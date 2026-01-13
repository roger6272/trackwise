import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/bluetooth_repository.dart';

/// Use case for stopping an active BLE scan.
@lazySingleton
class StopScanUseCase extends UseCase<void, NoParams> {
  final BluetoothRepository repository;

  StopScanUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return await repository.stopScan();
  }
}
