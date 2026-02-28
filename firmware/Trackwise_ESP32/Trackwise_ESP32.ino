// ESP32 BLE Counter Firmware – Final Version Matching Spec with Inline Comments

#include <Preferences.h>  // For storing item data persistently
#include <BLEDevice.h>    // Core BLE support
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>      // For BLE notification descriptors
#include <ArduinoJson.h>  // For encoding/decoding JSON
#include <RTClib.h>
#include <esp_gap_ble_api.h>  // For connection parameter logging
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include <esp_task_wdt.h>
#include <esp_bt.h>           // For BLE bonding table access

// Debug logging macro - compiles out when DEBUG is not defined
// To enable: add -DDEBUG to build flags (Arduino IDE: Tools > Compiler Warnings)
#define DEBUG  // Uncomment for serial debug logging

#ifdef DEBUG
  #define DEBUG_LOG(...) Serial.printf(__VA_ARGS__)
  #define DEBUG_PRINTLN(x) Serial.println(x)
#else
  #define DEBUG_LOG(...)
  #define DEBUG_PRINTLN(x)
#endif

// Mutex for NVS access synchronization (prevents corruption from concurrent access)
static SemaphoreHandle_t nvsMutex = NULL;

// Watchdog timeout in seconds
#define WDT_TIMEOUT_SEC 30

// Watchdog configuration (ESP-IDF v5.x API)
static const esp_task_wdt_config_t wdtConfig = {
  .timeout_ms = WDT_TIMEOUT_SEC * 1000,
  .idle_core_mask = 0,  // Don't watch idle tasks
  .trigger_panic = true
};

// BLE UUID definitions
#define SERVICE_UUID "12345678-1234-1234-1234-123456789000"
#define CHAR_READ_UUID "12345678-1234-1234-1234-123456789001"
#define CHAR_NOTIFY_UUID "12345678-1234-1234-1234-123456789002"     // Reusing CHAR_NOTIFY_UUID for both real-time events and log syncs to reduce BLE characteristics.
#define CHAR_SET_ITEMS_UUID "12345678-1234-1234-1234-123456789008"  //send list of items from the app to device
#define CHAR_WRITE_UUID "12345678-1234-1234-1234-123456789010"      //combine clearlogs, setselected, settime


// RAM-based log buffer setup
#define MAX_LOG_ENTRIES 1000  // 14KB RAM (1000 × 14 bytes)
#define maxPrefsSlots 100  // Max item slots supported (increased for inventory use)

#define REMINDER_NONE 0
#define REMINDER_TARGET 1
#define REMINDER_INTERVAL 2

#define VIBRATION_PIN 5

// ============== PROTOCOL & FIRMWARE VERSION ==============
// Protocol version: Increment when changing command/response formats or behavior
// - v1: Initial protocol
// - v2: Added multi-device sync with handshake-first approach
#define PROTOCOL_VERSION 2

// Firmware version: Semantic versioning (major.minor.patch)
#define FIRMWARE_VERSION "1.5.0"

// ============== MULTI-DEVICE NVS KEYS ==============
// NVS keys for multi-device pairing support
#define NVS_KEY_PAIRED_UID "paired_uid"           // String: Firebase uid (empty = unpaired)
#define NVS_KEY_SYNC_SEQ_NO "sync_seq_no"         // int32: Last sync sequence number (default: 0)
// Note: Device Instance ID is now the BLE MAC address (no NVS storage needed)

// ============== MULTI-DEVICE STATE ==============
bool isPairingMode = false;  // True when device is unpaired and waiting for pairing
bool inConflictState = false;  // True when sync_seq mismatch detected, waiting for app override

// ============== OVERRIDE PROTOCOL STATE ==============
// State tracking for chunked override protocol (app pushing data to device)
int overrideSyncSeq = 0;        // Sync sequence number for this override
int overrideTotalChunks = 0;    // Total number of chunks expected
int overrideReceivedChunks = 0; // Number of chunks received so far
int overrideNextSlot = 0;       // Next sequential slot index for saving items

// Event types for log entries (replaces String to save ~21 bytes per entry)
#define EVENT_INCREMENT 0
#define EVENT_RESET 1
#define EVENT_SWITCH 2

// ============== COUNT LIMITS ==============
#define MAX_COUNT 9999  // Maximum value for count and todaycount

// ============== ERROR CODES ==============
// Error codes for notifyError() - enables reliable error handling in app
// Ranges: 1xx = payload, 2xx = storage, 3xx = protocol, 4xx = state

// 1xx: Payload errors
#define ERR_PAYLOAD_TOO_LARGE   101  // Payload exceeds buffer size
#define ERR_INVALID_JSON        102  // JSON parse error
#define ERR_BUFFER_OVERFLOW     103  // Write buffer overflow

// 2xx: Storage errors
#define ERR_NVS_MUTEX_TIMEOUT   201  // NVS mutex acquisition failed
#define ERR_NVS_WRITE_FAILED    202  // NVS write operation failed

// 3xx: Protocol errors
#define ERR_MISSING_FIELD       301  // Required field missing in command
#define ERR_UNKNOWN_COMMAND     302  // Unrecognized command

// 4xx: State errors
#define ERR_NO_ITEM_SELECTED    401  // Operation requires selected item
#define ERR_CONFLICT_STATE      402  // Device in conflict state
#define ERR_ITEM_NOT_FOUND      403  // Item with given deviceItemId not found

// Convert event type to string for JSON serialization
const char* eventTypeToString(uint8_t eventType) {
  switch (eventType) {
    case EVENT_INCREMENT: return "increment";
    case EVENT_RESET: return "reset";
    case EVENT_SWITCH: return "switch";
    default: return "unknown";
  }
}

// Event struct to store count logs
// Memory-optimized: 14 bytes per entry (was ~91 bytes)
// - Removed String objects to eliminate heap fragmentation
// - Used smallest int types that fit the data
// - Removed itemName (app looks up from deviceItemId)
// - Removed reminder/reminderValue (only used for NVS, not logged)
struct CountLog {
  uint32_t timestamp;       // 4 bytes
  int32_t count;            // 4 bytes
  uint8_t deviceItemId;     // 1 byte (0-99)
  uint8_t eventType;        // 1 byte (EVENT_INCREMENT, EVENT_RESET, EVENT_SWITCH)
  int16_t increment;        // 2 bytes (max 1000)
  uint16_t resetNumber;     // 2 bytes
};  // Total: 14 bytes (app looks up itemName from deviceItemId)

CountLog logs[MAX_LOG_ENTRIES];  //Create an array named logs that can hold up to MAX_LOG_ENTRIES items, where each item is a CountLog struct. This is the RAM!!!!!!!!!!!!!!!!!!!!!!
int logWriteIndex = 0;           //keep track of which slot in log should a new event be stored in
int logCount = 0;                //number of valid entries in the log

// Current device state for selected item
int currentItemIndex = 0;
int8_t currentDeviceItemId = -1;  // -1 = none, 0-99 = valid device item ID
int itemCount = 0;
int itemTodayCount = 0;
int itemIncrement = 1;
String itemName = "Item";
String itemCategory = "";
unsigned long connectedAt = 0;
bool didInitialSync = false;
bool needsSendSyncData = false;  // Set after successful handshake to trigger prefs+logs send
bool needsSendLogs = false;      // Set after prefs transmission completes to trigger logs send
unsigned long syncDataRequestedAt = 0;  // Timestamp when needsSendSyncData was set
bool isConnected = false;
int reminder = REMINDER_NONE;
int reminderValue = 0;
time_t lastResetTime = 0;
int itemResetNumber = 0;  // Track reset count for current item
Preferences prefs;  // Non-volatile storage instance
unsigned long lastResetCheck = 0;

// NVS write batching - reduce flash wear by writing every N increments
static int incrementsSinceWrite = 0;
static bool countsDirty = false;

String incomingJsonBuffer = "";       // Buffer for SET_ITEMS characteristic (chunked item list)
String writeCommandBuffer = "";       // Buffer for WRITE characteristic (chunked commands like override_chunk)
unsigned long lastChunkReceived = 0;  // Timestamp of last chunk for timeout detection
const unsigned long CHUNK_TIMEOUT_MS = 5000;  // 5 second timeout for incomplete transfers
enum ReadMode { READ_NONE,
                READ_PREFS,
                READ_LOGS };
int currentPage = 0;
const int pageSize = 15;  // how many logs per page (increased from 2 for faster sync)
RTC_DS3231 rtc;
time_t localTimestamp;
DateTime localTime;


ReadMode currentReadMode = READ_NONE;

// BLE characteristic pointers that will be used later to access data
BLECharacteristic* NotifyChar;
BLECharacteristic* syncChar;
BLECharacteristic* setItemsChar;
BLECharacteristic* writeChar;  //combine clearlogs and setselected
BLECharacteristic* readChar;

// For Non-Blocking Vibration (handles millis() overflow after ~49 days)
// Supports multi-pulse patterns (e.g., double vibrate for goal reached)
struct VibrationState {
  unsigned long startTime = 0;
  unsigned int duration = 0;
  bool isActive = false;
  int pulsesRemaining = 0;
  unsigned int pulseOnMs = 0;
  unsigned int pulseGapMs = 0;
  bool inGap = false;
} vibration;

void triggerVibrationNonBlocking(int duration = 300) {
  digitalWrite(VIBRATION_PIN, HIGH);
  vibration.startTime = millis();
  vibration.duration = duration;
  vibration.isActive = true;
  vibration.pulsesRemaining = 0;
  vibration.inGap = false;
}

// Trigger a multi-pulse vibration pattern (e.g., 2 rapid pulses)
void triggerVibrationPattern(int pulses, int onMs = 150, int gapMs = 100) {
  digitalWrite(VIBRATION_PIN, HIGH);
  vibration.startTime = millis();
  vibration.duration = onMs;
  vibration.isActive = true;
  vibration.pulsesRemaining = pulses - 1;
  vibration.pulseOnMs = onMs;
  vibration.pulseGapMs = gapMs;
  vibration.inGap = false;
}

// Check and turn off vibration in loop() - call this every iteration
// Uses subtraction to handle millis() overflow correctly
void updateVibration() {
  if (!vibration.isActive) return;
  if (millis() - vibration.startTime < vibration.duration) return;

  if (vibration.inGap) {
    // Gap finished, start next pulse
    digitalWrite(VIBRATION_PIN, HIGH);
    vibration.startTime = millis();
    vibration.duration = vibration.pulseOnMs;
    vibration.inGap = false;
    vibration.pulsesRemaining--;
  } else if (vibration.pulsesRemaining > 0) {
    // Pulse finished, start gap before next pulse
    digitalWrite(VIBRATION_PIN, LOW);
    vibration.startTime = millis();
    vibration.duration = vibration.pulseGapMs;
    vibration.inGap = true;
  } else {
    // All done
    digitalWrite(VIBRATION_PIN, LOW);
    vibration.isActive = false;
  }
}

// ============== NVS MUTEX HELPERS ==============
// Safe NVS access with mutex protection to prevent corruption from concurrent access
bool nvsBeginSafe(const char* name, bool readOnly, TickType_t timeout_ms = 1000) {
  if (nvsMutex == NULL) {
    // Mutex not initialized yet (early boot) - proceed without lock
    prefs.begin(name, readOnly);
    return true;
  }
  if (xSemaphoreTake(nvsMutex, pdMS_TO_TICKS(timeout_ms)) == pdTRUE) {
    prefs.begin(name, readOnly);
    return true;
  }
  DEBUG_PRINTLN("⚠️ Warning: NVS mutex timeout");
  return false;
}

void nvsEndSafe() {
  prefs.end();
  if (nvsMutex != NULL) {
    xSemaphoreGive(nvsMutex);
  }
}

// ============== INPUT VALIDATION HELPERS ==============
// Clamp integer to valid range
inline int clampInt(int value, int minVal, int maxVal) {
  return (value < minVal) ? minVal : (value > maxVal) ? maxVal : value;
}

// Validate device item ID (0-99)
inline bool isValidDeviceItemId(int id) {
  return id >= 0 && id < maxPrefsSlots;
}

// Validate reminder type
inline bool isValidReminder(int r) {
  return r >= REMINDER_NONE && r <= REMINDER_INTERVAL;
}

// Safe string extraction with length limit
String safeString(const char* str, size_t maxLen = 30) {
  if (!str) return "";
  String s(str);
  return (s.length() > maxLen) ? s.substring(0, maxLen) : s;
}

// ============== MULTI-DEVICE FUNCTIONS ==============

// Get the device instance ID (uses BLE MAC address)
// MAC address is unique per device and doesn't require NVS storage
String getDeviceInstanceId() {
  return BLEDevice::getAddress().toString().c_str();
}

// Get the paired Firebase UID from NVS
String getPairedUid() {
  String uid = "";
  if (!nvsBeginSafe("counter", true)) return uid;
  uid = prefs.getString(NVS_KEY_PAIRED_UID, "");
  nvsEndSafe();
  return uid;
}

// Set the paired Firebase UID in NVS
void setPairedUid(const String& uid) {
  if (!nvsBeginSafe("counter", false)) return;
  prefs.putString(NVS_KEY_PAIRED_UID, uid);
  nvsEndSafe();
  DEBUG_LOG("🔗 Paired to UID: %s\n", uid.c_str());
}

// Get the sync sequence number from NVS
int getSyncSeqNo() {
  int seq = 0;
  if (!nvsBeginSafe("counter", true)) return seq;
  seq = prefs.getInt(NVS_KEY_SYNC_SEQ_NO, 0);
  nvsEndSafe();
  return seq;
}

// Set the sync sequence number in NVS
void setSyncSeqNo(int seq) {
  if (!nvsBeginSafe("counter", false)) return;
  prefs.putInt(NVS_KEY_SYNC_SEQ_NO, seq);
  nvsEndSafe();
  DEBUG_LOG("📊 Sync sequence updated: %d\n", seq);
}

// Check if the device is paired (has a paired_uid set)
bool isDevicePaired() {
  String uid = getPairedUid();
  return uid.length() > 0;
}

// Enter pairing mode - device is waiting for first pairing
void enterPairingMode() {
  isPairingMode = true;
  DEBUG_PRINTLN("🔓 Entering pairing mode - waiting for app connection");
}

// Enter normal mode - device is paired and operational
void enterNormalMode() {
  isPairingMode = false;
  DEBUG_PRINTLN("✅ Entering normal mode - device is paired");
}

// Display welcome screen on device (called when unpaired)
// This is a placeholder - actual display code depends on hardware
void displayWelcomeScreen() {
  DEBUG_PRINTLN("═══════════════════════════════════════");
  DEBUG_PRINTLN("║       WELCOME TO TRAXELOS           ║");
  DEBUG_PRINTLN("║                                     ║");
  DEBUG_PRINTLN("║  Please connect via the app to      ║");
  DEBUG_PRINTLN("║  pair this device to your account   ║");
  DEBUG_PRINTLN("═══════════════════════════════════════");
}

// Display a message on device (placeholder for actual display)
// TODO(Phase 5): Replace with production OLED rendering when hardware is ready.
// See docs/plans/2026-02-24-phase5-firmware.md Tasks 1-2.
void displayMessage(const char* msg) {
  DEBUG_LOG("📺 DISPLAY: %s\n", msg);
}

// ============== CONFLICT STATE HANDLING ==============

// Enter conflict state - device shows "SEE APP" and disables buttons
// Called when handshake detects sync_seq mismatch
void enterConflictState() {
  inConflictState = true;
  displayMessage("SEE APP");
  DEBUG_PRINTLN("⚠️ Entered conflict state - buttons disabled, waiting for app override");
}

// Exit conflict state - restore normal operation
// Called on BLE disconnect or after successful override
void exitConflictState() {
  if (!inConflictState) return;  // Already not in conflict
  inConflictState = false;
  DEBUG_PRINTLN("✅ Exited conflict state - buttons re-enabled");
  // Clear display message (actual implementation depends on hardware)
  displayMessage("");  // Clear the "SEE APP" message
}

// Forward declaration for BLE transmit queue check
bool isBleTransmitBusy();

// Send a JSON response via BLE notification
// Used by handshake and other protocol messages
void sendJsonResponse(const String& jsonStr) {
  if (!isConnected || NotifyChar == nullptr) return;

  String response = jsonStr + "\n";  // Add newline for Flutter end-of-message detection

  // Always use non-blocking queue if another transmission is in progress
  // to prevent interleaved chunks corrupting messages
  if (response.length() > 180 || isBleTransmitBusy()) {
    startBleTransmit(response);
  } else {
    // Small response and no transmission in progress, send directly
    NotifyChar->setValue(response.c_str());
    NotifyChar->notify();
  }
  DEBUG_LOG("📤 Sent response: %s\n", jsonStr.c_str());
}

// Send acknowledgment response for fire-and-forget commands
// Only sends if ack was requested (ack parameter is true)
void sendAckIfRequested(JsonDocument& doc, const char* cmd, bool success = true, const char* errorReason = nullptr) {
  bool ackRequested = doc["ack"] | false;
  if (!ackRequested) return;

  StaticJsonDocument<128> ackDoc;
  ackDoc["status"] = success ? "ok" : "error";
  ackDoc["cmd"] = cmd;
  if (!success && errorReason) {
    ackDoc["reason"] = errorReason;
  }

  String response;
  serializeJson(ackDoc, response);
  sendJsonResponse(response);
}

// Handle handshake command from app
// Performs account lock check and sync sequence comparison
// App sends: { "cmd": "handshake", "uid": "xxx", "sync_seq": 42 }
void handleHandshake(const String& uid, int appSyncSeq) {
  String pairedUid = getPairedUid();
  String deviceInstanceId = getDeviceInstanceId();

  DEBUG_LOG("🤝 Handshake: uid=%s, app_sync_seq=%d\n", uid.c_str(), appSyncSeq);
  DEBUG_LOG("   Device paired_uid=%s, device_sync_seq=%d\n",
                pairedUid.isEmpty() ? "(empty)" : pairedUid.c_str(), getSyncSeqNo());

  // Step 1: Account lock check
  if (!pairedUid.isEmpty() && pairedUid != uid) {
    // Different account - reject
    StaticJsonDocument<256> doc;
    doc["status"] = "wrong_account";
    doc["device_instance_id"] = deviceInstanceId;
    doc["protocol_version"] = PROTOCOL_VERSION;
    doc["firmware_version"] = FIRMWARE_VERSION;

    String response;
    serializeJson(doc, response);
    sendJsonResponse(response);

    displayMessage("PAIRED TO");
    delay(100);  // Small delay between display messages
    displayMessage("OTHER ACCOUNT");

    DEBUG_PRINTLN("❌ Handshake rejected: device paired to different account");
    return;
  }

  // Step 2: Uninitialized device - needs setup
  // Don't store UID yet - wait for user confirmation via override command
  if (pairedUid.isEmpty()) {
    StaticJsonDocument<256> doc;
    doc["status"] = "uninitialized";
    doc["device_instance_id"] = deviceInstanceId;
    doc["protocol_version"] = PROTOCOL_VERSION;
    doc["firmware_version"] = FIRMWARE_VERSION;

    String response;
    serializeJson(doc, response);
    sendJsonResponse(response);

    displayMessage("AWAITING");
    delay(100);
    displayMessage("SETUP");

    DEBUG_PRINTLN("📱 Handshake: device uninitialized, awaiting setup from app");
    return;
  }

  // Step 3: Sync sequence check (device is already paired)
  int deviceSyncSeq = getSyncSeqNo();  // 0 = never synced

  // App sends -1 to skip sync_seq comparison (multi-device mode).
  // This avoids false conflicts when multiple devices each increment sync_seq.
  if (appSyncSeq == -1 || appSyncSeq == deviceSyncSeq) {
    // In sync - device is Source of Truth, proceed with normal sync
    StaticJsonDocument<256> doc;
    doc["status"] = "in_sync";
    doc["device_instance_id"] = deviceInstanceId;
    doc["protocol_version"] = PROTOCOL_VERSION;
    doc["firmware_version"] = FIRMWARE_VERSION;

    String response;
    serializeJson(doc, response);
    sendJsonResponse(response);

    DEBUG_LOG("✅ Handshake: in_sync (seq=%d)\n", deviceSyncSeq);

    // Automatically send prefs+logs after successful handshake
    // (App expects these to arrive via notification stream)
    // Note: We set a flag here, the actual sending happens in loop()
    // to avoid blocking the BLE callback
    needsSendSyncData = true;  // Flag to trigger prefs+logs send in loop()
    syncDataRequestedAt = millis();  // Record time to allow handshake response to send first
  } else {
    // Out of sync - app is Source of Truth, enter conflict state
    StaticJsonDocument<256> doc;
    doc["status"] = "conflict";
    doc["device_seq"] = deviceSyncSeq;
    doc["device_instance_id"] = deviceInstanceId;
    doc["protocol_version"] = PROTOCOL_VERSION;
    doc["firmware_version"] = FIRMWARE_VERSION;

    String response;
    serializeJson(doc, response);
    sendJsonResponse(response);

    enterConflictState();

    DEBUG_LOG("⚠️ Handshake: conflict (device_seq=%d, app_seq=%d)\n", deviceSyncSeq, appSyncSeq);
  }
}

// Clear a single item slot from NVS
void clearItemSlot(int index) {
  if (index < 0 || index >= maxPrefsSlots) return;

  char key[16];
  snprintf(key, sizeof(key), "did_%d", index);
  prefs.remove(key);
  snprintf(key, sizeof(key), "n_%d", index);
  prefs.remove(key);
  snprintf(key, sizeof(key), "cat_%d", index);
  prefs.remove(key);
  snprintf(key, sizeof(key), "c_%d", index);
  prefs.remove(key);
  snprintf(key, sizeof(key), "tc_%d", index);
  prefs.remove(key);
  snprintf(key, sizeof(key), "i_%d", index);
  prefs.remove(key);
  snprintf(key, sizeof(key), "r_%d", index);
  prefs.remove(key);
  snprintf(key, sizeof(key), "rv_%d", index);
  prefs.remove(key);
  snprintf(key, sizeof(key), "g_%d", index);
  prefs.remove(key);
  snprintf(key, sizeof(key), "lr_%d", index);
  prefs.remove(key);
  snprintf(key, sizeof(key), "rn_%d", index);
  prefs.remove(key);
}

// Clear all item slots from NVS
void clearAllItemSlots() {
  for (int i = 0; i < maxPrefsSlots; i++) {
    clearItemSlot(i);
  }
  // Reset item_total
  prefs.putInt("item_total", 0);
  DEBUG_PRINTLN("🗑️ Cleared all item slots");
}

// ============== OVERRIDE PROTOCOL FUNCTIONS ==============

// Save item data to a specific slot in NVS during override
// slotId = sequential storage index (0, 1, 2...)
// device_item_id from JSON = the ID that maps back to Firestore
// NOTE: Caller must hold NVS lock - this function does NOT call nvsBeginSafe/nvsEndSafe
void saveItemToSlot(int slotId, JsonObject& item) {
  if (slotId < 0 || slotId >= maxPrefsSlots) {
    DEBUG_LOG("❌ Invalid slot ID: %d (must be 0-%d)\n", slotId, maxPrefsSlots - 1);
    return;
  }

  char key[16];

  // Store device_item_id (from JSON, NOT the slot index)
  int deviceItemId = item["device_item_id"] | slotId;  // Fallback to slotId if missing
  snprintf(key, sizeof(key), "did_%d", slotId);
  prefs.putUChar(key, (uint8_t)deviceItemId);

  // Store name (max 30 chars)
  snprintf(key, sizeof(key), "n_%d", slotId);
  String name = safeString(item["name"] | "", 30);
  prefs.putString(key, name);

  // Store category (max 30 chars)
  snprintf(key, sizeof(key), "cat_%d", slotId);
  String category = safeString(item["category"] | "", 30);
  prefs.putString(key, category);

  // Store count (clamped to MAX_COUNT)
  snprintf(key, sizeof(key), "c_%d", slotId);
  prefs.putInt(key, clampInt(item["count"] | 0, 0, MAX_COUNT));

  // Store todaycount (clamped to MAX_COUNT)
  snprintf(key, sizeof(key), "tc_%d", slotId);
  prefs.putInt(key, clampInt(item["todaycount"] | 0, 0, MAX_COUNT));

  // Store increment (1-1000)
  snprintf(key, sizeof(key), "i_%d", slotId);
  int increment = clampInt(item["increment"] | 1, 1, 1000);
  prefs.putInt(key, increment);

  // Store reminder type
  snprintf(key, sizeof(key), "r_%d", slotId);
  int reminderType = item["reminder"] | REMINDER_NONE;
  if (!isValidReminder(reminderType)) reminderType = REMINDER_NONE;
  prefs.putInt(key, reminderType);

  // Store reminder value
  snprintf(key, sizeof(key), "rv_%d", slotId);
  int reminderVal = clampInt(item["reminder_value"] | 0, 0, 9999);
  prefs.putInt(key, reminderVal);

  // Store goal (0 = no goal, clamped to MAX_COUNT)
  snprintf(key, sizeof(key), "g_%d", slotId);
  int goal = clampInt(item["goal"] | 0, 0, MAX_COUNT);
  prefs.putInt(key, goal);

  // Store lastResetTime
  snprintf(key, sizeof(key), "lr_%d", slotId);
  unsigned long lastReset = item["lastResetTime"] | 0UL;
  prefs.putULong(key, lastReset);

  // Store reset_number
  snprintf(key, sizeof(key), "rn_%d", slotId);
  int resetNum = clampInt(item["reset_number"] | 0, 0, 100000);
  prefs.putInt(key, resetNum);

  DEBUG_LOG("💾 Saved item to slot %d (did=%d): %s\n", slotId, deviceItemId, name.c_str());
}

// Set the selected item by device_item_id with fallback logic
// If selectedId == -1 -> select nothing (explicit "no selection" from app)
// If selectedId >= 0 but doesn't exist in items -> fall back to first item (index 0)
// If no items at all -> select nothing
// NOTE: Caller must hold NVS lock - this function does NOT call nvsBeginSafe/nvsEndSafe
void setSelectedItem(int selectedId) {
  int total = prefs.getInt("item_total", 0);

  // Check for explicit "select nothing" from app (-1)
  if (selectedId == -1) {
    currentItemIndex = 0;
    currentDeviceItemId = -1;
    prefs.putInt("selected_index", 0);
    prefs.putChar("selected_did", -1);
    DEBUG_PRINTLN("📌 selected_id=-1: selecting nothing");
    return;
  }

  if (total == 0) {
    // No items at all - select nothing
    currentItemIndex = 0;
    currentDeviceItemId = -1;
    prefs.putInt("selected_index", 0);
    prefs.putChar("selected_did", -1);
    displayMessage("NO ITEMS\nSYNC TO APP");
    DEBUG_PRINTLN("📌 No items - selecting nothing");
    return;
  }

  // Search for the item with matching device_item_id
  char key[16];
  bool found = false;
  for (int i = 0; i < total; i++) {
    snprintf(key, sizeof(key), "did_%d", i);
    uint8_t testId = prefs.getUChar(key, 255);
    if (testId == (uint8_t)selectedId) {
      // Found the item - select it
      currentItemIndex = i;
      currentDeviceItemId = selectedId;
      prefs.putInt("selected_index", i);
      prefs.putChar("selected_did", selectedId);
      found = true;

      // Load item data into runtime variables
      snprintf(key, sizeof(key), "c_%d", i);
      itemCount = prefs.getInt(key, 0);
      snprintf(key, sizeof(key), "tc_%d", i);
      itemTodayCount = prefs.getInt(key, 0);
      snprintf(key, sizeof(key), "i_%d", i);
      itemIncrement = prefs.getInt(key, 1);
      snprintf(key, sizeof(key), "n_%d", i);
      itemName = prefs.getString(key, "Item");
      snprintf(key, sizeof(key), "cat_%d", i);
      itemCategory = prefs.getString(key, "");
      snprintf(key, sizeof(key), "r_%d", i);
      reminder = prefs.getInt(key, REMINDER_NONE);
      snprintf(key, sizeof(key), "rv_%d", i);
      reminderValue = prefs.getInt(key, 0);
      snprintf(key, sizeof(key), "lr_%d", i);
      lastResetTime = prefs.getULong(key, 0);
      snprintf(key, sizeof(key), "rn_%d", i);
      itemResetNumber = prefs.getInt(key, 0);

      DEBUG_LOG("📌 Selected item %d (slot %d): %s\n", selectedId, i, itemName.c_str());
      break;
    }
  }

  if (!found) {
    // selectedId not found - fall back to first item (index 0)
    DEBUG_LOG("⚠️ Selected ID %d not found - falling back to first item\n", selectedId);
    currentItemIndex = 0;
    snprintf(key, sizeof(key), "did_%d", 0);
    currentDeviceItemId = prefs.getUChar(key, 0);
    prefs.putInt("selected_index", 0);
    prefs.putChar("selected_did", currentDeviceItemId);

    // Load first item data into runtime variables
    snprintf(key, sizeof(key), "c_%d", 0);
    itemCount = prefs.getInt(key, 0);
    snprintf(key, sizeof(key), "tc_%d", 0);
    itemTodayCount = prefs.getInt(key, 0);
    snprintf(key, sizeof(key), "i_%d", 0);
    itemIncrement = prefs.getInt(key, 1);
    snprintf(key, sizeof(key), "n_%d", 0);
    itemName = prefs.getString(key, "Item");
    snprintf(key, sizeof(key), "cat_%d", 0);
    itemCategory = prefs.getString(key, "");
    snprintf(key, sizeof(key), "r_%d", 0);
    reminder = prefs.getInt(key, REMINDER_NONE);
    snprintf(key, sizeof(key), "rv_%d", 0);
    reminderValue = prefs.getInt(key, 0);
    snprintf(key, sizeof(key), "lr_%d", 0);
    lastResetTime = prefs.getULong(key, 0);
    snprintf(key, sizeof(key), "rn_%d", 0);
    itemResetNumber = prefs.getInt(key, 0);

    DEBUG_LOG("📌 Fallback to first item (slot 0): %s\n", itemName.c_str());
  }
}

// ============== OVERRIDE PROTOCOL HANDLERS ==============

// Handle override_start command from app
// App sends: { "cmd": "override_start", "uid": "xxx", "sync_seq": 43, "total_chunks": N }
// Prepares device for receiving chunked item data
// Stores UID if device is uninitialized (user confirmed setup)
// NOTE: Caller must hold NVS lock - this function does NOT call nvsBeginSafe/nvsEndSafe
void handleOverrideStart(const String& uid, int syncSeq, int totalChunks) {
  DEBUG_LOG("📥 Override start: uid=%s, sync_seq=%d, total_chunks=%d\n",
                uid.c_str(), syncSeq, totalChunks);

  // Store UID if not already paired (user confirmed device setup)
  String pairedUid = prefs.getString(NVS_KEY_PAIRED_UID, "");
  if (pairedUid.isEmpty() && !uid.isEmpty()) {
    prefs.putString(NVS_KEY_PAIRED_UID, uid);
    enterNormalMode();  // Exit pairing mode
    DEBUG_LOG("🔗 Device setup: stored uid=%s\n", uid.c_str());
  }

  // Store override state
  overrideSyncSeq = syncSeq;
  overrideTotalChunks = totalChunks;
  overrideReceivedChunks = 0;
  overrideNextSlot = 0;  // Reset sequential slot counter

  // Clear existing items to prepare for new data
  clearAllItemSlots();

  DEBUG_PRINTLN("✅ Override started - ready to receive chunks");
}

// Handle override_chunk command from app
// App sends: { "cmd": "override_chunk", "index": 0, "items": [...] }
// Saves items SEQUENTIALLY at indices 0, 1, 2... (not at their device_item_id)
// The device_item_id is stored in did_X field for mapping back to Firestore
// NOTE: Caller must hold NVS lock - this function does NOT call nvsBeginSafe/nvsEndSafe
void handleOverrideChunk(int chunkIndex, JsonArray items) {
  DEBUG_LOG("📥 Override chunk %d: %d items\n", chunkIndex, items.size());

  int savedCount = 0;
  for (JsonObject item : items) {
    int deviceItemId = item["device_item_id"] | -1;

    // Enforce 100 item limit
    if (overrideNextSlot >= maxPrefsSlots) {
      DEBUG_LOG("⚠️ Max items reached (%d), skipping remaining\n", maxPrefsSlots);
      break;
    }

    if (deviceItemId >= 0) {
      // Save item at sequential slot index (not device_item_id)
      saveItemToSlot(overrideNextSlot, item);
      savedCount++;
      overrideNextSlot++;
    } else {
      DEBUG_LOG("⚠️ Skipping invalid device_item_id: %d\n", deviceItemId);
    }
  }

  overrideReceivedChunks++;
  DEBUG_LOG("✅ Chunk %d processed: saved %d items (received %d/%d chunks)\n",
                chunkIndex, savedCount, overrideReceivedChunks, overrideTotalChunks);
}

// Handle override_end command from app
// App sends: { "cmd": "override_end", "selected_id": 2 }
// Validates all chunks received, sets selected item, updates sync_seq
// NOTE: Caller must hold NVS lock - this function does NOT call nvsBeginSafe/nvsEndSafe
void handleOverrideEnd(int selectedId) {
  DEBUG_LOG("📥 Override end: selected_id=%d\n", selectedId);

  // Validate all chunks were received
  if (overrideReceivedChunks != overrideTotalChunks) {
    DEBUG_LOG("❌ Override failed: missing chunks (received %d, expected %d)\n",
                  overrideReceivedChunks, overrideTotalChunks);
    sendJsonResponse("{\"status\":\"error\",\"message\":\"missing_chunks\"}");
    return;
  }

  // Use overrideNextSlot as item_total (we saved items sequentially at 0, 1, 2...)
  int itemTotal = overrideNextSlot;
  prefs.putInt("item_total", itemTotal);
  DEBUG_LOG("📊 Override complete: %d items total\n", itemTotal);

  // Set selected item (with fallback logic)
  // NOTE: setSelectedItem reads from prefs which is already open
  setSelectedItem(selectedId);

  // Update sync sequence number directly (we already hold NVS lock)
  prefs.putInt(NVS_KEY_SYNC_SEQ_NO, overrideSyncSeq);
  DEBUG_LOG("📊 Sync sequence updated: %d\n", overrideSyncSeq);

  // Exit conflict state
  exitConflictState();

  // Send success response
  sendJsonResponse("{\"status\":\"override_complete\"}");

  // Display "SYNCED" message
  displayMessage("SYNCED");

  // Reset override state
  overrideSyncSeq = 0;
  overrideTotalChunks = 0;
  overrideReceivedChunks = 0;
  overrideNextSlot = 0;

  DEBUG_PRINTLN("✅ Override complete - device synced with app");
}

// Handle sync_complete command from app
// App sends: { "cmd": "sync_complete", "sync_seq": 43 }
// Called after normal sync (device was source of truth) to update sync_seq
void handleSyncComplete(int newSyncSeq) {
  DEBUG_LOG("📥 Sync complete: new_sync_seq=%d\n", newSyncSeq);

  // Update sync sequence number in NVS
  setSyncSeqNo(newSyncSeq);

  // Send acknowledgment so app knows it's safe to update Firestore
  sendJsonResponse("{\"status\":\"seq_updated\"}");

  // No display change - normal operation continues
  DEBUG_PRINTLN("✅ Sync complete - sequence number updated");
}

// Clear BLE bonding table
void clearBleBonding() {
  // Remove all bonded devices
  int devNum = esp_ble_get_bond_device_num();
  if (devNum > 0) {
    esp_ble_bond_dev_t* devList = (esp_ble_bond_dev_t*)malloc(sizeof(esp_ble_bond_dev_t) * devNum);
    if (devList != NULL) {
      esp_ble_get_bond_device_list(&devNum, devList);
      for (int i = 0; i < devNum; i++) {
        esp_ble_remove_bond_device(devList[i].bd_addr);
      }
      free(devList);
    }
  }
  DEBUG_LOG("🔐 Cleared BLE bonding table (%d devices)\n", devNum);
}

// Wait for a specific key confirmation with timeout
// Returns true if the expected key is pressed within timeout
bool waitForConfirmation(char expectedKey, unsigned long timeoutMs) {
  unsigned long startTime = millis();
  DEBUG_LOG("⏳ Waiting for '%c' confirmation (timeout: %lu ms)...\n", expectedKey, timeoutMs);

  while ((millis() - startTime) < timeoutMs) {
    // Explicitly feed the watchdog every iteration
    esp_task_wdt_reset();

    if (Serial.available()) {
      char c = Serial.read();
      if (c == expectedKey) {
        DEBUG_PRINTLN("✅ Confirmation received");
        return true;
      }
    }
    // Small delay to prevent busy-waiting
    delay(100);
  }

  DEBUG_PRINTLN("⏰ Confirmation timeout");
  return false;
}

// Handle factory reset with confirmation
// Clears: pairing, sync_seq, all items, BLE bonding
// Keeps: device_instance_id (persistent device identity)
void handleFactoryReset() {
  displayMessage("FACTORY RESET?");
  displayMessage("F=CONFIRM");

  if (waitForConfirmation('F', 10000)) {
    if (!nvsBeginSafe("counter", false)) {
      displayMessage("RESET FAILED");
      DEBUG_PRINTLN("❌ Factory reset failed - NVS mutex timeout");
      return;
    }

    // Clear pairing data
    prefs.remove(NVS_KEY_PAIRED_UID);
    prefs.remove(NVS_KEY_SYNC_SEQ_NO);
    DEBUG_PRINTLN("🗑️ Cleared pairing data");

    // Clear all item slots
    clearAllItemSlots();

    // Reset selection state
    prefs.putInt("selected_index", 0);
    prefs.putChar("selected_did", -1);
    prefs.remove("last_reset_date");

    nvsEndSafe();

    // Note: device_instance_id is NOT regenerated - it's a persistent device identity

    // Clear BLE bonding table
    clearBleBonding();

    displayMessage("RESET COMPLETE");
    DEBUG_PRINTLN("✅ Factory reset complete - restarting device");
    delay(2000);

    ESP.restart();
  } else {
    displayMessage("CANCELLED");
    DEBUG_PRINTLN("❌ Factory reset cancelled");
  }
}

// ============== NON-BLOCKING BLE TRANSMISSION ==============
// State machine for chunk-based BLE transmission without blocking
// Uses a queue to prevent message interleaving

#define BLE_TX_QUEUE_SIZE 8  // Max pending messages

// Max BLE message size: prefs JSON for 100 items ≈ 15KB
#define BLE_TX_BUF_SIZE 16384

struct BleTransmitState {
  char* queue[BLE_TX_QUEUE_SIZE];    // Queue of pending messages (heap-allocated, freed after send)
  int queueHead = 0;
  int queueTail = 0;
  int queueCount = 0;
  char buffer[BLE_TX_BUF_SIZE];      // Pre-allocated transmit buffer
  int bufferLen = 0;                  // Length of data in buffer
  int offset = 0;
  unsigned long lastChunkTime = 0;
  bool inProgress = false;
  const int mtu = 180;
} bleTransmit;

// Check if BLE transmit is busy (used by sendJsonResponse forward declaration)
bool isBleTransmitBusy() {
  return bleTransmit.inProgress || bleTransmit.queueCount > 0;
}

void startBleTransmit(const String& data) {
  if (!bleTransmit.inProgress) {
    int len = data.length();
    if (len >= BLE_TX_BUF_SIZE) {
      DEBUG_PRINTLN("⚠️ BLE message too large for transmit buffer!");
      return;
    }
    memcpy(bleTransmit.buffer, data.c_str(), len);
    bleTransmit.buffer[len] = '\0';
    bleTransmit.bufferLen = len;
    bleTransmit.offset = 0;
    bleTransmit.lastChunkTime = 0;
    bleTransmit.inProgress = true;
    return;
  }

  if (bleTransmit.queueCount < BLE_TX_QUEUE_SIZE) {
    char* copy = strdup(data.c_str());
    if (copy == NULL) {
      DEBUG_PRINTLN("⚠️ BLE transmit queue alloc failed!");
      return;
    }
    bleTransmit.queue[bleTransmit.queueHead] = copy;
    bleTransmit.queueHead = (bleTransmit.queueHead + 1) % BLE_TX_QUEUE_SIZE;
    bleTransmit.queueCount++;
    DEBUG_LOG("📋 Queued BLE message (%d in queue)\n", bleTransmit.queueCount);
  } else {
    DEBUG_PRINTLN("⚠️ BLE transmit queue full - message dropped!");
  }
}

// Process one chunk of BLE transmission (call from loop)
// Returns true when a transmission is complete (but queue may have more)
bool processBleTransmit() {
  if (!bleTransmit.inProgress || !isConnected) {
    if (bleTransmit.queueCount > 0 && isConnected) {
      char* queued = bleTransmit.queue[bleTransmit.queueTail];
      int len = strlen(queued);
      bleTransmit.queue[bleTransmit.queueTail] = NULL;
      bleTransmit.queueTail = (bleTransmit.queueTail + 1) % BLE_TX_QUEUE_SIZE;
      bleTransmit.queueCount--;
      if (len >= BLE_TX_BUF_SIZE) {
        DEBUG_PRINTLN("⚠️ Queued message too large, dropping");
        free(queued);
        return false;  // Skip this message, try next on next call
      }
      memcpy(bleTransmit.buffer, queued, len);
      bleTransmit.buffer[len] = '\0';
      bleTransmit.bufferLen = len;
      free(queued);
      bleTransmit.offset = 0;
      bleTransmit.lastChunkTime = 0;
      bleTransmit.inProgress = true;
      DEBUG_LOG("📋 Dequeued BLE message (%d remaining)\n", bleTransmit.queueCount);
    } else {
      bleTransmit.inProgress = false;
      return false;
    }
  }

  if (bleTransmit.lastChunkTime > 0 &&
      (millis() - bleTransmit.lastChunkTime) < 20) {
    return false;
  }

  int remaining = bleTransmit.bufferLen - bleTransmit.offset;
  if (remaining <= 0) {
    bleTransmit.inProgress = false;
    bleTransmit.bufferLen = 0;
    return true;
  }

  int chunkSize = min(remaining, bleTransmit.mtu);
  // Write directly from buffer without creating a String
  NotifyChar->setValue((uint8_t*)(bleTransmit.buffer + bleTransmit.offset), chunkSize);
  NotifyChar->notify();

  bleTransmit.offset += chunkSize;
  bleTransmit.lastChunkTime = millis();
  return false;
}

// ============== POWER MANAGEMENT ==============
// CPU frequency scaling and BLE advertising interval adjustment for power savings
#define IDLE_TIMEOUT_MS 300000  // 5 minutes
#define BLE_ADV_INTERVAL_IDLE 0x320   // 500ms (in 0.625ms units)
#define BLE_ADV_INTERVAL_ACTIVE 0x40  // 40ms (in 0.625ms units)

struct PowerState {
  unsigned long lastActivity = 0;
  bool isLowPower = false;
} powerState;

// Forward declarations for power management
void exitLowPowerMode();
void flushPendingNvsWrites();

void recordActivity() {
  powerState.lastActivity = millis();
  if (powerState.isLowPower) {
    // Will exit low power mode
    exitLowPowerMode();
  }
}

void enterLowPowerMode() {
  if (powerState.isLowPower) return;

  // Slow down BLE advertising to save power
  BLEDevice::getAdvertising()->stop();
  BLEDevice::getAdvertising()->setMinInterval(BLE_ADV_INTERVAL_IDLE);
  BLEDevice::getAdvertising()->setMaxInterval(BLE_ADV_INTERVAL_IDLE);
  BLEDevice::getAdvertising()->start();

  // Reduce CPU frequency (240MHz -> 80MHz)
  setCpuFrequencyMhz(80);

  // Flush any pending NVS writes before going to low power
  flushPendingNvsWrites();

  powerState.isLowPower = true;
  DEBUG_PRINTLN("🔋 Entered low power mode (80MHz, slow advertising)");
}

void exitLowPowerMode() {
  if (!powerState.isLowPower) return;

  // Restore full CPU frequency
  setCpuFrequencyMhz(240);

  // Restore fast BLE advertising
  BLEDevice::getAdvertising()->stop();
  BLEDevice::getAdvertising()->setMinInterval(BLE_ADV_INTERVAL_ACTIVE);
  BLEDevice::getAdvertising()->setMaxInterval(BLE_ADV_INTERVAL_ACTIVE);
  BLEDevice::getAdvertising()->start();

  powerState.isLowPower = false;
  DEBUG_PRINTLN("⚡ Exited low power mode (240MHz, fast advertising)");
}

// Flush pending NVS writes for current item (call on disconnect or before sleep)
void flushPendingNvsWrites() {
  if (countsDirty && currentDeviceItemId >= 0) {
    DEBUG_PRINTLN("📝 Flushing pending NVS writes...");
    if (!nvsBeginSafe("counter", false)) return;
    char key[16];
    snprintf(key, sizeof(key), "c_%d", currentItemIndex);
    prefs.putInt(key, itemCount);
    snprintf(key, sizeof(key), "tc_%d", currentItemIndex);
    prefs.putInt(key, itemTodayCount);
    nvsEndSafe();
    countsDirty = false;
    incrementsSinceWrite = 0;
    DEBUG_LOG("✅ Flushed: count=%d, todayCount=%d\n", itemCount, itemTodayCount);
  }
}

// Store a new log event in RAM
// For reset events, pass the OLD resetNumber before incrementing
void logEvent(uint8_t eventType, int resetNum = -1) {
  uint16_t logResetNumber = (resetNum >= 0) ? (uint16_t)resetNum : (uint16_t)itemResetNumber;

  CountLog& log = logs[logWriteIndex];
  log.timestamp = rtc.now().unixtime();
  log.count = itemCount;

  log.deviceItemId = (uint8_t)(currentDeviceItemId >= 0 ? currentDeviceItemId : 0);
  log.eventType = eventType;
  log.increment = (int16_t)itemIncrement;
  log.resetNumber = logResetNumber;

  logWriteIndex = (logWriteIndex + 1) % MAX_LOG_ENTRIES;
  if (logCount < MAX_LOG_ENTRIES) logCount++;
}

void notifyPrefsToApp() {
  if (!isConnected || NotifyChar == nullptr) return;
  // Flush any pending NVS writes so prefs reflect current RAM values
  flushPendingNvsWrites();
  String jsonOut = getPrefsJson();
  jsonOut += "\n";  // For Flutter end-of-message detection

  // Use non-blocking transmission (processed in loop)
  startBleTransmit(jsonOut);
  DEBUG_PRINTLN("📤 Started sending prefs via notification (non-blocking)...");
}

// Send error notification to app via NOTIFY characteristic
// Used to report command failures, parse errors, etc. for better debugging
// error_code: Numeric code for reliable app-side error handling (0 = legacy/unspecified)
void notifyError(const char* cmd, const char* reason, int error_code = 0) {
  if (!isConnected || NotifyChar == nullptr || cmd == nullptr || reason == nullptr) return;

  StaticJsonDocument<256> doc;
  doc["type"] = "error";
  doc["cmd"] = cmd;
  if (error_code > 0) {
    doc["error_code"] = error_code;
  }
  doc["reason"] = reason;

  String jsonOut;
  serializeJson(doc, jsonOut);
  jsonOut += "\n";

  NotifyChar->setValue(jsonOut.c_str());
  NotifyChar->notify();
  DEBUG_LOG("📤 Error notification: cmd=%s, code=%d, reason=%s\n", cmd, error_code, reason);
}

// ============================================================================
// ITEM_DELTA NOTIFICATION - Current State
// ============================================================================
// Purpose: Sync the CURRENT STATE of an item to the app for UI display.
// Contains: count, todaycount, lastResetTime, resetNumber
//
// This is DIFFERENT from notifyEvent():
//   - item_delta = "here's the current state" (for UI updates)
//   - event      = "here's what just happened" (for history/logging)
//
// When sent:
//   - After increment/reset button press (paired with notifyEvent)
//   - After set_selected command (WITHOUT notifyEvent - no action occurred)
//
// The app needs BOTH notifications on button press because:
//   - event: provides timestamp, action type, increment value (for history)
//   - item_delta: provides todaycount, lastResetTime (for UI state)
// ============================================================================
void notifyItemDelta(int8_t deviceItemId, int count, int todayCount, time_t resetTime, int resetNumber) {
  if (!isConnected || NotifyChar == nullptr) return;

  StaticJsonDocument<256> doc;
  doc["type"] = "item_delta";
  doc["id"] = (int)deviceItemId;  // Numeric deviceItemId instead of string
  doc["count"] = count;
  doc["todaycount"] = todayCount;
  doc["lastResetTime"] = (long)resetTime;
  doc["resetNumber"] = resetNumber;

  String jsonOut;
  serializeJson(doc, jsonOut);
  jsonOut += "\n";

  // Delta is small enough to send in one chunk typically
  NotifyChar->setValue(jsonOut.c_str());
  NotifyChar->notify();
  DEBUG_LOG("📤 Delta update: deviceItemId=%d count=%d today=%d resetNumber=%d\n", deviceItemId, count, todayCount, resetNumber);
}

// Send logs to app via notification (chunked for large payloads)
void notifyLogsToApp(int page) {
  if (!isConnected || NotifyChar == nullptr) return;
  String jsonOut = getLogsAsString(page);
  jsonOut += "\n";  // For Flutter end-of-message detection

  DEBUG_LOG("📤 Starting logs page %d (%d bytes, %d chunks) (non-blocking)\n", page, jsonOut.length(), (jsonOut.length() + 179) / 180);

  // Use non-blocking transmission (processed in loop)
  startBleTransmit(jsonOut);
}

// Convert ALL prefs into a JSON string to send to the app
// Uses numeric deviceItemId (0-99) instead of string IDs for memory optimization
String getPrefsJson() {
  StaticJsonDocument<15360> doc;  // 100 items × ~145 bytes = 14.5KB + headroom

  // Create the outer object
  JsonObject root = doc.to<JsonObject>();
  root["type"] = "prefs";

  // Add the array as a nested field called "data"
  JsonArray arr = root.createNestedArray("data");

  if (!nvsBeginSafe("counter", false)) {
    root["error"] = "NVS timeout";
    String out;
    serializeJson(root, out);
    return out;
  }
  int total = prefs.getInt("item_total", 0);
  char key[16];  // Buffer for preference keys
  for (int i = 0; i < total; i++) {
    JsonObject item = arr.createNestedObject();
    // Use deviceItemId from storage (not index)
    snprintf(key, sizeof(key), "did_%d", i);
    item["id"] = prefs.getUChar(key, i);  // Default to index if not stored
    snprintf(key, sizeof(key), "n_%d", i);
    item["name"] = prefs.getString(key, "");
    snprintf(key, sizeof(key), "c_%d", i);
    item["count"] = prefs.getInt(key, 0);
    snprintf(key, sizeof(key), "tc_%d", i);
    item["todaycount"] = prefs.getInt(key, 0); //pref needs todaycount
    snprintf(key, sizeof(key), "lr_%d", i);
    item["lastResetTime"] = prefs.getULong(key, 0);
    snprintf(key, sizeof(key), "rn_%d", i);
    item["resetNumber"] = prefs.getInt(key, 0);
  }

  // Add selected_id as numeric deviceItemId (-1 for none)
  int8_t selectedId = prefs.getChar("selected_did", -1);
  root["selected_id"] = (int)selectedId;
  nvsEndSafe();

  String out;
  serializeJson(root, out);
  return out;
}

// Convert ALL pts into a JSON string to send to the app
// Uses numeric deviceItemId (0-99) instead of string IDs
String getLogsAsString(int page) {
  StaticJsonDocument<2048> doc;  // 15 entries × ~60 bytes = ~1KB + headroom

  // Create outer object
  JsonObject root = doc.to<JsonObject>();
  root["type"] = "logs";
  root["page"] = page;  // Fixed: was hardcoded to 0

  int startIndex = page * pageSize;
  int endIndex = min(startIndex + pageSize, logCount);

  // Add hasMore BEFORE data array so it's not lost if JSON overflows
  root["hasMore"] = endIndex < logCount;

  // Add array as "data" field
  JsonArray arr = root.createNestedArray("data");

  for (int i = startIndex; i < endIndex; i++) {
    // Check for overflow before adding each entry
    if (doc.overflowed()) {
      DEBUG_PRINTLN("⚠️ JSON document overflow - truncating logs");
      break;
    }
    JsonObject o = arr.createNestedObject();
    o["timestamp"] = logs[i].timestamp;
    o["itemId"] = (int)logs[i].deviceItemId;  // Numeric deviceItemId
    o["event"] = eventTypeToString(logs[i].eventType);  // Convert enum to string
    o["increment"] = (int)logs[i].increment;
    o["count"] = logs[i].count;
    o["resetNumber"] = (int)logs[i].resetNumber;
  }

  // Check if we overflowed
  if (doc.overflowed()) {
    DEBUG_LOG("⚠️ JSON overflow detected! Doc size: %d, capacity: %d\n", doc.memoryUsage(), doc.capacity());
  }

  String out;
  serializeJson(root, out);
  return out;
}

// Clear all RAM log data (logWriteIndex = 0: reset the pointer to the first slot in logs. logCount = 0: keep the pointer from touching old data)
void clearLogs() {
  logWriteIndex = 0;
  logCount = 0;
}

// Handle app updating the full list of items
class SetItemsCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    String chunk = String(c->getValue().c_str());
    DEBUG_PRINTLN("Received raw chunk:");
    DEBUG_PRINTLN(chunk);

    // Update timestamp for chunk timeout detection
    lastChunkReceived = millis();

    incomingJsonBuffer.trim();
    incomingJsonBuffer += chunk;

    // Input validation: check payload size before parsing
    if (incomingJsonBuffer.length() > 32000) {
      DEBUG_PRINTLN("❌ Payload too large (>32KB)");
      notifyError("set_items", "Payload too large", ERR_PAYLOAD_TOO_LARGE);
      incomingJsonBuffer = "";
      return;
    }

    // Trim trailing whitespace/newlines before checking for end of JSON
    // (App sends newline delimiter after the JSON array)
    incomingJsonBuffer.trim();

    // Check if buffer ends with ']' (simple heuristic for end of JSON array)
    if (incomingJsonBuffer.endsWith("]")) {
      StaticJsonDocument<24576> doc;  // 100 items × ~200 bytes = 20KB + headroom
      DeserializationError err = deserializeJson(doc, incomingJsonBuffer);
      if (err) {
        DEBUG_LOG("JSON parse failed: %s\n", err.c_str());
        notifyError("set_items", err.c_str(), ERR_INVALID_JSON);
        incomingJsonBuffer = "";  // clear buffer on failure
        return;
      }

      // CRITICAL: Flush any pending count writes BEFORE reading existing data
      // Without this, batched increments (not yet written to NVS) would be lost
      flushPendingNvsWrites();

      if (!nvsBeginSafe("counter", false)) {
        notifyError("set_items", "NVS mutex timeout", ERR_NVS_MUTEX_TIMEOUT);
        incomingJsonBuffer = "";
        return;
      }

      // Save existing counts by deviceItemId before deletion (device is source of truth)
      int existingTotal = prefs.getInt("item_total", 0);
      uint8_t existingDeviceIds[maxPrefsSlots];
      int existingCounts[maxPrefsSlots];
      int existingTodayCounts[maxPrefsSlots];
      int existingResetNumbers[maxPrefsSlots];
      unsigned long existingLastResetTimes[maxPrefsSlots];
      char key[16];  // Buffer for preference keys
      for (int i = 0; i < existingTotal && i < maxPrefsSlots; i++) {
        snprintf(key, sizeof(key), "did_%d", i);
        existingDeviceIds[i] = prefs.getUChar(key, 255);  // 255 = invalid
        snprintf(key, sizeof(key), "c_%d", i);
        existingCounts[i] = prefs.getInt(key, 0);
        snprintf(key, sizeof(key), "tc_%d", i);
        existingTodayCounts[i] = prefs.getInt(key, 0);
        snprintf(key, sizeof(key), "rn_%d", i);
        existingResetNumbers[i] = prefs.getInt(key, 0);
        snprintf(key, sizeof(key), "lr_%d", i);
        existingLastResetTimes[i] = prefs.getULong(key, 0);
      }

      // Clear all slots
      // Note: BLE callbacks run on a separate task, so we can't reset the main loop's watchdog here
      for (int i = 0; i < maxPrefsSlots; i++) {
        snprintf(key, sizeof(key), "n_%d", i);
        prefs.remove(key);
        snprintf(key, sizeof(key), "cat_%d", i);
        prefs.remove(key);
        snprintf(key, sizeof(key), "c_%d", i);
        prefs.remove(key);
        snprintf(key, sizeof(key), "tc_%d", i);
        prefs.remove(key);
        snprintf(key, sizeof(key), "i_%d", i);
        prefs.remove(key);
        snprintf(key, sizeof(key), "did_%d", i);  // deviceItemId (was id_)
        prefs.remove(key);
        snprintf(key, sizeof(key), "r_%d", i);
        prefs.remove(key);
        snprintf(key, sizeof(key), "rv_%d", i);
        prefs.remove(key);
        snprintf(key, sizeof(key), "g_%d", i);
        prefs.remove(key);
        snprintf(key, sizeof(key), "lr_%d", i);
        prefs.remove(key);
        snprintf(key, sizeof(key), "rn_%d", i);
        prefs.remove(key);
      }

      int index = 0;
      for (JsonObject item : doc.as<JsonArray>()) {
        if (index >= maxPrefsSlots) break;

        // Input validation: validate and sanitize all incoming data
        int deviceItemId = item["id"] | index;
        if (!isValidDeviceItemId(deviceItemId)) deviceItemId = index;  // Clamp to valid range

        String name = safeString(item["name"] | "", 30);  // Max 30 chars
        String category = safeString(item["category"] | "", 30);  // Max 30 chars

        int increment = clampInt(item["increment"] | 1, 1, 1000);  // 1-1000
        int reminder = item["reminder"] | REMINDER_NONE;
        if (!isValidReminder(reminder)) reminder = REMINDER_NONE;
        int reminderValue = clampInt(item["reminder_value"] | 0, 0, 9999);  // 0-9999
        int goal = clampInt(item["goal"] | 0, 0, MAX_COUNT);  // 0 = no goal

        // Find existing data for this deviceItemId (device is source of truth)
        int count = 0;
        int todaycount = 0;
        int resetNumber = 0;
        unsigned long lastResetTime = 0;
        bool isExistingItem = false;
        for (int i = 0; i < existingTotal && i < maxPrefsSlots; i++) {
          if (existingDeviceIds[i] == deviceItemId) {
            count = existingCounts[i];
            todaycount = existingTodayCounts[i];
            resetNumber = existingResetNumbers[i];
            lastResetTime = existingLastResetTimes[i];
            isExistingItem = true;
            DEBUG_LOG("🔄 Preserving data for deviceItemId=%d: count=%d, todaycount=%d, resetNumber=%d\n",
                          deviceItemId, count, todaycount, resetNumber);
            break;
          }
        }

        // Override with JSON values ONLY for new items (not existing ones)
        // This ensures device remains source of truth for count data
        if (!isExistingItem) {
          if (item.containsKey("count")) {
            count = item["count"].as<int>();
          }
          if (item.containsKey("todaycount")) {
            todaycount = item["todaycount"].as<int>();
          }
          if (item.containsKey("reset_number")) {
            resetNumber = clampInt(item["reset_number"].as<int>(), 0, 100000);
          }
          if (item.containsKey("lastResetTime")) {
            lastResetTime = item["lastResetTime"];
          }
        }

        // For existing items: accept resetNumber from app if higher (monotonically increasing)
        // This handles app-side "Reset All" which increments resetNumber
        if (isExistingItem && item.containsKey("reset_number")) {
          int appResetNumber = clampInt(item["reset_number"].as<int>(), 0, 100000);
          if (appResetNumber > resetNumber) {
            resetNumber = appResetNumber;
            // Also accept count/todaycount/lastResetTime when reset detected
            if (item.containsKey("count")) {
              count = item["count"].as<int>();
            }
            if (item.containsKey("todaycount")) {
              todaycount = item["todaycount"].as<int>();
            }
            if (item.containsKey("lastResetTime")) {
              lastResetTime = item["lastResetTime"];
            }
            DEBUG_LOG("🔄 App reset detected for deviceItemId=%d: accepting resetNumber=%d from app\n",
                          deviceItemId, resetNumber);
          }
        }

        // Store deviceItemId (replaces string id)
        snprintf(key, sizeof(key), "did_%d", index);
        prefs.putUChar(key, (uint8_t)deviceItemId);
        snprintf(key, sizeof(key), "n_%d", index);
        prefs.putString(key, name);
        snprintf(key, sizeof(key), "cat_%d", index);
        prefs.putString(key, category);
        snprintf(key, sizeof(key), "c_%d", index);
        prefs.putInt(key, count);
        snprintf(key, sizeof(key), "tc_%d", index);
        prefs.putInt(key, todaycount);
        snprintf(key, sizeof(key), "i_%d", index);
        prefs.putInt(key, increment);
        snprintf(key, sizeof(key), "r_%d", index);
        prefs.putInt(key, reminder);
        snprintf(key, sizeof(key), "rv_%d", index);
        prefs.putInt(key, reminderValue);
        snprintf(key, sizeof(key), "g_%d", index);
        prefs.putInt(key, goal);
        snprintf(key, sizeof(key), "lr_%d", index);
        prefs.putULong(key, lastResetTime);
        snprintf(key, sizeof(key), "rn_%d", index);
        prefs.putInt(key, resetNumber);

        DEBUG_LOG("[%d] DeviceItemID=%d Name=%s Category=%s Count=%d TodayCount=%d Incr=%d Reminder=%d ReminderValue=%d Goal=%d ResetTime=%lu ResetNum=%d\n",
              index, deviceItemId, name.c_str(), category.c_str(), count, todaycount, increment, reminder, reminderValue, goal, lastResetTime, resetNumber);
        index++;
      }

      prefs.putInt("item_total", index);

      // Re-lookup selected item index after reordering
      // (items may have moved to different positions)
      if (currentDeviceItemId >= 0) {
        bool found = false;
        for (int i = 0; i < index; i++) {
          snprintf(key, sizeof(key), "did_%d", i);
          uint8_t testId = prefs.getUChar(key, 255);
          if (testId == currentDeviceItemId) {
            currentItemIndex = i;
            prefs.putInt("selected_index", i);
            found = true;
            DEBUG_LOG("🔄 Updated selected index to %d for deviceItemId %d\n", i, currentDeviceItemId);
            break;
          }
        }
        if (!found) {
          // Item not found - could be timing issue or item was deleted
          if (index > 0) {
            // Items exist but selected not found - DON'T reset to none/first item
            // Keep current selection and let incoming set_selected command fix it
            // This prevents brief "none" state during reorder operations
            DEBUG_LOG("⚠️ Selected item deviceItemId=%d not found after reorder, keeping current selection (set_selected will fix)\n", currentDeviceItemId);
          } else {
            // No items at all - must reset to none
            currentItemIndex = 0;
            currentDeviceItemId = -1;
            prefs.putInt("selected_index", 0);
            prefs.putChar("selected_did", -1);
            DEBUG_PRINTLN("⚠️ No items left, selected = none");
          }
        }
      }

      // Refresh runtime variables for currently selected item
      // This ensures updated incrementBy, reminder, etc. take effect immediately
      if (currentDeviceItemId >= 0 && currentItemIndex < index) {
        snprintf(key, sizeof(key), "c_%d", currentItemIndex);
        itemCount = prefs.getInt(key, 0);
        snprintf(key, sizeof(key), "tc_%d", currentItemIndex);
        itemTodayCount = prefs.getInt(key, 0);
        snprintf(key, sizeof(key), "i_%d", currentItemIndex);
        itemIncrement = prefs.getInt(key, 1);
        snprintf(key, sizeof(key), "n_%d", currentItemIndex);
        itemName = prefs.getString(key, "Item");
        snprintf(key, sizeof(key), "cat_%d", currentItemIndex);
        itemCategory = prefs.getString(key, "");
        snprintf(key, sizeof(key), "r_%d", currentItemIndex);
        reminder = prefs.getInt(key, REMINDER_NONE);
        snprintf(key, sizeof(key), "rv_%d", currentItemIndex);
        reminderValue = prefs.getInt(key, 0);
        snprintf(key, sizeof(key), "lr_%d", currentItemIndex);
        lastResetTime = prefs.getULong(key, 0);
        snprintf(key, sizeof(key), "rn_%d", currentItemIndex);
        itemResetNumber = prefs.getInt(key, 0);
        DEBUG_LOG("🔄 Refreshed runtime vars: %s, category=%s, increment=%d, reminder=%d, resetNumber=%d\n",
                      itemName.c_str(), itemCategory.c_str(), itemIncrement, reminder, itemResetNumber);
      }

      nvsEndSafe();

      // Reset batching state when items are refreshed from app
      countsDirty = false;
      incrementsSinceWrite = 0;

      clearLogs();
      incomingJsonBuffer = "";
      DEBUG_PRINTLN("✅ Finished writing to prefs with index-based keys.");
    }
  }
};


// Handle override_chunk command with larger JSON buffer
// App sends: { "cmd": "override_chunk", "index": 0, "items": [...] }
// Separated from WriteCallback because items array needs larger buffer
void handleOverrideChunkCommand(const String& jsonStr) {
  // 10 items per chunk × ~150 bytes = ~1.5KB + headroom
  StaticJsonDocument<2048> doc;
  DeserializationError err = deserializeJson(doc, jsonStr);
  if (err) {
    DEBUG_LOG("❌ Override chunk JSON parse error: %s\n", err.c_str());
    notifyError("override_chunk", err.c_str(), ERR_INVALID_JSON);
    return;
  }

  int chunkIndex = doc["index"] | 0;
  JsonArray items = doc["items"].as<JsonArray>();

  if (items.isNull()) {
    DEBUG_PRINTLN("❌ Override chunk missing items array");
    notifyError("override_chunk", "Missing items array", ERR_MISSING_FIELD);
    return;
  }

  // Acquire NVS lock for saving items
  if (!nvsBeginSafe("counter", false)) {
    notifyError("override_chunk", "NVS mutex timeout", ERR_NVS_MUTEX_TIMEOUT);
    return;
  }

  handleOverrideChunk(chunkIndex, items);
  nvsEndSafe();
}

// Process a complete write command (called when newline delimiter received)
void processWriteCommand(const String& jsonStr) {
    DEBUG_LOG("📨 Processing command: '%s%s'\n",
              jsonStr.substring(0, min((unsigned int)100, jsonStr.length())).c_str(),
              jsonStr.length() > 100 ? "..." : "");

    // Special handling for override_chunk - needs larger buffer due to items array
    // Check for "override_chunk" command prefix to route to special handler
    if (jsonStr.indexOf("\"override_chunk\"") >= 0) {
      handleOverrideChunkCommand(jsonStr);
      return;
    }

    StaticJsonDocument<256> doc;
    DeserializationError err = deserializeJson(doc, jsonStr);
    if (err) {
      DEBUG_LOG("❌ Command JSON parse error: %s\n", err.c_str());
      notifyError("parse", err.c_str(), ERR_INVALID_JSON);
      return;
    }

    String cmd = doc["cmd"] | "";
    cmd.trim();

    if (cmd == "handshake") {  //////////////////// multi-device handshake
      // App sends: { "cmd": "handshake", "uid": "xxx", "sync_seq": 42 }
      String uid = doc["uid"] | "";
      int syncSeq = doc["sync_seq"] | 0;

      if (uid.isEmpty()) {
        notifyError("handshake", "Missing uid parameter", ERR_MISSING_FIELD);
        return;
      }

      handleHandshake(uid, syncSeq);

    } else if (cmd == "clear_logs") {  //////////////////// clear all event logs
      // Format: {"cmd": "clear_logs"} or {"cmd": "clear_logs", "ack": true}
      clearLogs();
      DEBUG_PRINTLN("✅ Logs cleared.");
      sendAckIfRequested(doc, "clear_logs");

    } else if (cmd == "set_selected") {  ///////////////////////// set selected item
      // id is now numeric deviceItemId (0-99), -1 means no selection
      int targetDeviceId = doc["id"] | -1;

      // Flush pending writes for previous item before switching
      flushPendingNvsWrites();

      if (!nvsBeginSafe("counter", false)) {
        notifyError("set_selected", "NVS mutex timeout", ERR_NVS_MUTEX_TIMEOUT);
        return;
      }

      int total = prefs.getInt("item_total", 0);
      if (total == 0 || targetDeviceId < 0) {
        DEBUG_PRINTLN("⚠️ No items available to select.");
        currentDeviceItemId = -1;
        prefs.putChar("selected_did", -1);
        prefs.putInt("selected_index", 0);
        nvsEndSafe();
        return;
      }

      bool found = false;
      char key[16];  // Buffer for preference keys
      for (int i = 0; i < total; i++) {
        snprintf(key, sizeof(key), "did_%d", i);
        uint8_t testId = prefs.getUChar(key, 255);
        if (testId == targetDeviceId) {
          currentDeviceItemId = targetDeviceId;
          currentItemIndex = i;
          prefs.putChar("selected_did", targetDeviceId);
          prefs.putInt("selected_index", i);
          snprintf(key, sizeof(key), "c_%d", i);
          itemCount = prefs.getInt(key, 0);
          snprintf(key, sizeof(key), "tc_%d", i);
          itemTodayCount = prefs.getInt(key, 0);
          snprintf(key, sizeof(key), "i_%d", i);
          itemIncrement = prefs.getInt(key, 1);
          snprintf(key, sizeof(key), "n_%d", i);
          itemName = prefs.getString(key, "Item");
          snprintf(key, sizeof(key), "cat_%d", i);
          itemCategory = prefs.getString(key, "");
          snprintf(key, sizeof(key), "r_%d", i);
          reminder = prefs.getInt(key, REMINDER_NONE);
          snprintf(key, sizeof(key), "rv_%d", i);
          reminderValue = prefs.getInt(key, 0);
          snprintf(key, sizeof(key), "lr_%d", i);
          lastResetTime = prefs.getULong(key, 0);
          snprintf(key, sizeof(key), "rn_%d", i);
          itemResetNumber = prefs.getInt(key, 0);

          DEBUG_LOG("✅ Selected item [%d]: deviceItemId=%d (%s) category=%s resetNumber=%d\n", i, targetDeviceId, itemName.c_str(), itemCategory.c_str(), itemResetNumber);
          found = true;
          nvsEndSafe();
          // Notify app of current item state (spec: set_selected sends item_delta)
          notifyItemDelta(currentDeviceItemId, itemCount, itemTodayCount, lastResetTime, itemResetNumber);
          return;
        }
      }

      if (!found) {
        DEBUG_LOG("⚠️ Item with deviceItemId=%d not found.\n", targetDeviceId);
      }
      nvsEndSafe();

    } else if (cmd == "override_start") {  //////////////////// multi-device override start
      // App sends: { "cmd": "override_start", "uid": "xxx", "sync_seq": N, "total_chunks": M }
      String uid = doc["uid"] | "";
      int syncSeq = doc["sync_seq"] | 0;
      int totalChunks = doc["total_chunks"] | 0;

      // Acquire NVS lock for the override operation
      if (!nvsBeginSafe("counter", false)) {
        notifyError("override_start", "NVS mutex timeout", ERR_NVS_MUTEX_TIMEOUT);
        return;
      }
      handleOverrideStart(uid, syncSeq, totalChunks);
      nvsEndSafe();

    } else if (cmd == "override_end") {  //////////////////// multi-device override end
      // App sends: { "cmd": "override_end", "selected_id": X }
      int selectedId = doc["selected_id"] | -1;

      // Acquire NVS lock for finalization
      if (!nvsBeginSafe("counter", false)) {
        notifyError("override_end", "NVS mutex timeout", ERR_NVS_MUTEX_TIMEOUT);
        return;
      }
      handleOverrideEnd(selectedId);
      nvsEndSafe();

    } else if (cmd == "sync_complete") {  //////////////////// multi-device sync complete
      // App sends: { "cmd": "sync_complete", "sync_seq": N }
      int syncSeq = doc["sync_seq"] | 0;
      handleSyncComplete(syncSeq);

    } else if (cmd == "delete_item") {  //////////////////// delete single item
      // App sends: { "cmd": "delete_item", "deviceItemId": N }
      // More efficient than set_items when deleting a single item
      int targetDeviceId = doc["deviceItemId"] | -1;

      if (targetDeviceId < 0) {
        notifyError("delete_item", "Missing deviceItemId", ERR_MISSING_FIELD);
        return;
      }

      if (!nvsBeginSafe("counter", false)) {
        notifyError("delete_item", "NVS mutex timeout", ERR_NVS_MUTEX_TIMEOUT);
        return;
      }

      int total = prefs.getInt("item_total", 0);
      char key[16];
      int foundIndex = -1;

      // Find the slot index for this deviceItemId
      for (int i = 0; i < total; i++) {
        snprintf(key, sizeof(key), "did_%d", i);
        uint8_t testId = prefs.getUChar(key, 255);
        if (testId == (uint8_t)targetDeviceId) {
          foundIndex = i;
          break;
        }
      }

      if (foundIndex < 0) {
        nvsEndSafe();
        notifyError("delete_item", "Item not found", ERR_ITEM_NOT_FOUND);
        return;
      }

      // Check if we're deleting the currently selected item
      bool deletingSelected = (currentDeviceItemId == targetDeviceId);

      // Shift all items after foundIndex down by one
      for (int i = foundIndex; i < total - 1; i++) {
        // Copy slot i+1 to slot i
        snprintf(key, sizeof(key), "did_%d", i + 1);
        uint8_t did = prefs.getUChar(key, 0);
        snprintf(key, sizeof(key), "did_%d", i);
        prefs.putUChar(key, did);

        snprintf(key, sizeof(key), "n_%d", i + 1);
        String name = prefs.getString(key, "");
        snprintf(key, sizeof(key), "n_%d", i);
        prefs.putString(key, name);

        snprintf(key, sizeof(key), "cat_%d", i + 1);
        String cat = prefs.getString(key, "");
        snprintf(key, sizeof(key), "cat_%d", i);
        prefs.putString(key, cat);

        snprintf(key, sizeof(key), "c_%d", i + 1);
        int count = prefs.getInt(key, 0);
        snprintf(key, sizeof(key), "c_%d", i);
        prefs.putInt(key, count);

        snprintf(key, sizeof(key), "tc_%d", i + 1);
        int todayCount = prefs.getInt(key, 0);
        snprintf(key, sizeof(key), "tc_%d", i);
        prefs.putInt(key, todayCount);

        snprintf(key, sizeof(key), "i_%d", i + 1);
        int inc = prefs.getInt(key, 1);
        snprintf(key, sizeof(key), "i_%d", i);
        prefs.putInt(key, inc);

        snprintf(key, sizeof(key), "r_%d", i + 1);
        int rem = prefs.getInt(key, 0);
        snprintf(key, sizeof(key), "r_%d", i);
        prefs.putInt(key, rem);

        snprintf(key, sizeof(key), "rv_%d", i + 1);
        int remVal = prefs.getInt(key, 0);
        snprintf(key, sizeof(key), "rv_%d", i);
        prefs.putInt(key, remVal);

        snprintf(key, sizeof(key), "g_%d", i + 1);
        int gl = prefs.getInt(key, 0);
        snprintf(key, sizeof(key), "g_%d", i);
        prefs.putInt(key, gl);

        snprintf(key, sizeof(key), "lr_%d", i + 1);
        unsigned long lr = prefs.getULong(key, 0);
        snprintf(key, sizeof(key), "lr_%d", i);
        prefs.putULong(key, lr);

        snprintf(key, sizeof(key), "rn_%d", i + 1);
        int rn = prefs.getInt(key, 0);
        snprintf(key, sizeof(key), "rn_%d", i);
        prefs.putInt(key, rn);
      }

      // Clear the last slot (now a duplicate)
      clearItemSlot(total - 1);

      // Update item_total
      int newTotal = total - 1;
      prefs.putInt("item_total", newTotal);

      // Handle selection after deletion
      if (newTotal == 0) {
        // No items left
        currentDeviceItemId = -1;
        currentItemIndex = -1;
        prefs.putChar("selected_did", -1);
        prefs.putInt("selected_index", 0);
        itemName = "";
        itemCount = 0;
        itemTodayCount = 0;
      } else if (deletingSelected) {
        // Select first item if we deleted the selected one
        currentItemIndex = 0;
        snprintf(key, sizeof(key), "did_%d", 0);
        currentDeviceItemId = prefs.getUChar(key, 0);
        prefs.putChar("selected_did", currentDeviceItemId);
        prefs.putInt("selected_index", 0);
        // Load the new selected item's data
        snprintf(key, sizeof(key), "n_%d", 0);
        itemName = prefs.getString(key, "Item");
        snprintf(key, sizeof(key), "c_%d", 0);
        itemCount = prefs.getInt(key, 0);
        snprintf(key, sizeof(key), "tc_%d", 0);
        itemTodayCount = prefs.getInt(key, 0);
        snprintf(key, sizeof(key), "i_%d", 0);
        itemIncrement = prefs.getInt(key, 1);
      } else if (currentItemIndex > foundIndex) {
        // Adjust current index if it was after the deleted item
        currentItemIndex--;
        prefs.putInt("selected_index", currentItemIndex);
      }

      nvsEndSafe();

      // Send success response
      StaticJsonDocument<128> response;
      response["status"] = "deleted";
      response["deviceItemId"] = targetDeviceId;
      response["item_total"] = newTotal;
      String responseStr;
      serializeJson(response, responseStr);
      sendJsonResponse(responseStr);

      DEBUG_LOG("✅ Deleted item deviceItemId=%d (was at index %d), %d items remaining\n",
                    targetDeviceId, foundIndex, newTotal);

    } else if (cmd == "unpair") {  //////////////////// unpair device
      // App sends: { "cmd": "unpair" }
      // Used when user deletes their account while connected
      // Clears pairing data so device can be paired to a new account

      if (!nvsBeginSafe("counter", false)) {
        notifyError("unpair", "NVS mutex timeout", ERR_NVS_MUTEX_TIMEOUT);
        return;
      }

      // Clear pairing data
      prefs.remove(NVS_KEY_PAIRED_UID);
      prefs.remove(NVS_KEY_SYNC_SEQ_NO);

      // Reset selection state
      prefs.putInt("selected_index", 0);
      prefs.putChar("selected_did", -1);

      nvsEndSafe();

      // Set device to pairing mode
      isPairingMode = true;
      inConflictState = false;

      // Clear runtime state
      currentDeviceItemId = -1;
      currentItemIndex = -1;
      itemName = "";
      itemCount = 0;
      itemTodayCount = 0;

      // Send success response
      StaticJsonDocument<64> response;
      response["status"] = "unpaired";
      String responseStr;
      serializeJson(response, responseStr);
      sendJsonResponse(responseStr);

      DEBUG_PRINTLN("✅ Device unpaired - ready for new account");

      // Display will update to "AWAITING SETUP" on next refresh

    } else if (cmd == "set_time") {  //////////////////// set time
      // Format: {"cmd": "set_time", "utc_time": "yyyy-MM-dd HH:mm:ss", "offset": minutes}
      // Optional: {"cmd": "set_time", ..., "ack": true} for acknowledgment
      const char* utcTimeStr = doc["utc_time"];
      int offsetMinutes = doc["offset"] | 0;
      if (utcTimeStr) {
        // Parse the UTC time string
        int y, mo, d, h, mi, s;
        sscanf(utcTimeStr, "%d-%d-%d %d:%d:%d", &y, &mo, &d, &h, &mi, &s);
        DateTime utcTime(y, mo, d, h, mi, s);
        // Set RTC to UTC time
        rtc.adjust(utcTime);
        // Store offset in prefs
        prefs.begin("counter", false);
        prefs.putInt("tz_offset", offsetMinutes);
        prefs.end();
        DEBUG_LOG("✅ RTC set to UTC: %04d-%02d-%02d %02d:%02d:%02d (local offset: %d min)\n",
                      y, mo, d, h, mi, s, offsetMinutes);
        // Trigger daily reset check in case the date changed
        resetTodayCountsIfNeeded();
        sendAckIfRequested(doc, "set_time", true);
      } else {
        DEBUG_PRINTLN("❌ set_time: missing utc_time parameter");
        sendAckIfRequested(doc, "set_time", false, "Missing utc_time parameter");
      }

    } else if (cmd == "prepare_read") {  //////////////////// prepare data for reading
      const char* t = doc["type"];
      int page = doc["page"] | 0;
      if (!t) return;
      String type = String(t);
      currentPage = page;
      if (type == "prefs") {
        currentReadMode = READ_PREFS;
      } else if (type == "logs") {
        currentReadMode = READ_LOGS;
      }
      // Note: Actual sending happens in loop() when currentReadMode is set

    } else {
      DEBUG_LOG("⚠️ Unknown command: %s\n", cmd.c_str());
    }
}

class WriteCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    String chunk = String(c->getValue().c_str());

    // Update timestamp for chunk timeout detection
    lastChunkReceived = millis();

    // Accumulate chunks in buffer
    writeCommandBuffer += chunk;

    // Check for buffer overflow
    if (writeCommandBuffer.length() > 8192) {
      DEBUG_PRINTLN("❌ Write command buffer overflow (>8KB)");
      notifyError("write", "Buffer overflow", ERR_BUFFER_OVERFLOW);
      writeCommandBuffer = "";
      return;
    }

    // Check for newline delimiter indicating complete message
    int newlinePos = writeCommandBuffer.indexOf('\n');
    while (newlinePos >= 0) {
      // Extract complete command (everything before newline)
      String completeCmd = writeCommandBuffer.substring(0, newlinePos);
      completeCmd.trim();

      // Remove processed command from buffer (including newline)
      writeCommandBuffer = writeCommandBuffer.substring(newlinePos + 1);

      // Process the complete command
      if (completeCmd.length() > 0) {
        processWriteCommand(completeCmd);
      }

      // Check for another newline (multiple commands in one transfer)
      newlinePos = writeCommandBuffer.indexOf('\n');
    }
  }
};


// Track BLE connection state
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* p) override {
    isConnected = true;
    recordActivity();  // Wake from low power mode on connection
    DEBUG_PRINTLN("✅ Connected!");
  }
  void onDisconnect(BLEServer* p) override {
    // Flush any pending NVS writes before disconnecting to prevent data loss
    flushPendingNvsWrites();

    // Exit conflict state on disconnect - device returns to normal operation
    // User can reconnect to retry sync
    if (inConflictState) {
      exitConflictState();
    }

    // Clear sync state flags to avoid stale state on next connection
    needsSendSyncData = false;
    needsSendLogs = false;
    syncDataRequestedAt = 0;

    // Clear BLE transmit queue
    bleTransmit.inProgress = false;
    bleTransmit.bufferLen = 0;
    bleTransmit.buffer[0] = '\0';
    for (int i = 0; i < BLE_TX_QUEUE_SIZE; i++) {
      if (bleTransmit.queue[i] != NULL) {
        free(bleTransmit.queue[i]);
        bleTransmit.queue[i] = NULL;
      }
    }
    bleTransmit.queueCount = 0;
    bleTransmit.queueHead = 0;
    bleTransmit.queueTail = 0;

    isConnected = false;
    DEBUG_PRINTLN("🔌 Client disconnected — restarting advertising...");
    BLEDevice::startAdvertising();
  }
};

// GAP event callback to log connection parameter changes
static void onGapEvent(esp_gap_ble_cb_event_t event, esp_ble_gap_cb_param_t *param) {
  if (event == ESP_GAP_BLE_UPDATE_CONN_PARAMS_EVT) {
    // conn_int is the actual negotiated connection interval (in 1.25ms units)
    float interval = param->update_conn_params.conn_int * 1.25;

    DEBUG_PRINTLN("📊 Connection parameters updated:");
    DEBUG_LOG("   - Actual interval: %.2fms\n", interval);
    DEBUG_LOG("   - Latency: %d\n", param->update_conn_params.latency);
    DEBUG_LOG("   - Timeout: %dms\n", param->update_conn_params.timeout * 10);
    DEBUG_LOG("   - Status: %s\n",
                  param->update_conn_params.status == ESP_BT_STATUS_SUCCESS ? "SUCCESS" : "FAILED");

    // Log interpretation
    if (interval <= 15) {
      DEBUG_PRINTLN("   ✅ HIGH priority (~7.5ms interval)");
    } else if (interval <= 50) {
      DEBUG_PRINTLN("   ⚡ BALANCED priority (~30ms interval)");
    } else {
      DEBUG_PRINTLN("   🔋 LOW priority (>50ms interval)");
    }
  }
}

// BLE peripheral and characteristic setup
void setupBLE() {
  BLEDevice::init("Traxelos_One");

  // Log device instance ID (MAC address) now that BLE is initialized
  DEBUG_LOG("🆔 Device Instance ID (MAC): %s\n", getDeviceInstanceId().c_str());

  // Set maximum MTU to allow larger packets (default is 23, max is 517)
  // This allows the app to negotiate larger MTU for faster transfers
  BLEDevice::setMTU(517);
  DEBUG_PRINTLN("📦 BLE MTU set to 517 bytes (max)");

  // Register GAP callback to log connection parameter changes
  esp_ble_gap_register_callback(onGapEvent);
  DEBUG_PRINTLN("📡 BLE GAP callback registered for connection parameter logging");

  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  BLEService* svc = server->createService(SERVICE_UUID);

  NotifyChar = svc->createCharacteristic(CHAR_NOTIFY_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  NotifyChar->addDescriptor(new BLE2902());

  setItemsChar = svc->createCharacteristic(CHAR_SET_ITEMS_UUID, BLECharacteristic::PROPERTY_WRITE);
  setItemsChar->setCallbacks(new SetItemsCallback());

  writeChar = svc->createCharacteristic(CHAR_WRITE_UUID, BLECharacteristic::PROPERTY_WRITE);
  writeChar->setCallbacks(new WriteCallback());


  readChar = svc->createCharacteristic(CHAR_READ_UUID, BLECharacteristic::PROPERTY_READ);
  readChar->setValue("[]");  // default empty

  svc->start();
  BLEDevice::getAdvertising()->addServiceUUID(SERVICE_UUID);
  BLEDevice::getAdvertising()->setScanResponse(true);

  //Set advertising parameters (intervals + connectable mode)
  BLEDevice::getAdvertising()->setMinInterval(0x20);  // 32 * 0.625ms = 20ms
  BLEDevice::getAdvertising()->setMaxInterval(0x40);  // 64 * 0.625ms = 40ms
  BLEDevice::getAdvertising()->setScanResponse(true);
  BLEDevice::getAdvertising()->setAppearance(0x0000);  // Optional: generic device
  BLEDevice::getAdvertising()->start();


}

void updateReadChar() {
  String jsonOut;
  if (currentReadMode == READ_PREFS) {
    // Flush any pending NVS writes so prefs reflect current RAM values
    flushPendingNvsWrites();
    jsonOut = getPrefsJson();
    //DEBUG_PRINTLN("PrefsSent - Details skipped");
    DEBUG_LOG("PrefsSent (%u bytes)\n", jsonOut.length());
    DEBUG_PRINTLN(jsonOut);
  } else if (currentReadMode == READ_LOGS) {
    jsonOut = getLogsAsString(currentPage);  // Convert all logs into one array
    //DEBUG_PRINTLN("LogsSent - Details skipped");
    //DEBUG_PRINTLN(jsonOut);  //////////////////////////////////////////////////Sent logs
    DEBUG_LOG("LogsSent page %u (%u bytes)\n", currentPage, jsonOut.length());
    DEBUG_PRINTLN(jsonOut);   // <- print full JSON here
  } else {
    return;
  }

  readChar->setValue(jsonOut.c_str());
 //   if (currentReadMode == READ_LOGS) {
 //   clearLogs();                        // ✅ ...before clearing RAM
 // }
  currentReadMode = READ_NONE;  // Reset after preparing
}



// ============================================================================
// EVENT NOTIFICATION - Action History
// ============================================================================
// Purpose: Record WHAT JUST HAPPENED for history/logging/analytics.
// Contains: event type, timestamp, itemId, count, increment, resetNumber
//
// This is DIFFERENT from notifyItemDelta():
//   - event      = "here's what just happened" (for history/logging)
//   - item_delta = "here's the current state" (for UI updates)
//
// When sent:
//   - After increment button press (paired with notifyItemDelta)
//   - After reset button press (paired with notifyItemDelta)
//   - After switch button press (NO item_delta - state didn't change for switched-from item)
//
// Note: For reset events, pass the OLD resetNumber before incrementing
// Uses numeric deviceItemId (0-99) for memory optimization - app looks up name
// ============================================================================
void notifyEvent(String event, int resetNum = -1) {
  if (!isConnected || NotifyChar == nullptr) return;

  int eventResetNumber = (resetNum >= 0) ? resetNum : itemResetNumber;

  StaticJsonDocument<256> doc;  // ~120 bytes actual, 256 with headroom

  // Create the standard JSON structure
  JsonObject root = doc.to<JsonObject>();
  root["type"] = "event";

  // Create the data object with event details
  JsonObject data = root.createNestedObject("data");
  data["timestamp"] = rtc.now().unixtime();
  data["itemId"] = (int)currentDeviceItemId;  // Numeric deviceItemId - app looks up name
  data["event"] = event;
  data["increment"] = itemIncrement;
  data["count"] = itemCount;
  data["resetNumber"] = eventResetNumber;

  String s;
  serializeJson(root, s);
  s += "\n";  // 🧩 newline as end-of-message marker

  // Use larger MTU for faster transfers (event JSON is typically ~150 bytes, fits in one chunk)
  const int mtu = 180;
  for (int i = 0; i < s.length(); i += mtu) {
    String chunk = s.substring(i, min(i + mtu, (int)s.length()));  //min to end the loop if empty info detected in the last round
    NotifyChar->setValue(chunk.c_str());
    NotifyChar->notify();
    delay(20);  // Unified 20ms delay for reliable BLE chunk transmission
  }
  //DEBUG_PRINTLN("📤 Sent notifyEvent:");
  //DEBUG_PRINTLN(s);
}

// Handle local commands: 'u' (up), 'r' (reset), 's' (switch item)
void handleCommand(char cmd) {
  recordActivity();  // Wake from low power mode on button press

  // ============== CONFLICT STATE CHECK ==============
  // In conflict state, all buttons are disabled - user must resolve via app
  if (inConflictState) {
    displayMessage("SEE APP");  // Remind user to check app
    DEBUG_LOG("⛔ Button '%c' ignored - device in conflict state (SEE APP)\n", cmd);
    return;
  }

  if (!nvsBeginSafe("counter", false)) {
    DEBUG_PRINTLN("⚠️ NVS mutex timeout in handleCommand");
    return;
  }

  int total = prefs.getInt("item_total", 0);
  char key[16];  // Buffer for preference keys
  if (cmd == 'u') {
    // Increment current item count and update in prefs using indexed keys
    if (currentDeviceItemId < 0) {
      DEBUG_PRINTLN("No Item Selected");
      notifyError("increment", "No item selected", ERR_NO_ITEM_SELECTED);
      nvsEndSafe();
      return;
    }
    // Clamp check: already at max count
    if (itemCount >= MAX_COUNT) {
      triggerVibrationPattern(2);  // Double vibrate for max reached
      displayMessage("MAX REACHED");
      // Send delta so app stays in sync, but no event (no actual change)
      if (isConnected) notifyItemDelta(currentDeviceItemId, itemCount, itemTodayCount, lastResetTime, itemResetNumber);
      nvsEndSafe();
      return;
    }

    //update first
    itemCount += itemIncrement;
    // Clamp to MAX_COUNT if increment would exceed it
    if (itemCount > MAX_COUNT) {
      itemCount = MAX_COUNT;
      triggerVibrationPattern(2);  // Double vibrate for max reached
      displayMessage("MAX REACHED");
    }
    itemTodayCount += itemIncrement;
    if (itemTodayCount > MAX_COUNT) itemTodayCount = MAX_COUNT;
    incrementsSinceWrite++;
    countsDirty = true;

    //extract from prefs
    snprintf(key, sizeof(key), "g_%d", currentItemIndex);
    int goal = prefs.getInt(key, 0);
    snprintf(key, sizeof(key), "r_%d", currentItemIndex);
    reminder = prefs.getInt(key, REMINDER_NONE);
    snprintf(key, sizeof(key), "rv_%d", currentItemIndex);
    reminderValue = prefs.getInt(key, 0);

    if (goal > 0 && itemCount >= goal && (itemCount - itemIncrement) < goal) {
      triggerVibrationPattern(3);  // Triple vibrate for goal reached
    } else if (reminder == REMINDER_TARGET && itemCount >= reminderValue && (itemCount - itemIncrement) < reminderValue) {
      triggerVibrationNonBlocking();
    } else if (reminder == REMINDER_INTERVAL && reminderValue > 0 && itemCount > 0 && itemCount % reminderValue == 0){
      triggerVibrationNonBlocking();
    }

    // Batch NVS writes - only write every 10 increments to reduce flash wear
    if (incrementsSinceWrite >= 10) {
      snprintf(key, sizeof(key), "c_%d", currentItemIndex);
      prefs.putInt(key, itemCount);
      snprintf(key, sizeof(key), "tc_%d", currentItemIndex);
      prefs.putInt(key, itemTodayCount);
      incrementsSinceWrite = 0;
      countsDirty = false;
      DEBUG_PRINTLN("📝 NVS batch write (10 increments)");
    }

    // Only log when disconnected - when connected, real-time events are synced directly
    if (!isConnected) logEvent(EVENT_INCREMENT);
    // Send delta update instead of full prefs (much smaller payload)
    if (isConnected) notifyItemDelta(currentDeviceItemId, itemCount, itemTodayCount, lastResetTime, itemResetNumber);
    delay(50);  // Brief gap between notifications
    if (isConnected) notifyEvent("increment");

    // Debug: print category and item index
    DEBUG_LOG("📍 Category: %s | Item index: %d/%d\n",
                  itemCategory.length() > 0 ? itemCategory.c_str() : "Uncategorized",
                  currentItemIndex, total);

  } else if (cmd == 'r') {
    // Reset current item count and update in prefs using indexed keys
    if (currentDeviceItemId < 0) {
      DEBUG_PRINTLN("No Item Selected");
      notifyError("reset", "No item selected", ERR_NO_ITEM_SELECTED);
      nvsEndSafe();
      return;
    }

    // Option A: Log reset event with OLD resetNumber before incrementing
    int oldResetNumber = itemResetNumber;

    itemCount = 0;
    itemTodayCount = 0;
    snprintf(key, sizeof(key), "c_%d", currentItemIndex);
    prefs.putInt(key, itemCount);
    snprintf(key, sizeof(key), "tc_%d", currentItemIndex);
    prefs.putInt(key, itemTodayCount);

    // Reset clears any pending batched writes since we just wrote
    countsDirty = false;
    incrementsSinceWrite = 0;

    lastResetTime = rtc.now().unixtime();
    snprintf(key, sizeof(key), "lr_%d", currentItemIndex);
    prefs.putULong(key, lastResetTime);

    // Log the reset event with OLD resetNumber (this reset ends period N)
    logEvent(EVENT_RESET, oldResetNumber);

    // Now increment resetNumber for the new period
    itemResetNumber++;
    snprintf(key, sizeof(key), "rn_%d", currentItemIndex);
    prefs.putInt(key, itemResetNumber);

    DEBUG_LOG("🔄 Reset: period %d ended, now in period %d\n", oldResetNumber, itemResetNumber);

    nvsEndSafe();  // Close prefs BEFORE notifying to avoid nested prefs.begin() issues

    // Send delta update with NEW resetNumber (app needs current state)
    if (isConnected) notifyItemDelta(currentDeviceItemId, itemCount, itemTodayCount, lastResetTime, itemResetNumber);
    delay(50);  // Brief gap between notifications
    // Send event notification with OLD resetNumber (the reset that ended period N)
    if (isConnected) notifyEvent("reset", oldResetNumber);
    return;  // Already closed prefs, skip the final nvsEndSafe()

  } else if (cmd == 's') {
    if (total == 0) {
      nvsEndSafe();
      displayMessage("NO ITEMS\nSYNC TO APP");
      return;
    }

    // Fixed-task constraint: cannot switch items when offline
    if (!isConnected) {
      nvsEndSafe();
      displayMessage("SWITCH DISABLED\nSYNC TO APP");
      DEBUG_PRINTLN("⛔ Item switch blocked - device offline");
      return;
    }

    // Flush pending writes for current item before switching
    if (countsDirty) {
      snprintf(key, sizeof(key), "c_%d", currentItemIndex);
      prefs.putInt(key, itemCount);
      snprintf(key, sizeof(key), "tc_%d", currentItemIndex);
      prefs.putInt(key, itemTodayCount);
      countsDirty = false;
      incrementsSinceWrite = 0;
      DEBUG_PRINTLN("📝 NVS flush before item switch");
    }

    // Cycle to the next item index
    currentItemIndex = (currentItemIndex + 1) % total;
    snprintf(key, sizeof(key), "did_%d", currentItemIndex);
    currentDeviceItemId = prefs.getUChar(key, currentItemIndex);  // Default to index

    // Update state with new selection
    prefs.putChar("selected_did", currentDeviceItemId);
    prefs.putInt("selected_index", currentItemIndex);
    snprintf(key, sizeof(key), "c_%d", currentItemIndex);
    itemCount = prefs.getInt(key, 0);
    snprintf(key, sizeof(key), "tc_%d", currentItemIndex);
    itemTodayCount = prefs.getInt(key, 0);
    snprintf(key, sizeof(key), "i_%d", currentItemIndex);
    itemIncrement = prefs.getInt(key, 1);
    snprintf(key, sizeof(key), "n_%d", currentItemIndex);
    itemName = prefs.getString(key, "Item");
    snprintf(key, sizeof(key), "cat_%d", currentItemIndex);
    itemCategory = prefs.getString(key, "");
    snprintf(key, sizeof(key), "r_%d", currentItemIndex);
    reminder = prefs.getInt(key, REMINDER_NONE);
    snprintf(key, sizeof(key), "rv_%d", currentItemIndex);
    reminderValue = prefs.getInt(key, 0);
    snprintf(key, sizeof(key), "lr_%d", currentItemIndex);
    lastResetTime = prefs.getULong(key, 0);
    snprintf(key, sizeof(key), "rn_%d", currentItemIndex);
    itemResetNumber = prefs.getInt(key, 0);

    nvsEndSafe();  // Close prefs BEFORE notifying to avoid nested prefs.begin() issues

    //logEvent(EVENT_SWITCH);
    if (isConnected) notifyEvent("switch");

    DEBUG_LOG("Switch to: %s (index %d)\n", itemName.c_str(), currentItemIndex);
    // Debug: print category and item index
    DEBUG_LOG("📍 Category: %s | Item index: %d/%d\n",
                  itemCategory.length() > 0 ? itemCategory.c_str() : "Uncategorized",
                  currentItemIndex, total);
    return;  // Already closed prefs, skip the final nvsEndSafe()
  }

  nvsEndSafe();


  //DateTime now = rtc.now();
  // 📢 Display current item status after any command
  DEBUG_LOG("%s%s%s%s [DeviceID: %d] Count: %d, TodayCount: %d (+%d)\n",
            itemName.c_str(),
            itemCategory.length() > 0 ? " (" : "",
            itemCategory.length() > 0 ? itemCategory.c_str() : "",
            itemCategory.length() > 0 ? ")" : "",
            currentDeviceItemId, itemCount, itemTodayCount, itemIncrement);

}

void updateLocalTime() {
  DateTime nowUtc = rtc.now();

  int offsetMin = 0;
  if (nvsBeginSafe("counter", true)) {  // Read-only
    offsetMin = prefs.getInt("tz_offset", 0);
    nvsEndSafe();
  }

  localTimestamp = nowUtc.unixtime() + offsetMin * 60;
  localTime = DateTime(localTimestamp);
}


void resetTodayCountsIfNeeded(){//bool forceReset = false) {

  updateLocalTime();

  char todayStr[11]; // "YYYY-MM-DD" + null
  snprintf(todayStr, sizeof(todayStr), "%04d-%02d-%02d", localTime.year(), localTime.month(), localTime.day());

  if (!nvsBeginSafe("counter", false)) return;
  String last_reset_date = prefs.getString("last_reset_date", "");

  if (last_reset_date != String(todayStr)) {
    DEBUG_PRINTLN("🔄 New day detected. Resetting todayCount for all items.");
    DEBUG_PRINTLN(String(todayStr));

    // Use UTC timestamp for lastResetTime (consistent with event timestamps and manual reset)
    // Events use rtc.now().unixtime() (UTC), so lastResetTime must also be UTC
    time_t utcTimestamp = rtc.now().unixtime();

    int total = prefs.getInt("item_total", 0);
    char key[16];  // Buffer for preference keys
    for (int i = 0; i < total; i++) {
      // Reset todaycount to 0
      snprintf(key, sizeof(key), "tc_%d", i);
      prefs.putInt(key, 0);

      // Update lastResetTime to UTC timestamp (not localTimestamp which has offset applied)
      snprintf(key, sizeof(key), "lr_%d", i);
      prefs.putULong(key, utcTimestamp);

      DEBUG_LOG("Reset: %s, lastResetTime: %lu (UTC)\n", key, utcTimestamp);
    }

    if (currentDeviceItemId >= 0) {
      itemTodayCount = 0;  // Also reset runtime variable
      lastResetTime = utcTimestamp;
    }

    prefs.putString("last_reset_date", todayStr);
  }// else {
   // DEBUG_PRINTLN("✅ todayCount is already up to date.");
   // DEBUG_PRINTLN(todayStr);
  //}

  nvsEndSafe();
}




// Device boot initialization
void setup() {
  Serial.begin(115200);

  // Initialize NVS mutex for thread-safe access
  nvsMutex = xSemaphoreCreateMutex();
  DEBUG_PRINTLN("🔒 NVS mutex initialized");

  if (!rtc.begin()) {
    DEBUG_PRINTLN("❌ RTC not found!");
  } else {
    DEBUG_PRINTLN("✅ RTC connected.");
  }
  if (rtc.lostPower()) {
    DEBUG_PRINTLN("⚠️ RTC lost power. Setting to compile time.");
    rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
  }

  // Note: Using raw prefs.begin here since mutex is now initialized
  // nvsBeginSafe handles the mutex properly
  if (!nvsBeginSafe("counter", false)) {
    DEBUG_PRINTLN("❌ Failed to open NVS in setup");
    return;
  }

  // ============== MULTI-DEVICE: Device Instance ID ==============
  // Device Instance ID is the BLE MAC address (logged after BLE init in setupBLE)

  // ============== MULTI-DEVICE: Pairing Mode Detection ==============
  // Check if device is paired (has a paired_uid set)
  String pairedUid = prefs.getString(NVS_KEY_PAIRED_UID, "");
  int syncSeqNo = prefs.getInt(NVS_KEY_SYNC_SEQ_NO, 0);
  DEBUG_LOG("🔗 Paired UID: %s\n", pairedUid.isEmpty() ? "(unpaired)" : pairedUid.c_str());
  DEBUG_LOG("📊 Sync Sequence: %d\n", syncSeqNo);

  // ✅ Verify and store item_total
  int verifiedTotal = 0;
  char key[16];  // Buffer for preference keys
  for (int i = 0; i < maxPrefsSlots; i++) {
    // Check if deviceItemId exists for this slot (or name as fallback)
    snprintf(key, sizeof(key), "did_%d", i);
    uint8_t did = prefs.getUChar(key, 255);
    snprintf(key, sizeof(key), "n_%d", i);
    String name = prefs.getString(key, "");
    if (did != 255 || name.length() > 0) {
      verifiedTotal++;
    } else {
      break;
    }
  }
  prefs.putInt("item_total", verifiedTotal);
  DEBUG_LOG("✅ Verified item_total on boot: %d\n", verifiedTotal);


  currentDeviceItemId = prefs.getChar("selected_did", -1);
  DEBUG_LOG("CurrentDeviceItemId:%d", currentDeviceItemId);
  currentItemIndex = prefs.getInt("selected_index", 0);
  snprintf(key, sizeof(key), "c_%d", currentItemIndex);
  itemCount = prefs.getInt(key, 0);
  snprintf(key, sizeof(key), "tc_%d", currentItemIndex);
  itemTodayCount = prefs.getInt(key, 0);
  snprintf(key, sizeof(key), "i_%d", currentItemIndex);
  itemIncrement = prefs.getInt(key, 1);
  snprintf(key, sizeof(key), "n_%d", currentItemIndex);
  itemName = prefs.getString(key, "Item");
  snprintf(key, sizeof(key), "cat_%d", currentItemIndex);
  itemCategory = prefs.getString(key, "");
  snprintf(key, sizeof(key), "r_%d", currentItemIndex);
  reminder = prefs.getInt(key, REMINDER_NONE);
  snprintf(key, sizeof(key), "rv_%d", currentItemIndex);
  reminderValue = prefs.getInt(key, 0);
  snprintf(key, sizeof(key), "lr_%d", currentItemIndex);
  lastResetTime = prefs.getULong(key, 0);
  snprintf(key, sizeof(key), "rn_%d", currentItemIndex);
  itemResetNumber = prefs.getInt(key, 0);

  if (currentItemIndex >= verifiedTotal) {
    currentItemIndex = 0;
    prefs.putInt("selected_index", 0);
    snprintf(key, sizeof(key), "did_%d", 0);
    currentDeviceItemId = prefs.getChar(key, -1);
    prefs.putChar("selected_did", currentDeviceItemId);
    DEBUG_PRINTLN("⚠️ selected_index out of bounds. Resetting to 0.");
  }


  nvsEndSafe();
  delay(100);



  // Daily reset check is deferred until set_time is received from the app.
  // Running it here with a potentially-invalid RTC would incorrectly
  // reset todaycount values on every power cycle.

  pinMode(VIBRATION_PIN, OUTPUT);
  digitalWrite(VIBRATION_PIN, LOW);

  setupBLE();

  // Initialize watchdog timer (30 second timeout, panic on timeout)
  esp_task_wdt_init(&wdtConfig);
  esp_task_wdt_add(NULL);  // Add current task (loop task) to watchdog
  DEBUG_PRINTLN("🐕 Watchdog initialized (30s timeout)");

  // Initialize power management
  powerState.lastActivity = millis();
  DEBUG_PRINTLN("⚡ Power management initialized");

  // ============== MULTI-DEVICE: Enter appropriate mode ==============
  if (!isDevicePaired()) {
    // Unpaired device - enter pairing mode
    enterPairingMode();
    displayWelcomeScreen();
  } else {
    // Paired device - normal operation
    enterNormalMode();
  }
}



// Main loop waits for user commands from serial input
void loop() {
  // Reset watchdog timer at start of each loop iteration
  esp_task_wdt_reset();

  // Update non-blocking vibration state
  updateVibration();

  // Process non-blocking BLE transmission (one chunk per iteration)
  processBleTransmit();

  if (millis() - lastResetCheck > 60000) {  // every 60 seconds. Might need to update this for battery life
    resetTodayCountsIfNeeded();
    lastResetCheck = millis();
  }

  // Periodic NVS flush - ensure dirty data is written every 5 minutes
  // Uses subtraction to handle millis() overflow correctly
  static unsigned long lastNvsFlush = 0;
  if (countsDirty && (millis() - lastNvsFlush > 300000)) {  // 5 minutes
    flushPendingNvsWrites();
    lastNvsFlush = millis();
  }

  // Check for stale incoming JSON buffer (incomplete transfer from app)
  if (incomingJsonBuffer.length() > 0 && lastChunkReceived > 0) {
    if (millis() - lastChunkReceived > CHUNK_TIMEOUT_MS) {
      DEBUG_LOG("⚠️ Chunk timeout - clearing stale buffer (%d bytes)\n", incomingJsonBuffer.length());
      incomingJsonBuffer = "";
      lastChunkReceived = 0;
    }
  }

  // Check for stale write command buffer (incomplete multi-packet command)
  if (writeCommandBuffer.length() > 0 && lastChunkReceived > 0) {
    if (millis() - lastChunkReceived > CHUNK_TIMEOUT_MS) {
      DEBUG_LOG("⚠️ Write command timeout - clearing stale buffer (%d bytes)\n", writeCommandBuffer.length());
      writeCommandBuffer = "";
    }
  }

  // After successful handshake (in_sync), send prefs and logs to app
  // This mimics the old prepare_read flow but is triggered automatically
  // Uses two-step approach: prefs first, then logs after prefs completes
  // Wait 100ms after handshake to ensure response is sent before starting prefs
  if (needsSendSyncData && !bleTransmit.inProgress &&
      (millis() - syncDataRequestedAt >= 100)) {
    needsSendSyncData = false;  // Clear flag to prevent re-triggering
    DEBUG_PRINTLN("📤 Sending initial prefs after handshake...");

    // Send prefs first (non-blocking)
    notifyPrefsToApp();

    // Set flag to send logs after prefs transmission completes
    needsSendLogs = true;
  }

  // Send logs after prefs transmission completes
  if (needsSendLogs && !bleTransmit.inProgress) {
    needsSendLogs = false;  // Clear flag to prevent re-triggering
    DEBUG_PRINTLN("📤 Prefs sent, now sending logs...");

    // Send logs (page 0)
    notifyLogsToApp(0);

    DEBUG_PRINTLN("✅ Initial sync data sent");
  }

  // Handle prepare_read requests by sending data via notification
  // (deferred from BLE callback to avoid NVS access issues)
  if (currentReadMode == READ_PREFS) {
    notifyPrefsToApp();  // Send prefs via notification (non-blocking)
    updateReadChar();    // Also update READ char for compatibility
    currentReadMode = READ_NONE;  // Reset after handling
  } else if (currentReadMode == READ_LOGS) {
    notifyLogsToApp(currentPage);  // Send logs via notification (non-blocking)
    updateReadChar();              // Also update READ char for compatibility
    currentReadMode = READ_NONE;  // Reset after handling
  }

  if (Serial.available()) {
    char cmd = Serial.read();
    if (cmd == 'u' || cmd == 'r' || cmd == 's') {
      handleCommand(cmd);
    } else if (cmd == 'f' || cmd == 'F') {
      // Factory reset command - requires confirmation
      handleFactoryReset();
    }
  }

  // Power management: enter low power mode when idle and not connected
  if (!powerState.isLowPower && !isConnected) {
    if (millis() - powerState.lastActivity > IDLE_TIMEOUT_MS) {
      enterLowPowerMode();
    }
  }

  // Adjust loop delay based on power state
  delay(powerState.isLowPower ? 100 : 10);
}
