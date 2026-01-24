import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/bluetooth_repository.dart';

/// Parameters for SendSelectedItemUseCase.
class SendSelectedItemParams extends Equatable {
  final String deviceId;
  final String itemId;

  /// Device-side ID (0-99) for BLE communication
  final int deviceItemId;

  const SendSelectedItemParams({
    required this.deviceId,
    required this.itemId,
    required this.deviceItemId,
  });

  @override
  List<Object> get props => [deviceId, itemId, deviceItemId];
}

/// Use case for sending selected item command to ESP32.
///
/// Tells the ESP32 which item is currently active.
@lazySingleton
class SendSelectedItemUseCase extends UseCase<void, SendSelectedItemParams> {
  final BluetoothRepository repository;

  SendSelectedItemUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(SendSelectedItemParams params) async {
    // Validate itemId is not empty (allow 'none' for deselection)
    if (params.itemId.isEmpty) {
      return const Left(ValidationFailure('Item ID cannot be empty'));
    }

    return await repository.sendSelectedItem(
      params.deviceId,
      params.deviceItemId,
    );
  }
}
