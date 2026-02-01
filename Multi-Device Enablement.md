# Multi-Device Enablement

To implement the multi-device support for Traxogic, the following guide outlines the logic for device firmware and mobile app synchronization. This ensures data integrity when managing multiple physical counters with a single account.

### **1\. Device Firmware Implementation**

The device must handle local state, pairing security, and visual feedback for synchronization conflicts.

* **Pairing & Security:**  
  * **App ID Storage:** The device must store a unique `App_Instance_ID` in non-volatile memory upon the first successful pair.  
  * **Single-App Lock:** If a device with a stored `App_Instance_ID` is turned on, it should only accept connection requests from that specific ID.  
* **Factory Reset Protocol:**  
  * **Trigger:** For the current firmware, press F. (when the device is ready later, long-press B button for 10 seconds)  
  * **UI Flow:** Display `WARNING: Factory Reset? A to confirm`  Press u to confirm, r to cancel (when the device is ready later, press button A to confirm)  
  * **Action:** Wipe all local counts, clear the stored `App_Instance_ID`, and clear the Bluetooth bonding table.  
  * **Post-Reset:** Automatically enter `Pairing Mode` with a "Welcome" splash screen whenever it’s turned on. (it will still go into sleep after 5 mins of inactivity)  
* **Conflict UI:**  
  * If the device connects to an app but fails the "Last Sync Check," (The app’s last synced device id should be the same) it should display `SEE APP` and disable incrementing/decrementing until the conflict is resolved in the app.

### **2\. App Implementation (Device Management)**

The app acts as the primary controller and "Source of Truth" for all paired hardware.

* **Device Registry:**  
  * Maintain a `Paired_Devices` list. Each entry includes: `Device_ID`, `Device_Name` (Could be updated by user after connected), and `Last_Sync_Timestamp`.  
* **Connection Logic:**  
  * Allow multiple devices to be paired, but only allow **one** active BLE (Bluetooth Low Energy) session at a time.  
  * The user guide in the app should state that if a user attempts to connect to Device B while Device A is connected, Device A needs to be disconnected first.

### **3\. Synchronization & Conflict Resolution Logic**

This "Handshake" occurs every time a connection is established to prevent data overwriting.

**The Handshake Process:**

1. **Identity Check:** App retrieves `Device_ID` and `Last_App_ID_Synced` from the hardware.  
2. **State Comparison:** The app compares the device's current state with the last known state stored in the cloud/local database.  
3. **Conflict Detection:**  
   * **Scenario A (Match):** If the last synced `Device_ID` is the same device, trigger **Normal Sync** (The logic we have today. Device pass the data to the app, app updates its own records)  
   * **Scenario B (Mismatch):** If the app detects that the "Last Synced Device" was a *different* physical device, trigger the **Conflict Protocol**.

**Conflict Protocol UI:**

* **App Alert:** "Sync Conflict: Device data is being updated to match your app. Confirm  
* **Resolution Options:**  
  * **Override Device:** Push App Data to Device. (App overwrites the physical counter's memory with a pref & selected id push ).

### **4\. Data Schema Update**

To support this, the data model should be updated to include:

* `device_id`: Unique hardware identifier.  
* `app_instance_id`: Unique identifier for the user's app installation.  
* `sync_sequence_no`: An incrementing integer updated on both the app and device after every successful sync to ensure they are on the same "version" of the data.

