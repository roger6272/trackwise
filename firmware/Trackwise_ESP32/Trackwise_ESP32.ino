// ESP32 BLE Counter Firmware – Final Version Matching Spec with Inline Comments

#include <Preferences.h>  // For storing item data persistently
#include <BLEDevice.h>    // Core BLE support
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>      // For BLE notification descriptors
#include <ArduinoJson.h>  // For encoding/decoding JSON
#include <RTClib.h>
#include <esp_gap_ble_api.h>  // For connection parameter logging

// BLE UUID definitions
#define SERVICE_UUID "12345678-1234-1234-1234-123456789000"
#define CHAR_READ_UUID "12345678-1234-1234-1234-123456789001"
#define CHAR_NOTIFY_UUID "12345678-1234-1234-1234-123456789002"     // Reusing CHAR_NOTIFY_UUID for both real-time events and log syncs to reduce BLE characteristics.
#define CHAR_SET_ITEMS_UUID "12345678-1234-1234-1234-123456789008"  //send list of items from the app to device
#define CHAR_WRITE_UUID "12345678-1234-1234-1234-123456789010"      //combine clearlogs, setselected, settime


// RAM-based log buffer setup
#define MAX_LOG_ENTRIES 500
#define maxPrefsSlots 100  // Max item slots supported (increased for inventory use)

#define REMINDER_NONE 0
#define REMINDER_TARGET 1
#define REMINDER_INTERVAL 2

#define VIBRATION_PIN 5

// Event struct to store count logs
struct CountLog {
  String itemId;
  String itemName;
  String event;
  uint32_t timestamp;
  int increment;
  int count;
  int reminder;
  int reminderValue;
  int resetNumber;
};

CountLog logs[MAX_LOG_ENTRIES];  //Create an array named logs that can hold up to MAX_LOG_ENTRIES items, where each item is a CountLog struct. This is the RAM!!!!!!!!!!!!!!!!!!!!!!
int logWriteIndex = 0;           //keep track of which slot in log should a new event be stored in
int logCount = 0;                //number of valid entries in the log

// Current device state for selected item
int currentItemIndex = 0;
String currentItemId = "none";
int itemCount = 0;
int itemTodayCount = 0;
int itemIncrement = 1;
String itemName = "Item";
String itemCategory = "";
unsigned long connectedAt = 0;
bool didInitialSync = false;
bool isConnected = false;
int reminder = REMINDER_NONE;
int reminderValue = 0;
time_t lastResetTime = 0;
int itemResetNumber = 0;  // Track reset count for current item
Preferences prefs;  // Non-volatile storage instance
unsigned long lastResetCheck = 0;
String incomingJsonBuffer = "";
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

// For Non-Blocking Vibration
struct VibrationState {
  unsigned long endTime = 0;
  bool isActive = false;
} vibration;

void triggerVibrationNonBlocking(int duration = 300) {
  digitalWrite(VIBRATION_PIN, HIGH);
  vibration.endTime = millis() + duration;
  vibration.isActive = true;
}

// Check and turn off vibration in loop() - call this every iteration
void updateVibration() {
  if (vibration.isActive && millis() >= vibration.endTime) {
    digitalWrite(VIBRATION_PIN, LOW);
    vibration.isActive = false;
  }
}

// Store a new log event in RAM
// For reset events, pass the OLD resetNumber before incrementing
void logEvent(String event, int resetNum = -1) {
  int logResetNumber = (resetNum >= 0) ? resetNum : itemResetNumber;
  logs[logWriteIndex] = {
    currentItemId, itemName, event, rtc.now().unixtime(), itemIncrement, itemCount, reminder, reminderValue, logResetNumber
  };
  logWriteIndex = (logWriteIndex + 1) % MAX_LOG_ENTRIES;
  if (logCount < MAX_LOG_ENTRIES) logCount++;
}

void notifyPrefsToApp() {
  if (!isConnected || NotifyChar == nullptr) return;
  String jsonOut = getPrefsJson();
  jsonOut += "\n";  // For Flutter end-of-message detection

  // Use larger MTU for faster transfers (app negotiates 512, we use 180 for safety margin)
  const int mtu = 180;
  for (int i = 0; i < jsonOut.length(); i += mtu) {
    String chunk = jsonOut.substring(i, min(i + mtu, (int)jsonOut.length()));
    NotifyChar->setValue(chunk.c_str());
    NotifyChar->notify();
    delay(10);  // Reduced from 30ms - high priority connection can handle this
  }
  Serial.println("✅ Finished sending prefs via notification.");
}

// Send delta update for a single item (much smaller than full prefs)
// Used after increment/reset to update just the changed item
void notifyItemDelta(String itemId, int count, int todayCount, time_t resetTime, int resetNumber) {
  if (!isConnected || NotifyChar == nullptr) return;

  StaticJsonDocument<256> doc;
  doc["type"] = "item_delta";
  doc["id"] = itemId;
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
  Serial.printf("📤 Delta update: %s count=%d today=%d resetNumber=%d\n", itemId.c_str(), count, todayCount, resetNumber);
}

// Send logs to app via notification (chunked for large payloads)
void notifyLogsToApp(int page) {
  if (!isConnected || NotifyChar == nullptr) return;
  String jsonOut = getLogsAsString(page);
  jsonOut += "\n";  // For Flutter end-of-message detection

  Serial.printf("📤 Sending logs page %d (%d bytes, %d chunks)\n", page, jsonOut.length(), (jsonOut.length() + 179) / 180);

  const int mtu = 180;
  for (int i = 0; i < jsonOut.length(); i += mtu) {
    // Check connection before each chunk
    if (!isConnected) {
      Serial.println("⚠️ Connection lost during log transmission");
      return;
    }
    String chunk = jsonOut.substring(i, min(i + mtu, (int)jsonOut.length()));
    NotifyChar->setValue(chunk.c_str());
    NotifyChar->notify();
    delay(20);  // Increased from 10ms for more reliable transmission
  }
  Serial.printf("✅ Finished sending logs page %d via notification.\n", page);
}

// Convert ALL prefs into a JSON string to send to the app
String getPrefsJson() {
  StaticJsonDocument<16384> doc;  // Increased for 100 items

  // Create the outer object
  JsonObject root = doc.to<JsonObject>();
  root["type"] = "prefs";

  // Add the array as a nested field called "data"
  JsonArray arr = root.createNestedArray("data");

  prefs.begin("counter", false);
  int total = prefs.getInt("item_total", 0);
  char key[16];  // Buffer for preference keys
  for (int i = 0; i < total; i++) {
    JsonObject item = arr.createNestedObject();
    snprintf(key, sizeof(key), "id_%d", i);
    item["id"] = prefs.getString(key, "");
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

  //Add selected_id to update the appstate
  String selectedId = prefs.getString("selected_id", "");
  root["selected_id"] = selectedId;
  prefs.end();

  String out;
  serializeJson(root, out);
  return out;
}

// Convert ALL pts into a JSON string to send to the app
String getLogsAsString(int page) {
  StaticJsonDocument<4096> doc;

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
      Serial.println("⚠️ JSON document overflow - truncating logs");
      break;
    }
    JsonObject o = arr.createNestedObject();
    o["timestamp"] = logs[i].timestamp;
    o["itemId"] = logs[i].itemId;
    o["itemName"] = logs[i].itemName;
    o["event"] = logs[i].event;
    o["increment"] = logs[i].increment;
    o["count"] = logs[i].count;
    o["resetNumber"] = logs[i].resetNumber;
  }

  // Check if we overflowed
  if (doc.overflowed()) {
    Serial.printf("⚠️ JSON overflow detected! Doc size: %d, capacity: %d\n", doc.memoryUsage(), doc.capacity());
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
    Serial.println("Received raw chunk:");
    Serial.println(chunk);

    // Update timestamp for chunk timeout detection
    lastChunkReceived = millis();

    incomingJsonBuffer.trim();
    incomingJsonBuffer += chunk;

    // Check if buffer ends with ']' (simple heuristic for end of JSON array)
    if (incomingJsonBuffer.endsWith("]")) {
      StaticJsonDocument<32768> doc;  // Increased for 100 items
      DeserializationError err = deserializeJson(doc, incomingJsonBuffer);
      if (err) {
        Serial.print("JSON parse failed: ");
        Serial.println(err.c_str());
        incomingJsonBuffer = "";  // clear buffer on failure
        return;
      }

      prefs.begin("counter", false);

      // Save existing counts by item ID before deletion (device is source of truth)
      int existingTotal = prefs.getInt("item_total", 0);
      String existingIds[maxPrefsSlots];
      int existingCounts[maxPrefsSlots];
      int existingTodayCounts[maxPrefsSlots];
      char key[16];  // Buffer for preference keys
      for (int i = 0; i < existingTotal && i < maxPrefsSlots; i++) {
        snprintf(key, sizeof(key), "id_%d", i);
        existingIds[i] = prefs.getString(key, "");
        snprintf(key, sizeof(key), "c_%d", i);
        existingCounts[i] = prefs.getInt(key, 0);
        snprintf(key, sizeof(key), "tc_%d", i);
        existingTodayCounts[i] = prefs.getInt(key, 0);
      }

      // Clear all slots
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
        snprintf(key, sizeof(key), "id_%d", i);
        prefs.remove(key);
        snprintf(key, sizeof(key), "r_%d", i);
        prefs.remove(key);
        snprintf(key, sizeof(key), "rv_%d", i);
        prefs.remove(key);
        snprintf(key, sizeof(key), "lr_%d", i);
        prefs.remove(key);
        snprintf(key, sizeof(key), "rn_%d", i);
        prefs.remove(key);
      }

      int index = 0;
      for (JsonObject item : doc.as<JsonArray>()) {
        if (index >= maxPrefsSlots) break;
        String id = item["id"].as<String>();
        String name = item["name"].as<String>();
        String category = item.containsKey("category") ? item["category"].as<String>() : "";
        int increment = item["increment"];
        int reminder = item["reminder"];
        int reminderValue = item["reminder_value"];
        unsigned long lastResetTime = item.containsKey("lastResetTime") ? item["lastResetTime"] : 0;
        int resetNumber = item.containsKey("reset_number") ? item["reset_number"].as<int>() : 0;

        // Find existing counts for this item ID (device is source of truth)
        int count = 0;
        int todaycount = 0;
        for (int i = 0; i < existingTotal && i < maxPrefsSlots; i++) {
          if (existingIds[i] == id) {
            count = existingCounts[i];
            todaycount = existingTodayCounts[i];
            Serial.printf("🔄 Preserving counts for %s: count=%d, todaycount=%d\n", id.c_str(), count, todaycount);
            break;
          }
        }

        // Override with JSON values if provided (for new items with initial values)
        if (item.containsKey("count")) {
          count = item["count"].as<int>();
        }
        if (item.containsKey("todaycount")) {
          todaycount = item["todaycount"].as<int>();
        }

        snprintf(key, sizeof(key), "id_%d", index);
        prefs.putString(key, id);
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
        snprintf(key, sizeof(key), "lr_%d", index);
        prefs.putULong(key, lastResetTime);
        snprintf(key, sizeof(key), "rn_%d", index);
        prefs.putInt(key, resetNumber);

        Serial.printf("[%d] ID=%s Name=%s Category=%s Count=%d TodayCount=%d Incr=%d Reminder=%d ReminderValue=%d ResetTime=%lu ResetNum=%d\n",
              index, id.c_str(), name.c_str(), category.c_str(), count, todaycount, increment, reminder, reminderValue, lastResetTime, resetNumber);
        index++;
      }

      prefs.putInt("item_total", index);

      // Re-lookup selected item index after reordering
      // (items may have moved to different positions)
      if (currentItemId != "none") {
        bool found = false;
        for (int i = 0; i < index; i++) {
          snprintf(key, sizeof(key), "id_%d", i);
          String testId = prefs.getString(key, "");
          if (testId == currentItemId) {
            currentItemIndex = i;
            prefs.putInt("selected_index", i);
            found = true;
            Serial.printf("🔄 Updated selected index to %d for ID %s\n", i, currentItemId.c_str());
            break;
          }
        }
        if (!found) {
          // Item not found - could be timing issue or item was deleted
          if (index > 0) {
            // Items exist but selected not found - DON'T reset to none/first item
            // Keep current selection and let incoming set_selected command fix it
            // This prevents brief "none" state during reorder operations
            Serial.printf("⚠️ Selected item '%s' not found after reorder, keeping current selection (set_selected will fix)\n", currentItemId.c_str());
          } else {
            // No items at all - must reset to none
            currentItemIndex = 0;
            currentItemId = "none";
            prefs.putInt("selected_index", 0);
            prefs.putString("selected_id", "none");
            Serial.println("⚠️ No items left, selected = none");
          }
        }
      }

      // Refresh runtime variables for currently selected item
      // This ensures updated incrementBy, reminder, etc. take effect immediately
      if (currentItemId != "none" && currentItemIndex < index) {
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
        Serial.printf("🔄 Refreshed runtime vars: %s, category=%s, increment=%d, reminder=%d, resetNumber=%d\n",
                      itemName.c_str(), itemCategory.c_str(), itemIncrement, reminder, itemResetNumber);
      }

      prefs.end();

      clearLogs();
      incomingJsonBuffer = "";
      Serial.println("✅ Finished writing to prefs with index-based keys.");
    }
  }
};



class WriteCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    String jsonStr = String(c->getValue().c_str());
    jsonStr.trim();  // ⚠️ Trim whitespace and line breaks
    Serial.print("📨 Received JSON string: '");
    Serial.print(jsonStr);
    Serial.println("'");

    StaticJsonDocument<256> doc;
    DeserializationError err = deserializeJson(doc, jsonStr);
    if (err) {
      Serial.print("❌ Command JSON parse error: ");
      Serial.println(err.c_str());
      return;
    }

    String cmd = doc["cmd"] | "";
    cmd.trim();

    if (cmd == "clear_logs") {  //////////////////// clear all event logs
      clearLogs();
      Serial.println("✅ Logs cleared.");

    } else if (cmd == "set_selected") {  ///////////////////////// set selected item
      String id = doc["id"] | "";
      id.trim();  // ⚠️ Important to match stored prefs key

      prefs.begin("counter", false);

      int total = prefs.getInt("item_total", 0);
      if (total == 0 || id == "none") {
        Serial.println("⚠️ No items available to select.");
        currentItemId = "none";
        prefs.putString("selected_id", "none");
        prefs.putInt("selected_index", 0);
        prefs.end();
        return;
      }

      bool found = false;
      char key[16];  // Buffer for preference keys
      for (int i = 0; i < total; i++) {
        snprintf(key, sizeof(key), "id_%d", i);
        String testId = prefs.getString(key, "");  //loop through all index with each id compared with the target id
        if (testId == id) {
          currentItemId = id;
          currentItemIndex = i;
          prefs.putString("selected_id", id);
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

          Serial.printf("✅ Selected item [%d]: %s (%s) category=%s resetNumber=%d\n", i, id.c_str(), itemName.c_str(), itemCategory.c_str(), itemResetNumber);
          found = true;
          break;
        }
      }

      if (!found) {
        Serial.println("Selected ItemId unchanged:");
        for (int i = 0; i < total; i++) {
          snprintf(key, sizeof(key), "id_%d", i);
          Serial.println(prefs.getString(key, ""));
        }
      }
      prefs.end();

    } else if (cmd == "set_time") {
      String utc_time = doc["utc_time"] | "";
      utc_time.trim();
      int offsetMin = doc["offset"];       // timezone offset in minutes

      Serial.print("📥 Received utc_time: '");
      Serial.print(utc_time);
      Serial.print("', offset: ");
      Serial.println(offsetMin);

      struct tm tm;
      memset(&tm, 0, sizeof(tm));  // Clear struct to avoid garbage values
      if (strptime(utc_time.c_str(), "%Y-%m-%d %H:%M:%S", &tm)) {
        Serial.printf("📅 Parsed: year=%d mon=%d day=%d hour=%d min=%d sec=%d\n",
                      tm.tm_year, tm.tm_mon, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec);

        // Construct DateTime directly from parsed components
        // This avoids mktime() which has timezone interpretation issues on ESP32
        DateTime utcDt(tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
                       tm.tm_hour, tm.tm_min, tm.tm_sec);
        time_t parsedTime = utcDt.unixtime();

        Serial.print("⏱️ UTC unix timestamp: ");
        Serial.println(parsedTime);

        if (parsedTime > 1000000000) {              // Rough sanity check (post-2001)
          rtc.adjust(utcDt);                        // ✅ Set the RTC to UTC time

          prefs.begin("counter", false);
          // ✅ Store timezone offset in Preferences
          prefs.putInt("timezone_offset", offsetMin);
          prefs.end();

          localTimestamp = parsedTime + offsetMin * 60;
          localTime = DateTime(localTimestamp);  // ✅ Assign to global

          Serial.print("🕒 UTC time set = ");
          Serial.println(utcDt.timestamp());
          Serial.print("🕒 Local time = ");
          Serial.println(localTime.timestamp());
          Serial.print("✅ RTC now reads: ");
          Serial.println(rtc.now().timestamp());
        } else {
          Serial.print("⚠️ Parsed time was too early (");
          Serial.print(parsedTime);
          Serial.println(") — ignoring.");
        }
      } else {
        Serial.println("❌ Failed to parse set_time value.");
      }


    } else if (cmd == "prepare_read") {
      String type = doc["type"] | "";
      currentPage = doc["page"] | 0;  // ← Parse page, default to 0

      if (type == "prefs") {
        currentReadMode = READ_PREFS;
      } else if (type == "logs") {
        currentReadMode = READ_LOGS;
      }
    }

    else if (cmd == "force_reset_today") {
      // Debug command to force reset all todaycounts regardless of date
      Serial.println("🔧 DEBUG: Force resetting all todayCounts...");

      updateLocalTime();

      // Use UTC timestamp for lastResetTime (consistent with event timestamps)
      time_t utcTimestamp = rtc.now().unixtime();

      prefs.begin("counter", false);
      int total = prefs.getInt("item_total", 0);

      char key[16];  // Buffer for preference keys
      for (int i = 0; i < total; i++) {
        // Reset todaycount to 0
        snprintf(key, sizeof(key), "tc_%d", i);
        prefs.putInt(key, 0);

        // Update lastResetTime to UTC timestamp (not localTimestamp which has offset applied)
        snprintf(key, sizeof(key), "lr_%d", i);
        prefs.putULong(key, utcTimestamp);

        Serial.printf("Force reset: %s = 0, lastResetTime = %lu (UTC)\n", key, utcTimestamp);
      }

      // Update last_reset_date to today
      char todayStr[11];
      snprintf(todayStr, sizeof(todayStr), "%04d-%02d-%02d", localTime.year(), localTime.month(), localTime.day());
      prefs.putString("last_reset_date", todayStr);

      // Reset runtime variable if item is selected
      if (currentItemId != "none") {
        itemTodayCount = 0;
        lastResetTime = utcTimestamp;
      }

      prefs.end();
      Serial.println("✅ Force reset complete.");
    }

    else {
      Serial.print("❓ Unknown command: ");
      Serial.println(cmd);
    }
  }
};


// Track BLE connection state
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* p) override {
    isConnected = true;
    Serial.println("✅ Connected!");
  }
  void onDisconnect(BLEServer* p) override {
    isConnected = false;
    Serial.println("🔌 Client disconnected — restarting advertising...");
    BLEDevice::startAdvertising();
  }
};

// GAP event callback to log connection parameter changes
static void onGapEvent(esp_gap_ble_cb_event_t event, esp_ble_gap_cb_param_t *param) {
  if (event == ESP_GAP_BLE_UPDATE_CONN_PARAMS_EVT) {
    // conn_int is the actual negotiated connection interval (in 1.25ms units)
    float interval = param->update_conn_params.conn_int * 1.25;

    Serial.println("📊 Connection parameters updated:");
    Serial.printf("   - Actual interval: %.2fms\n", interval);
    Serial.printf("   - Latency: %d\n", param->update_conn_params.latency);
    Serial.printf("   - Timeout: %dms\n", param->update_conn_params.timeout * 10);
    Serial.printf("   - Status: %s\n",
                  param->update_conn_params.status == ESP_BT_STATUS_SUCCESS ? "SUCCESS" : "FAILED");

    // Log interpretation
    if (interval <= 15) {
      Serial.println("   ✅ HIGH priority (~7.5ms interval)");
    } else if (interval <= 50) {
      Serial.println("   ⚡ BALANCED priority (~30ms interval)");
    } else {
      Serial.println("   🔋 LOW priority (>50ms interval)");
    }
  }
}

// BLE peripheral and characteristic setup
void setupBLE() {
  BLEDevice::init("TallyCounter");

  // Set maximum MTU to allow larger packets (default is 23, max is 517)
  // This allows the app to negotiate larger MTU for faster transfers
  BLEDevice::setMTU(517);
  Serial.println("📦 BLE MTU set to 517 bytes (max)");

  // Register GAP callback to log connection parameter changes
  esp_ble_gap_register_callback(onGapEvent);
  Serial.println("📡 BLE GAP callback registered for connection parameter logging");

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
    jsonOut = getPrefsJson();
    //Serial.println("PrefsSent - Details skipped");
    Serial.printf("PrefsSent (%u bytes)\n", jsonOut.length());
    Serial.println(jsonOut);
  } else if (currentReadMode == READ_LOGS) {
    jsonOut = getLogsAsString(currentPage);  // Convert all logs into one array
    //Serial.println("LogsSent - Details skipped");
    //Serial.println(jsonOut);  //////////////////////////////////////////////////Sent logs
    Serial.printf("LogsSent page %u (%u bytes)\n", currentPage, jsonOut.length());
    Serial.println(jsonOut);   // <- print full JSON here
  } else {
    return;
  }

  readChar->setValue(jsonOut.c_str());
 //   if (currentReadMode == READ_LOGS) {
 //   clearLogs();                        // ✅ ...before clearing RAM
 // }
  currentReadMode = READ_NONE;  // Reset after preparing
}



// Send event to app via notification. This will be called everytime a button is pressed
// For reset events, pass the OLD resetNumber before incrementing
void notifyEvent(String event, int resetNum = -1) {
  if (!isConnected || NotifyChar == nullptr) return;

  int eventResetNumber = (resetNum >= 0) ? resetNum : itemResetNumber;

  StaticJsonDocument<512> doc;

  // Create the standard JSON structure
  JsonObject root = doc.to<JsonObject>();
  root["type"] = "event";

  // Create the data object with event details
  JsonObject data = root.createNestedObject("data");
  data["timestamp"] = rtc.now().unixtime();
  data["itemId"] = currentItemId;
  data["itemName"] = itemName;
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
    delay(10);  // Reduced from 30ms - high priority connection can handle this
  }
  //Serial.println("📤 Sent notifyEvent:");
  //Serial.println(s);
}

/*
void syncAllLogsToApp() {
  if (!isConnected || NotifyChar == nullptr) return;

  StaticJsonDocument<512> doc;

  for (int i = 0; i < logCount; i++) {
    doc.clear();
    doc["type"] = "log";
    doc["timestamp"] = logs[i].timestamp;
    doc["itemID"] = logs[i].itemId;
    doc["itemName"] = logs[i].itemName;
    doc["event"] = logs[i].event;
    doc["increment"] = logs[i].increment;
    doc["count"] = logs[i].count;

    String jsonOut;
    serializeJson(doc, jsonOut);
    jsonOut += "\n";  // 🧩 flutter side uses newline as delimiter

    const int mtu = 20;  // max payload for default MTU (23)
    for (int j = 0; j < jsonOut.length(); j += mtu) {
      String chunk = jsonOut.substring(j, j + mtu);
      NotifyChar->setValue(chunk.c_str());
      NotifyChar->notify();
      delay(30);  // avoid BLE flooding
    }
  }

  Serial.println("✅ Sent all offline logs to app.");
  clearLogs();  // Optional: clear after sync
}
*/

// Handle local commands: 'u' (up), 'r' (reset), 's' (switch item)
void handleCommand(char cmd) {
  prefs.begin("counter", false);

  int total = prefs.getInt("item_total", 0);
  char key[16];  // Buffer for preference keys
  if (cmd == 'u') {
    // Increment current item count and update in prefs using indexed keys
    if (currentItemId == "none") {
      Serial.println("No Item Selected");
      return;
    }
    //update first
    itemCount += itemIncrement;
    itemTodayCount += itemIncrement;

    //extract from prefs
    snprintf(key, sizeof(key), "r_%d", currentItemIndex);
    reminder = prefs.getInt(key, REMINDER_NONE);
    snprintf(key, sizeof(key), "rv_%d", currentItemIndex);
    reminderValue = prefs.getInt(key, 0);

    if (reminder == REMINDER_TARGET && itemCount == reminderValue) {
      triggerVibrationNonBlocking();
      // trigger vibration here
    } else if (reminder == REMINDER_INTERVAL && reminderValue > 0 && itemCount > 0 && itemCount % reminderValue == 0){
      triggerVibrationNonBlocking();
      // trigger vibration here
    }

    snprintf(key, sizeof(key), "c_%d", currentItemIndex);
    prefs.putInt(key, itemCount);
    snprintf(key, sizeof(key), "tc_%d", currentItemIndex);
    prefs.putInt(key, itemTodayCount);

    logEvent("increment");
    // Send delta update instead of full prefs (much smaller payload)
    if (isConnected) notifyItemDelta(currentItemId, itemCount, itemTodayCount, lastResetTime, itemResetNumber);
    delay(50);  // Brief gap between notifications
    if (isConnected) notifyEvent("increment");

  } else if (cmd == 'r') {
    // Reset current item count and update in prefs using indexed keys
    if (currentItemId == "none") {
      Serial.print("No Item Selected");
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

    lastResetTime = rtc.now().unixtime();
    snprintf(key, sizeof(key), "lr_%d", currentItemIndex);
    prefs.putULong(key, lastResetTime);

    // Log the reset event with OLD resetNumber (this reset ends period N)
    logEvent("reset", oldResetNumber);

    // Now increment resetNumber for the new period
    itemResetNumber++;
    snprintf(key, sizeof(key), "rn_%d", currentItemIndex);
    prefs.putInt(key, itemResetNumber);

    Serial.printf("🔄 Reset: period %d ended, now in period %d\n", oldResetNumber, itemResetNumber);

    prefs.end();  // Close prefs BEFORE notifying to avoid nested prefs.begin() issues

    // Send delta update with NEW resetNumber (app needs current state)
    if (isConnected) notifyItemDelta(currentItemId, itemCount, itemTodayCount, lastResetTime, itemResetNumber);
    delay(50);  // Brief gap between notifications
    // Send event notification with OLD resetNumber (the reset that ended period N)
    if (isConnected) notifyEvent("reset", oldResetNumber);
    return;  // Already closed prefs, skip the final prefs.end()

  } else if (cmd == 's') {
    if (total == 0) {
      prefs.end();
      return;
    }

    // Cycle to the next item index
    currentItemIndex = (currentItemIndex + 1) % total;
    snprintf(key, sizeof(key), "id_%d", currentItemIndex);
    currentItemId = prefs.getString(key, "none");

    // Update state with new selection
    prefs.putString("selected_id", currentItemId);
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

    currentItemId = prefs.getString("selected_id", "none");
    prefs.end();  // Close prefs BEFORE notifying to avoid nested prefs.begin() issues

    //logEvent("switch");
    if (isConnected) notifyEvent("switch");

    Serial.printf("Switch to: %s (index %d)\n", itemName.c_str(), currentItemIndex);
    return;  // Already closed prefs, skip the final prefs.end()
  }

  prefs.end();


  //DateTime now = rtc.now();
  // 📢 Display current item status after any command
  //  Serial.print("Time: ");
  //Serial.print(now.month(), DEC);
  //Serial.print('/');
  //Serial.print(now.day(), DEC);
  //Serial.print(" ");
 // Serial.print(now.hour(), DEC);
 // Serial.print(" ");
  Serial.print(itemName);
  if (itemCategory.length() > 0) {
    Serial.print(" (");
    Serial.print(itemCategory);
    Serial.print(")");
  }
  Serial.print(" [ID: ");
  Serial.print(currentItemId);
  Serial.print("] Count: ");
  Serial.print(itemCount);
  Serial.print(", TodayCount: ");
  Serial.print(itemTodayCount);
  Serial.print(" (+");
  Serial.print(itemIncrement);
  Serial.println(")");

}

void updateLocalTime() {
  DateTime nowUtc = rtc.now();

  prefs.begin("counter", false);
  int offsetMin = prefs.getInt("timezone_offset", 0);
  prefs.end();

  localTimestamp = nowUtc.unixtime() + offsetMin * 60;
  localTime = DateTime(localTimestamp);
}


void resetTodayCountsIfNeeded(){//bool forceReset = false) {

  updateLocalTime();

  char todayStr[11]; // "YYYY-MM-DD" + null
  snprintf(todayStr, sizeof(todayStr), "%04d-%02d-%02d", localTime.year(), localTime.month(), localTime.day());

  prefs.begin("counter", false);
  String last_reset_date = prefs.getString("last_reset_date", "");

  if (last_reset_date != String(todayStr)) {
    Serial.println("🔄 New day detected. Resetting todayCount for all items.");
    Serial.println(String(todayStr));

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

      Serial.printf("Reset: %s, lastResetTime: %lu (UTC)\n", key, utcTimestamp);
    }

    if (currentItemId != "none") {
      itemTodayCount = 0;  // Also reset runtime variable
      lastResetTime = utcTimestamp;
    }

    prefs.putString("last_reset_date", todayStr);
  }// else {
   // Serial.println("✅ todayCount is already up to date.");
   // Serial.println(todayStr);
  //}

  prefs.end();
}




// Device boot initialization
void setup() {
  Serial.begin(115200);
  if (!rtc.begin()) {
    Serial.println("❌ RTC not found!");
  } else {
    Serial.println("✅ RTC connected.");
  }
  if (rtc.lostPower()) {
    Serial.println("⚠️ RTC lost power. Setting to compile time.");
    rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
  }

  prefs.begin("counter", false);
  // ✅ Verify and store item_total
  int verifiedTotal = 0;
  char key[16];  // Buffer for preference keys
  for (int i = 0; i < maxPrefsSlots; i++) {
    snprintf(key, sizeof(key), "id_%d", i);
    String id = prefs.getString(key, "");
    if (id.length() > 0) {
      verifiedTotal++;
    } else {
      break;
    }
  }
  prefs.putInt("item_total", verifiedTotal);
  Serial.printf("✅ Verified item_total on boot: %d\n", verifiedTotal);


  currentItemId = prefs.getString("selected_id", "none");
  Serial.print("CurrentItemid:");
  Serial.print(currentItemId);
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
    currentItemId = prefs.getString("id_0", "none");
    prefs.putString("selected_id", currentItemId);
    Serial.println("⚠️ selected_index out of bounds. Resetting to 0.");
  }


  prefs.end();
  delay(100);



  resetTodayCountsIfNeeded();
  delay(100);

  pinMode(VIBRATION_PIN, OUTPUT);
  digitalWrite(VIBRATION_PIN, LOW);

  setupBLE();
}



// Main loop waits for user commands from serial input
void loop() {

  // Update non-blocking vibration state
  updateVibration();

    if (millis() - lastResetCheck > 60000) {  // every 60 seconds. Might need to update this for battery life
      resetTodayCountsIfNeeded();
      lastResetCheck = millis();
    }

  // Check for stale incoming JSON buffer (incomplete transfer from app)
  if (incomingJsonBuffer.length() > 0 && lastChunkReceived > 0) {
    if (millis() - lastChunkReceived > CHUNK_TIMEOUT_MS) {
      Serial.printf("⚠️ Chunk timeout - clearing stale buffer (%d bytes)\n", incomingJsonBuffer.length());
      incomingJsonBuffer = "";
      lastChunkReceived = 0;
    }
  }

  // Handle prepare_read requests by sending data via notification
  // (deferred from BLE callback to avoid NVS access issues)
  if (currentReadMode == READ_PREFS) {
    notifyPrefsToApp();  // Send prefs via notification (chunked)
    updateReadChar();    // Also update READ char for compatibility
    currentReadMode = READ_NONE;  // Reset after handling
  } else if (currentReadMode == READ_LOGS) {
    notifyLogsToApp(currentPage);  // Send logs via notification (chunked)
    updateReadChar();              // Also update READ char for compatibility
    currentReadMode = READ_NONE;  // Reset after handling
  }

  if (Serial.available()) {
    char cmd = Serial.read();
    if (cmd == 'u' || cmd == 'r' || cmd == 's') {
      handleCommand(cmd);
    }
  }
  delay(10);
}
