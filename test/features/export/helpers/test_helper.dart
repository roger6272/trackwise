import 'package:mocktail/mocktail.dart';
import 'package:trackwise/features/events/domain/repositories/event_log_repository.dart';
import 'package:trackwise/features/export/data/datasources/firestore_mail_datasource.dart';
import 'package:trackwise/features/export/domain/usecases/generate_csv_usecase.dart';

/// Mock classes for Export tests.
class MockEventLogRepository extends Mock implements EventLogRepository {}

class MockFirestoreMailDataSource extends Mock implements FirestoreMailDataSource {}

class MockGenerateCSVUseCase extends Mock implements GenerateCSVUseCase {}
