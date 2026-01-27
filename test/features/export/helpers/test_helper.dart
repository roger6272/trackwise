import 'package:mocktail/mocktail.dart';
import 'package:traxelos/features/categories/domain/repositories/category_repository.dart';
import 'package:traxelos/features/events/domain/repositories/event_log_repository.dart';
import 'package:traxelos/features/export/data/datasources/firestore_mail_datasource.dart';
import 'package:traxelos/features/export/domain/usecases/generate_csv_usecase.dart';
import 'package:traxelos/features/items/domain/repositories/item_repository.dart';

/// Mock classes for Export tests.
class MockEventLogRepository extends Mock implements EventLogRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockFirestoreMailDataSource extends Mock implements FirestoreMailDataSource {}

class MockGenerateCSVUseCase extends Mock implements GenerateCSVUseCase {}
