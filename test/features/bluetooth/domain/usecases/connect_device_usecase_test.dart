import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:trackwise/features/bluetooth/domain/usecases/connect_device_usecase.dart';

class MockBluetoothRepository extends Mock implements BluetoothRepository {}

void main() {
  late ConnectDeviceUseCase useCase;
  late MockBluetoothRepository mockRepository;

  setUp(() {
    mockRepository = MockBluetoothRepository();
    useCase = ConnectDeviceUseCase(mockRepository);
  });

  const tDeviceId = 'test-device-id';

  group('ConnectDeviceUseCase', () {
    test('should call repository.connect with device id', () async {
      // arrange
      when(() => mockRepository.connect(tDeviceId))
          .thenAnswer((_) async => const Right(true));

      // act
      final result = await useCase(const ConnectDeviceParams(tDeviceId));

      // assert
      expect(result, const Right(true));
      verify(() => mockRepository.connect(tDeviceId)).called(1);
    });

    test('should return failure from repository', () async {
      // arrange
      when(() => mockRepository.connect(tDeviceId))
          .thenAnswer((_) async => const Left(BluetoothFailure('Connection failed')));

      // act
      final result = await useCase(const ConnectDeviceParams(tDeviceId));

      // assert
      expect(result, isA<Left>());
      expect((result as Left).value, isA<BluetoothFailure>());
    });

    test('should return Right(false) when device missing characteristics', () async {
      // arrange
      when(() => mockRepository.connect(tDeviceId))
          .thenAnswer((_) async => const Right(false));

      // act
      final result = await useCase(const ConnectDeviceParams(tDeviceId));

      // assert
      expect(result, const Right(false));
    });
  });

  group('ConnectDeviceParams', () {
    test('props should contain deviceId', () {
      const params = ConnectDeviceParams(tDeviceId);
      expect(params.props, [tDeviceId]);
    });

    test('two params with same deviceId should be equal', () {
      const params1 = ConnectDeviceParams(tDeviceId);
      const params2 = ConnectDeviceParams(tDeviceId);
      expect(params1, equals(params2));
    });

    test('two params with different deviceId should not be equal', () {
      const params1 = ConnectDeviceParams('device-1');
      const params2 = ConnectDeviceParams('device-2');
      expect(params1, isNot(equals(params2)));
    });
  });
}
