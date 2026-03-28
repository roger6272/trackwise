import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/services/analytics_service.dart';
import 'package:traxelos/features/ota/domain/repositories/ota_repository.dart';
import 'package:traxelos/features/ota/domain/usecases/check_for_update.dart';
import 'package:traxelos/features/ota/domain/usecases/perform_ota_update.dart';

class MockOtaRepository extends Mock implements OtaRepository {}

class MockCheckForUpdateUseCase extends Mock implements CheckForUpdateUseCase {}

class MockPerformOtaUpdateUseCase extends Mock
    implements PerformOtaUpdateUseCase {}

class MockAnalyticsService extends Mock implements AnalyticsService {}
