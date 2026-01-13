/// Test data fixtures for consistent test data across test files.
///
/// This file provides sample data that matches the Firestore schema.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Test user ID
const String testUserId = 'test_user_123';

/// Test user email
const String testUserEmail = 'test@example.com';

/// Test item data matching Firestore schema
const Map<String, dynamic> testItemData = {
  'item_name': 'Test Item',
  'todaycount': 5,
  'increment_by': 1,
  'item_id': 'item_123',
  'max_value': 10,
  'uid': testUserId,
  'created_at': 'timestamp_placeholder', // Will be replaced with Timestamp in tests
};

/// Test event log data matching Firestore schema
const Map<String, dynamic> testEventLogData = {
  'item_id': 'item_123',
  'item_name': 'Test Item',
  'event_time': 'timestamp_placeholder', // Will be replaced with Timestamp in tests
  'increment_value': 1,
  'uid': testUserId,
};

/// Create a Timestamp for testing (current time)
Timestamp getTestTimestamp() {
  return Timestamp.now();
}

/// Create test item data with proper Timestamp
Map<String, dynamic> createTestItemData({
  String? itemName,
  int? todayCount,
  int? incrementBy,
  String? itemId,
  String? uid,
}) {
  return {
    'item_name': itemName ?? testItemData['item_name'],
    'todaycount': todayCount ?? testItemData['todaycount'],
    'increment_by': incrementBy ?? testItemData['increment_by'],
    'item_id': itemId ?? testItemData['item_id'],
    'max_value': testItemData['max_value'],
    'uid': uid ?? testItemData['uid'],
    'created_at': getTestTimestamp(),
  };
}

/// Create test event log data with proper Timestamp
Map<String, dynamic> createTestEventLogData({
  String? itemId,
  String? itemName,
  int? incrementValue,
  String? uid,
}) {
  return {
    'item_id': itemId ?? testEventLogData['item_id'],
    'item_name': itemName ?? testEventLogData['item_name'],
    'event_time': getTestTimestamp(),
    'increment_value': incrementValue ?? testEventLogData['increment_value'],
    'uid': uid ?? testEventLogData['uid'],
  };
}
