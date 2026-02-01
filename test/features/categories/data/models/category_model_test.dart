import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/features/categories/domain/entities/category.dart';
import 'package:traxelos/features/categories/data/models/category_model.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  group('CategoryModel', () {
    test('should be a subclass of Category entity', () {
      expect(testCategoryModel, isA<Category>());
    });

    test('should convert to Firestore map correctly', () {
      // Act
      final result = testCategoryModel.toFirestore();

      // Assert
      expect(result['category_name'], 'Electronics');
      expect(result['order'], 0);
      expect(result['created_time'], isA<int>());
      expect(result['last_updated'], isA<int>());
      expect(result['created_time'], testDateTime.millisecondsSinceEpoch);
      expect(result['last_updated'], testDateTime.millisecondsSinceEpoch);
      // uid is not included in toFirestore (handled by datasource)
      expect(result.containsKey('uid'), isFalse);
    });

    test('should include deleted_at in Firestore map when set', () {
      // Arrange
      final deletedModel = CategoryModel(
        id: 'test',
        name: 'Test',
        userId: 'user',
        order: 0,
        createdAt: testDateTime,
        lastUpdated: testDateTime,
        deletedAt: testDateTime,
      );

      // Act
      final result = deletedModel.toFirestore();

      // Assert
      expect(result['deleted_at'], testDateTime.millisecondsSinceEpoch);
    });

    test('should not include deleted_at in Firestore map when null', () {
      // Act
      final result = testCategoryModel.toFirestore();

      // Assert
      expect(result.containsKey('deleted_at'), isFalse);
    });

    test('should convert from Firestore document with String uid', () {
      // Arrange
      final map = {
        'category_name': 'Electronics',
        'uid': 'user_123',
        'order': 0,
        'created_time': testDateTime.millisecondsSinceEpoch,
        'last_updated': testDateTime.millisecondsSinceEpoch,
      };

      final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      when(() => mockDoc.id).thenReturn('test_category_1');
      when(() => mockDoc.data()).thenReturn(map);

      // Act
      final result = CategoryModel.fromFirestore(mockDoc);

      // Assert
      expect(result.id, 'test_category_1');
      expect(result.name, 'Electronics');
      expect(result.userId, 'user_123');
      expect(result.order, 0);
      expect(result.deletedAt, isNull);
    });

    test('should convert from Firestore document with DocumentReference uid',
        () {
      // Arrange
      final mockDocRef = MockDocumentReference<Map<String, dynamic>>();
      when(() => mockDocRef.id).thenReturn('user_123');

      final map = {
        'category_name': 'Electronics',
        'uid': mockDocRef,
        'order': 0,
        'created_time': testDateTime.millisecondsSinceEpoch,
        'last_updated': testDateTime.millisecondsSinceEpoch,
      };

      final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      when(() => mockDoc.id).thenReturn('test_category_1');
      when(() => mockDoc.data()).thenReturn(map);

      // Act
      final result = CategoryModel.fromFirestore(mockDoc);

      // Assert
      expect(result.userId, 'user_123');
    });

    test('should handle Timestamp fields in fromFirestore', () {
      // Arrange
      final timestamp = Timestamp.fromDate(testDateTime);
      final map = {
        'category_name': 'Test',
        'uid': 'user_123',
        'order': 0,
        'created_time': timestamp,
        'last_updated': timestamp,
      };

      final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      when(() => mockDoc.id).thenReturn('test_id');
      when(() => mockDoc.data()).thenReturn(map);

      // Act
      final result = CategoryModel.fromFirestore(mockDoc);

      // Assert
      expect(result.createdAt, testDateTime);
      expect(result.lastUpdated, testDateTime);
    });

    test('should handle int (milliseconds) fields in fromFirestore', () {
      // Arrange
      final map = {
        'category_name': 'Test',
        'uid': 'user_123',
        'order': 0,
        'created_time': testDateTime.millisecondsSinceEpoch,
        'last_updated': testDateTime.millisecondsSinceEpoch,
      };

      final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      when(() => mockDoc.id).thenReturn('test_id');
      when(() => mockDoc.data()).thenReturn(map);

      // Act
      final result = CategoryModel.fromFirestore(mockDoc);

      // Assert
      expect(result.createdAt, testDateTime);
      expect(result.lastUpdated, testDateTime);
    });

    test('should handle missing fields with defaults', () {
      // Arrange
      final map = {
        'category_name': 'Test',
        'uid': 'user_123',
        // Missing: order, created_time, last_updated
      };

      final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      when(() => mockDoc.id).thenReturn('test_id');
      when(() => mockDoc.data()).thenReturn(map);

      // Act
      final result = CategoryModel.fromFirestore(mockDoc);

      // Assert
      expect(result.order, 0);
      expect(result.name, 'Test');
      expect(result.deletedAt, isNull);
    });

    test('should handle deleted_at with int value 0 as null', () {
      // Arrange
      final map = {
        'category_name': 'Test',
        'uid': 'user_123',
        'order': 0,
        'created_time': testDateTime.millisecondsSinceEpoch,
        'last_updated': testDateTime.millisecondsSinceEpoch,
        'deleted_at': 0,
      };

      final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      when(() => mockDoc.id).thenReturn('test_id');
      when(() => mockDoc.data()).thenReturn(map);

      // Act
      final result = CategoryModel.fromFirestore(mockDoc);

      // Assert
      expect(result.deletedAt, isNull);
    });

    test('should handle deleted_at with Timestamp', () {
      // Arrange
      final timestamp = Timestamp.fromDate(testDateTime);
      final map = {
        'category_name': 'Test',
        'uid': 'user_123',
        'order': 0,
        'created_time': testDateTime.millisecondsSinceEpoch,
        'last_updated': testDateTime.millisecondsSinceEpoch,
        'deleted_at': timestamp,
      };

      final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      when(() => mockDoc.id).thenReturn('test_id');
      when(() => mockDoc.data()).thenReturn(map);

      // Act
      final result = CategoryModel.fromFirestore(mockDoc);

      // Assert
      expect(result.deletedAt, testDateTime);
    });

    test('should handle DateTime conversion to milliseconds in toFirestore',
        () {
      // Arrange
      final specificDateTime = DateTime(2026, 3, 15, 10, 30, 45);
      final model = CategoryModel(
        id: 'test',
        name: 'Test',
        userId: 'user',
        order: 0,
        createdAt: specificDateTime,
        lastUpdated: specificDateTime,
      );

      // Act
      final result = model.toFirestore();

      // Assert
      expect(
          result['created_time'], specificDateTime.millisecondsSinceEpoch);
      expect(
          result['last_updated'], specificDateTime.millisecondsSinceEpoch);
    });

    test('toEntity should return the model itself (since it extends Category)',
        () {
      // Act
      final entity = testCategoryModel.toEntity();

      // Assert
      expect(entity, testCategoryModel);
      expect(entity.id, 'test_category_1');
      expect(entity.name, 'Electronics');
    });

    test('fromEntity should create model from domain entity', () {
      // Act
      final model = CategoryModel.fromEntity(testCategory);

      // Assert
      expect(model.id, testCategory.id);
      expect(model.name, testCategory.name);
      expect(model.userId, testCategory.userId);
      expect(model.order, testCategory.order);
      expect(model.createdAt, testCategory.createdAt);
      expect(model.lastUpdated, testCategory.lastUpdated);
      expect(model.deletedAt, testCategory.deletedAt);
    });

    test('fromEntity roundtrip preserves all fields', () {
      // Arrange
      final categoryWithDeletedAt = Category(
        id: 'cat_1',
        name: 'Test',
        userId: 'user_1',
        order: 3,
        createdAt: testDateTime,
        lastUpdated: testDateTime,
        deletedAt: testDateTime,
      );

      // Act
      final model = CategoryModel.fromEntity(categoryWithDeletedAt);
      final entity = model.toEntity();

      // Assert — Equatable props should match even though runtime types differ
      expect(entity.props, categoryWithDeletedAt.props);
      expect(entity.id, categoryWithDeletedAt.id);
      expect(entity.name, categoryWithDeletedAt.name);
      expect(entity.deletedAt, categoryWithDeletedAt.deletedAt);
    });
  });
}
