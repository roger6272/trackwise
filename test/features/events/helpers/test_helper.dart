import 'package:mocktail/mocktail.dart';

import 'package:trackwise/features/events/domain/repositories/event_log_repository.dart';
import 'package:trackwise/features/events/domain/usecases/get_events_by_date_range_usecase.dart';
import 'package:trackwise/features/events/domain/usecases/get_events_by_item_usecase.dart';
import 'package:trackwise/features/events/domain/usecases/insert_events_usecase.dart';
import 'package:trackwise/features/events/domain/usecases/delete_events_for_item_usecase.dart';
import 'package:trackwise/features/events/data/datasources/event_log_remote_datasource.dart';

// Domain mocks
class MockEventLogRepository extends Mock implements EventLogRepository {}

class MockGetEventsByDateRangeUseCase extends Mock
    implements GetEventsByDateRangeUseCase {}

class MockGetEventsByItemUseCase extends Mock
    implements GetEventsByItemUseCase {}

class MockInsertEventsUseCase extends Mock implements InsertEventsUseCase {}

class MockDeleteEventsForItemUseCase extends Mock
    implements DeleteEventsForItemUseCase {}

// Data mocks
class MockEventLogRemoteDataSource extends Mock
    implements EventLogRemoteDataSource {}
