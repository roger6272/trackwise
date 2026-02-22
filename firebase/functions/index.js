const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
  let firestore = admin.firestore();
  let userRef = firestore.doc("users/" + user.uid);
  await firestore.collection("users").doc(user.uid).delete();
});

/**
 * Scheduled function to permanently delete soft-deleted items after 30 days.
 * Runs daily at 2:00 AM UTC.
 *
 * Deletes:
 * 1. Items where deletedAt is older than 30 days
 * 2. All EventLogs associated with those items
 */
exports.cleanupSoftDeletedItems = functions.pubsub
  .schedule("0 2 * * *") // Run daily at 2:00 AM UTC
  .timeZone("UTC")
  .onRun(async (context) => {
    const firestore = admin.firestore();
    const now = Date.now();
    const thirtyDaysAgo = now - (30 * 24 * 60 * 60 * 1000); // 30 days in milliseconds

    console.log(`Starting cleanup of items soft-deleted before ${new Date(thirtyDaysAgo).toISOString()}`);

    try {
      // Query items where deletedAt exists and is older than 30 days
      const itemsSnapshot = await firestore
        .collection("Item")
        .where("deletedAt", "<", thirtyDaysAgo)
        .get();

      if (itemsSnapshot.empty) {
        console.log("No items to clean up");
        return null;
      }

      console.log(`Found ${itemsSnapshot.size} items to permanently delete`);

      let totalEventsDeleted = 0;
      let totalItemsDeleted = 0;

      // Process each item
      for (const itemDoc of itemsSnapshot.docs) {
        const itemId = itemDoc.id;
        const itemRef = firestore.collection("Item").doc(itemId);

        // Delete associated EventLogs
        const eventLogsSnapshot = await firestore
          .collection("EventLog")
          .where("item", "==", itemRef)
          .get();

        // Use batched writes for efficiency (max 500 operations per batch)
        const batches = [];
        let currentBatch = firestore.batch();
        let operationCount = 0;

        // Add EventLog deletions to batch
        for (const eventDoc of eventLogsSnapshot.docs) {
          currentBatch.delete(eventDoc.ref);
          operationCount++;
          totalEventsDeleted++;

          if (operationCount >= 499) {
            batches.push(currentBatch);
            currentBatch = firestore.batch();
            operationCount = 0;
          }
        }

        // Add Item deletion to batch
        currentBatch.delete(itemRef);
        operationCount++;
        totalItemsDeleted++;

        if (operationCount > 0) {
          batches.push(currentBatch);
        }

        // Commit all batches
        for (const batch of batches) {
          await batch.commit();
        }

        console.log(`Deleted item ${itemId} and ${eventLogsSnapshot.size} EventLogs`);
      }

      console.log(`Cleanup complete: ${totalItemsDeleted} items and ${totalEventsDeleted} EventLogs permanently deleted`);
      return null;
    } catch (error) {
      console.error("Error during cleanup:", error);
      throw error;
    }
  });
