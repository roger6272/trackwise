import 'package:mocktail/mocktail.dart';

import 'package:trackwise/features/events/domain/repositories/event_log_repository.dart';
import 'package:trackwise/features/charts/domain/usecases/get_chart_data_usecase.dart';
import 'package:trackwise/features/charts/domain/usecases/get_cumulative_chart_data_usecase.dart';

// Domain mocks
class MockEventLogRepository extends Mock implements EventLogRepository {}

class MockGetChartDataUseCase extends Mock implements GetChartDataUseCase {}

class MockGetCumulativeChartDataUseCase extends Mock
    implements GetCumulativeChartDataUseCase {}
