import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class EventLogRecord extends FirestoreRecord {
  EventLogRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "created_time" field.
  DateTime? _createdTime;
  DateTime? get createdTime => _createdTime;
  bool hasCreatedTime() => _createdTime != null;

  // "event_name" field.
  String? _eventName;
  String get eventName => _eventName ?? '';
  bool hasEventName() => _eventName != null;

  // "item" field.
  DocumentReference? _item;
  DocumentReference? get item => _item;
  bool hasItem() => _item != null;

  // "increment" field.
  int? _increment;
  int get increment => _increment ?? 0;
  bool hasIncrement() => _increment != null;

  // "currentcount" field.
  int? _currentcount;
  int get currentcount => _currentcount ?? 0;
  bool hasCurrentcount() => _currentcount != null;

  // "uid" field.
  DocumentReference? _uid;
  DocumentReference? get uid => _uid;
  bool hasUid() => _uid != null;

  void _initializeFields() {
    _createdTime = snapshotData['created_time'] as DateTime?;
    _eventName = snapshotData['event_name'] as String?;
    _item = snapshotData['item'] as DocumentReference?;
    _increment = castToType<int>(snapshotData['increment']);
    _currentcount = castToType<int>(snapshotData['currentcount']);
    _uid = snapshotData['uid'] as DocumentReference?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('EventLog');

  static Stream<EventLogRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => EventLogRecord.fromSnapshot(s));

  static Future<EventLogRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => EventLogRecord.fromSnapshot(s));

  static EventLogRecord fromSnapshot(DocumentSnapshot snapshot) =>
      EventLogRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static EventLogRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      EventLogRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'EventLogRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is EventLogRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createEventLogRecordData({
  DateTime? createdTime,
  String? eventName,
  DocumentReference? item,
  int? increment,
  int? currentcount,
  DocumentReference? uid,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'created_time': createdTime,
      'event_name': eventName,
      'item': item,
      'increment': increment,
      'currentcount': currentcount,
      'uid': uid,
    }.withoutNulls,
  );

  return firestoreData;
}

class EventLogRecordDocumentEquality implements Equality<EventLogRecord> {
  const EventLogRecordDocumentEquality();

  @override
  bool equals(EventLogRecord? e1, EventLogRecord? e2) {
    return e1?.createdTime == e2?.createdTime &&
        e1?.eventName == e2?.eventName &&
        e1?.item == e2?.item &&
        e1?.increment == e2?.increment &&
        e1?.currentcount == e2?.currentcount &&
        e1?.uid == e2?.uid;
  }

  @override
  int hash(EventLogRecord? e) => const ListEquality().hash([
        e?.createdTime,
        e?.eventName,
        e?.item,
        e?.increment,
        e?.currentcount,
        e?.uid
      ]);

  @override
  bool isValidKey(Object? o) => o is EventLogRecord;
}
