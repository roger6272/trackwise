import 'package:mocktail/mocktail.dart';

import 'package:traxelos/features/events/domain/repositories/event_log_repository.dart';
import 'package:traxelos/features/items/domain/repositories/item_repository.dart';
import 'package:traxelos/features/charts/domain/usecases/get_chart_data_usecase.dart';
import 'package:traxelos/features/charts/domain/usecases/get_cumulative_chart_data_usecase.dart';

// Domain mocks
class MockEventLogRepository extends Mock implements EventLogRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockGetChartDataUseCase extends Mock implements GetChartDataUseCase {}

class MockGetCumulativeChartDataUseCase extends Mock
    implements GetCumulativeChartDataUseCase {}
