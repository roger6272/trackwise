import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:trackwise/features/items/domain/repositories/item_repository.dart';
import 'package:trackwise/features/items/domain/usecases/get_items_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/watch_items_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/create_item_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/update_item_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/delete_item_usecase.dart';
import 'package:trackwise/features/items/domain/usecases/increment_item_usecase.dart';
import 'package:trackwise/features/items/data/datasources/item_remote_datasource.dart';

// Domain mocks
class MockItemRepository extends Mock implements ItemRepository {}

class MockGetItemsUseCase extends Mock implements GetItemsUseCase {}

class MockWatchItemsUseCase extends Mock implements WatchItemsUseCase {}

class MockCreateItemUseCase extends Mock implements CreateItemUseCase {}

class MockUpdateItemUseCase extends Mock implements UpdateItemUseCase {}

class MockDeleteItemUseCase extends Mock implements DeleteItemUseCase {}

class MockIncrementItemUseCase extends Mock implements IncrementItemUseCase {}

// Data mocks
class MockItemRemoteDataSource extends Mock implements ItemRemoteDataSource {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference<T> extends Mock
    implements CollectionReference<T> {}

class MockDocumentReference<T> extends Mock implements DocumentReference<T> {}

class MockDocumentSnapshot<T> extends Mock implements DocumentSnapshot<T> {}

class MockQuerySnapshot<T> extends Mock implements QuerySnapshot<T> {}

class MockQuery<T> extends Mock implements Query<T> {}

class MockQueryDocumentSnapshot<T> extends Mock
    implements QueryDocumentSnapshot<T> {}

class MockWriteBatch extends Mock implements WriteBatch {}
