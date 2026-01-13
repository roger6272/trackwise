import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/core/error/exceptions.dart';
import 'package:trackwise/features/items/data/datasources/item_remote_datasource_impl.dart';
import 'package:trackwise/features/items/data/models/item_model.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late ItemRemoteDataSourceImpl dataSource;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference<Map<String, dynamic>> mockCollection;
  late MockQuery<Map<String, dynamic>> mockQuery;
  late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;
  late MockDocumentSnapshot<Map<String, dynamic>> mockDocSnapshot;
  late MockWriteBatch mockBatch;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference<Map<String, dynamic>>();
    mockQuery = MockQuery<Map<String, dynamic>>();
    mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
    mockDocRef = MockDocumentReference<Map<String, dynamic>>();
    mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
    mockBatch = MockWriteBatch();

    dataSource = ItemRemoteDataSourceImpl(mockFirestore);
  });

  group('getItems', () {
    const userId = 'user_123';

    test('should return list of ItemModels on success', () async {
      // Arrange
      when(() => mockFirestore.collection('Item')).thenReturn(mockCollection);
      when(() => mockCollection.where('user_id', isEqualTo: userId))
          .thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

      final mockDocSnap = MockQueryDocumentSnapshot<Map<String, dynamic>>();
      when(() => mockDocSnap.id).thenReturn('test_item_1');
      when(() => mockDocSnap.data()).thenReturn({
        'item_name': 'Coffee',
        'count': 10,
        'todaycount': 5,
        'increment_by': 1,
        'reminder': 'TARGET',
        'reminder_value': 20,
        'lastResetTime': testDateTime.millisecondsSinceEpoch,
        'lastUpdated': testDateTime.millisecondsSinceEpoch,
        'user_id': 'user_123',
      });

      when(() => mockQuerySnapshot.docs).thenReturn([mockDocSnap]);

      // Act
      final result = await dataSource.getItems(userId);

      // Assert
      expect(result, isA<List<ItemModel>>());
      expect(result.length, 1);
      expect(result[0].name, 'Coffee');
      expect(result[0].count, 10);
    });

    test('should throw ServerException when Firestore fails', () async {
      // Arrange
      when(() => mockFirestore.collection('Item'))
          .thenThrow(Exception('Firestore error'));

      // Act & Assert
      expect(
        () => dataSource.getItems(userId),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('getItem', () {
    const itemId = 'test_item_1';

    test('should return ItemModel when document exists', () async {
      // Arrange
      when(() => mockFirestore.collection('Item')).thenReturn(mockCollection);
      when(() => mockCollection.doc(itemId)).thenReturn(mockDocRef);
      when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(true);
      when(() => mockDocSnapshot.id).thenReturn(itemId);
      when(() => mockDocSnapshot.data()).thenReturn({
        'item_name': 'Coffee',
        'count': 10,
        'todaycount': 5,
        'increment_by': 1,
        'reminder': 'TARGET',
        'reminder_value': 20,
        'lastResetTime': testDateTime.millisecondsSinceEpoch,
        'lastUpdated': testDateTime.millisecondsSinceEpoch,
        'user_id': 'user_123',
      });

      // Act
      final result = await dataSource.getItem(itemId);

      // Assert
      expect(result, isA<ItemModel>());
      expect(result.id, itemId);
      expect(result.name, 'Coffee');
    });

    test('should throw ServerException when document does not exist', () async {
      // Arrange
      when(() => mockFirestore.collection('Item')).thenReturn(mockCollection);
      when(() => mockCollection.doc(itemId)).thenReturn(mockDocRef);
      when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(false);

      // Act & Assert
      expect(
        () => dataSource.getItem(itemId),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('watchItems', () {
    const userId = 'user_123';

    test('should return stream of ItemModels', () {
      // Arrange
      when(() => mockFirestore.collection('Item')).thenReturn(mockCollection);
      when(() => mockCollection.where('user_id', isEqualTo: userId))
          .thenReturn(mockQuery);

      final mockDocSnap = MockQueryDocumentSnapshot<Map<String, dynamic>>();
      when(() => mockDocSnap.id).thenReturn('test_item_1');
      when(() => mockDocSnap.data()).thenReturn({
        'item_name': 'Coffee',
        'count': 10,
        'todaycount': 5,
        'increment_by': 1,
        'reminder': 'TARGET',
        'reminder_value': 20,
        'lastResetTime': testDateTime.millisecondsSinceEpoch,
        'lastUpdated': testDateTime.millisecondsSinceEpoch,
        'user_id': 'user_123',
      });

      when(() => mockQuerySnapshot.docs).thenReturn([mockDocSnap]);
      final stream = Stream.value(mockQuerySnapshot);
      when(() => mockQuery.snapshots()).thenAnswer((_) => stream);

      // Act
      final result = dataSource.watchItems(userId);

      // Assert
      expect(result, emitsInOrder([
        isA<List<ItemModel>>()
            .having((list) => list.length, 'length', 1)
            .having((list) => list[0].name, 'first item name', 'Coffee'),
      ]));
    });
  });

  group('createItem', () {
    test('should call Firestore set with correct data', () async {
      // Arrange
      when(() => mockFirestore.collection('Item')).thenReturn(mockCollection);
      when(() => mockCollection.doc()).thenReturn(mockDocRef);
      when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockDocRef.id).thenReturn('generated_id');
      when(() => mockDocRef.set(any())).thenAnswer((_) async => {});

      final itemToCreate = ItemModel(
        id: '',
        name: testItemModel.name,
        count: testItemModel.count,
        todayCount: testItemModel.todayCount,
        incrementBy: testItemModel.incrementBy,
        reminder: testItemModel.reminder,
        reminderValue: testItemModel.reminderValue,
        lastResetTime: testItemModel.lastResetTime,
        lastUpdated: testItemModel.lastUpdated,
        userId: testItemModel.userId,
      );

      // Act
      final result = await dataSource.createItem(itemToCreate);

      // Assert
      expect(result, isA<ItemModel>());
      expect(result.id, isNotEmpty);
      verify(() => mockDocRef.set(any())).called(1);
    });

    test('should throw ServerException when Firestore fails', () async {
      // Arrange
      when(() => mockFirestore.collection('Item'))
          .thenThrow(Exception('Firestore error'));

      // Act & Assert
      expect(
        () => dataSource.createItem(testItemModel),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('updateItem', () {
    test('should call Firestore update with correct data', () async {
      // Arrange
      when(() => mockFirestore.collection('Item')).thenReturn(mockCollection);
      when(() => mockCollection.doc(testItemModel.id)).thenReturn(mockDocRef);
      when(() => mockDocRef.update(any())).thenAnswer((_) async => {});

      // Act
      final result = await dataSource.updateItem(testItemModel);

      // Assert
      expect(result, isA<ItemModel>());
      verify(() => mockDocRef.update(any())).called(1);
    });

    test('should throw ServerException when Firestore fails', () async {
      // Arrange
      when(() => mockFirestore.collection('Item'))
          .thenThrow(Exception('Firestore error'));

      // Act & Assert
      expect(
        () => dataSource.updateItem(testItemModel),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('deleteItem', () {
    const itemId = 'test_item_1';

    test('should delete item and associated EventLog entries', () async {
      // Arrange
      when(() => mockFirestore.collection('Item')).thenReturn(mockCollection);
      when(() => mockCollection.doc(itemId)).thenReturn(mockDocRef);
      when(() => mockDocRef.delete()).thenAnswer((_) async => {});

      final mockEventLogCollection = MockCollectionReference<Map<String, dynamic>>();
      final mockEventLogQuery = MockQuery<Map<String, dynamic>>();
      final mockEventLogSnapshot = MockQuerySnapshot<Map<String, dynamic>>();

      when(() => mockFirestore.collection('EventLog'))
          .thenReturn(mockEventLogCollection);
      when(() => mockEventLogCollection.where('item_id', isEqualTo: itemId))
          .thenReturn(mockEventLogQuery);
      when(() => mockEventLogQuery.get())
          .thenAnswer((_) async => mockEventLogSnapshot);
      when(() => mockEventLogSnapshot.docs).thenReturn([]);
      when(() => mockFirestore.batch()).thenReturn(mockBatch);
      when(() => mockBatch.commit()).thenAnswer((_) async => {});

      // Act
      await dataSource.deleteItem(itemId);

      // Assert
      verify(() => mockDocRef.delete()).called(1);
      verify(() => mockBatch.commit()).called(1);
    });

    test('should throw ServerException when Firestore fails', () async {
      // Arrange
      when(() => mockFirestore.collection('Item'))
          .thenThrow(Exception('Firestore error'));

      // Act & Assert
      expect(
        () => dataSource.deleteItem('item_id'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('incrementItem', () {
    const itemId = 'test_item_1';
    const amount = 5;

    test('should increment item count and todayCount', () async {
      // Arrange
      when(() => mockFirestore.collection('Item')).thenReturn(mockCollection);
      when(() => mockCollection.doc(itemId)).thenReturn(mockDocRef);
      when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(true);
      when(() => mockDocSnapshot.id).thenReturn(itemId);
      when(() => mockDocSnapshot.data()).thenReturn({
        'item_name': 'Coffee',
        'count': 10,
        'todaycount': 5,
        'increment_by': 1,
        'reminder': 'TARGET',
        'reminder_value': 20,
        'lastResetTime': testDateTime.millisecondsSinceEpoch,
        'lastUpdated': testDateTime.millisecondsSinceEpoch,
        'user_id': 'user_123',
      });
      when(() => mockDocRef.update(any())).thenAnswer((_) async => {});

      // Act
      final result = await dataSource.incrementItem(itemId, amount);

      // Assert
      expect(result, isA<ItemModel>());
      expect(result.count, 15); // 10 + 5
      expect(result.todayCount, 10); // 5 + 5
      verify(() => mockDocRef.update(any())).called(1);
    });

    test('should throw ServerException when item does not exist', () async {
      // Arrange
      when(() => mockFirestore.collection('Item')).thenReturn(mockCollection);
      when(() => mockCollection.doc(itemId)).thenReturn(mockDocRef);
      when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(false);

      // Act & Assert
      expect(
        () => dataSource.incrementItem(itemId, amount),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('resetDailyCount', () {
    const itemId = 'test_item_1';

    test('should reset todaycount and update timestamps', () async {
      // Arrange
      when(() => mockFirestore.collection('Item')).thenReturn(mockCollection);
      when(() => mockCollection.doc(itemId)).thenReturn(mockDocRef);
      when(() => mockDocRef.update(any())).thenAnswer((_) async => {});

      // Act
      await dataSource.resetDailyCount(itemId);

      // Assert
      verify(() => mockDocRef.update(any())).called(1);
    });

    test('should throw ServerException when Firestore fails', () async {
      // Arrange
      when(() => mockFirestore.collection('Item'))
          .thenThrow(Exception('Firestore error'));

      // Act & Assert
      expect(
        () => dataSource.resetDailyCount(itemId),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
