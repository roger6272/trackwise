import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:trackwise/features/bluetooth/domain/usecases/request_device_data_usecase.dart';

class MockBluetoothRepository extends Mock implements BluetoothRepository {}

void main() {
  late RequestDeviceDataUseCase useCase;
  late MockBluetoothRepository mockRepository;

  setUp(() {
    mockRepository = MockBluetoothRepository();
    useCase = RequestDeviceDataUseCase(mockRepository);
  });

  const tDeviceId = 'test-device-id';

  group('RequestDeviceDataUseCase', () {
    test('should call repository.requestData for prefs', () async {
      // arrange
      when(() => mockRepository.requestData(tDeviceId, 'prefs', 0))
          .thenAnswer((_) async => const Right(null));

      // act
      final result = await useCase(RequestDeviceDataParams(
        deviceId: tDeviceId,
        type: DeviceDataType.prefs,
        page: 0,
      ));

      // assert
      expect(result, const Right(null));
      verify(() => mockRepository.requestData(tDeviceId, 'prefs', 0)).called(1);
    });

    test('should call repository.requestData for logs with page', () async {
      // arrange
      when(() => mockRepository.requestData(tDeviceId, 'logs', 2))
          .thenAnswer((_) async => const Right(null));

      // act
      final result = await useCase(RequestDeviceDataParams(
        deviceId: tDeviceId,
        type: DeviceDataType.logs,
        page: 2,
      ));

      // assert
      expect(result, const Right(null));
      verify(() => mockRepository.requestData(tDeviceId, 'logs', 2)).called(1);
    });

    test('should return ValidationFailure for negative page number', () async {
      // act
      final result = await useCase(RequestDeviceDataParams(
        deviceId: tDeviceId,
        type: DeviceDataType.logs,
        page: -1,
      ));

      // assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<ValidationFailure>());
      verifyNever(() => mockRepository.requestData(any(), any(), any()));
    });

    test('should return failure from repository', () async {
      // arrange
      when(() => mockRepository.requestData(tDeviceId, 'prefs', 0))
          .thenAnswer((_) async => const Left(BluetoothFailure('Request failed')));

      // act
      final result = await useCase(RequestDeviceDataParams(
        deviceId: tDeviceId,
        type: DeviceDataType.prefs,
      ));

      // assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<BluetoothFailure>());
    });
  });

  group('RequestDeviceDataParams', () {
    test('typeString should return "prefs" for DeviceDataType.prefs', () {
      final params = RequestDeviceDataParams(
        deviceId: tDeviceId,
        type: DeviceDataType.prefs,
      );
      expect(params.typeString, 'prefs');
    });

    test('typeString should return "logs" for DeviceDataType.logs', () {
      final params = RequestDeviceDataParams(
        deviceId: tDeviceId,
        type: DeviceDataType.logs,
      );
      expect(params.typeString, 'logs');
    });

    test('page should default to 0', () {
      final params = RequestDeviceDataParams(
        deviceId: tDeviceId,
        type: DeviceDataType.prefs,
      );
      expect(params.page, 0);
    });

    test('props should contain deviceId, type, and page', () {
      final params = RequestDeviceDataParams(
        deviceId: tDeviceId,
        type: DeviceDataType.logs,
        page: 5,
      );
      expect(params.props, [tDeviceId, DeviceDataType.logs, 5]);
    });
  });

  group('DeviceDataType', () {
    test('should have prefs and logs values', () {
      expect(DeviceDataType.values, contains(DeviceDataType.prefs));
      expect(DeviceDataType.values, contains(DeviceDataType.logs));
      expect(DeviceDataType.values.length, 2);
    });
  });
}
