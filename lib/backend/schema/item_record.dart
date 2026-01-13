import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ItemRecord extends FirestoreRecord {
  ItemRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "item_name" field.
  String? _itemName;
  String get itemName => _itemName ?? '';
  bool hasItemName() => _itemName != null;

  // "count" field.
  int? _count;
  int get count => _count ?? 0;
  bool hasCount() => _count != null;

  // "create_time" field.
  DateTime? _createTime;
  DateTime? get createTime => _createTime;
  bool hasCreateTime() => _createTime != null;

  // "uid" field.
  DocumentReference? _uid;
  DocumentReference? get uid => _uid;
  bool hasUid() => _uid != null;

  // "increment_by" field.
  int? _incrementBy;
  int get incrementBy => _incrementBy ?? 0;
  bool hasIncrementBy() => _incrementBy != null;

  // "reminder" field.
  String? _reminder;
  String get reminder => _reminder ?? '';
  bool hasReminder() => _reminder != null;

  // "todaycount" field.
  int? _todaycount;
  int get todaycount => _todaycount ?? 0;
  bool hasTodaycount() => _todaycount != null;

  // "lastUpdated" field.
  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;
  bool hasLastUpdated() => _lastUpdated != null;

  // "reminder_value" field.
  int? _reminderValue;
  int get reminderValue => _reminderValue ?? 0;
  bool hasReminderValue() => _reminderValue != null;

  // "lastResetTime" field.
  DateTime? _lastResetTime;
  DateTime? get lastResetTime => _lastResetTime;
  bool hasLastResetTime() => _lastResetTime != null;

  void _initializeFields() {
    _itemName = snapshotData['item_name'] as String?;
    _count = castToType<int>(snapshotData['count']);
    _createTime = snapshotData['create_time'] as DateTime?;
    _uid = snapshotData['uid'] as DocumentReference?;
    _incrementBy = castToType<int>(snapshotData['increment_by']);
    _reminder = snapshotData['reminder'] as String?;
    _todaycount = castToType<int>(snapshotData['todaycount']);
    _lastUpdated = snapshotData['lastUpdated'] as DateTime?;
    _reminderValue = castToType<int>(snapshotData['reminder_value']);
    _lastResetTime = snapshotData['lastResetTime'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('Item');

  static Stream<ItemRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ItemRecord.fromSnapshot(s));

  static Future<ItemRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ItemRecord.fromSnapshot(s));

  static ItemRecord fromSnapshot(DocumentSnapshot snapshot) => ItemRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ItemRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ItemRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ItemRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ItemRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createItemRecordData({
  String? itemName,
  int? count,
  DateTime? createTime,
  DocumentReference? uid,
  int? incrementBy,
  String? reminder,
  int? todaycount,
  DateTime? lastUpdated,
  int? reminderValue,
  DateTime? lastResetTime,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'item_name': itemName,
      'count': count,
      'create_time': createTime,
      'uid': uid,
      'increment_by': incrementBy,
      'reminder': reminder,
      'todaycount': todaycount,
      'lastUpdated': lastUpdated,
      'reminder_value': reminderValue,
      'lastResetTime': lastResetTime,
    }.withoutNulls,
  );

  return firestoreData;
}

class ItemRecordDocumentEquality implements Equality<ItemRecord> {
  const ItemRecordDocumentEquality();

  @override
  bool equals(ItemRecord? e1, ItemRecord? e2) {
    return e1?.itemName == e2?.itemName &&
        e1?.count == e2?.count &&
        e1?.createTime == e2?.createTime &&
        e1?.uid == e2?.uid &&
        e1?.incrementBy == e2?.incrementBy &&
        e1?.reminder == e2?.reminder &&
        e1?.todaycount == e2?.todaycount &&
        e1?.lastUpdated == e2?.lastUpdated &&
        e1?.reminderValue == e2?.reminderValue &&
        e1?.lastResetTime == e2?.lastResetTime;
  }

  @override
  int hash(ItemRecord? e) => const ListEquality().hash([
        e?.itemName,
        e?.count,
        e?.createTime,
        e?.uid,
        e?.incrementBy,
        e?.reminder,
        e?.todaycount,
        e?.lastUpdated,
        e?.reminderValue,
        e?.lastResetTime
      ]);

  @override
  bool isValidKey(Object? o) => o is ItemRecord;
}
