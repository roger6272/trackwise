import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../items/domain/entities/item.dart';
import '../repositories/bluetooth_repository.dart';

/// Parameters for SendItemsToDeviceUseCase.
class SendItemsParams extends Equatable {
  final String deviceId;
  final List<Item> items;

  /// Map of categoryId -> categoryName for resolving category names.
  final Map<String, String> categoryNames;

  const SendItemsParams({
    required this.deviceId,
    required this.items,
    this.categoryNames = const {},
  });

  @override
  List<Object> get props => [deviceId, items, categoryNames];
}

/// Use case for sending item list to ESP32 device.
///
/// Formats items as JSON and handles 180-byte MTU chunking.
/// Validates that items list is not too large (max 100 items).
@lazySingleton
class SendItemsToDeviceUseCase extends UseCase<void, SendItemsParams> {
  final BluetoothRepository repository;

  /// Maximum number of items that can be sent to device.
  static const int maxItems = 100;

  SendItemsToDeviceUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(SendItemsParams params) async {
    // Validate items count
    if (params.items.length > maxItems) {
      return Left(ValidationFailure(
        'Cannot send more than $maxItems items to device. '
        'Current count: ${params.items.length}',
      ));
    }

    return await repository.sendItems(
      params.deviceId,
      params.items,
      categoryNames: params.categoryNames,
    );
  }
}
