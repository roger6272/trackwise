import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/send_email_params.dart';
import '../../domain/usecases/send_email_with_csv_usecase.dart';
import 'export_event.dart';
import 'export_state.dart';

/// BLoC for managing CSV export functionality.
///
/// Handles export requests by generating CSV data and sending
/// it to the user's email via Firebase Mail Extension.
@injectable
class ExportBloc extends Bloc<ExportEvent, ExportState> {
  final SendEmailWithCSVUseCase sendEmailWithCSVUseCase;

  ExportBloc({
    required this.sendEmailWithCSVUseCase,
  }) : super(const ExportInitial()) {
    on<ExportCSV>(_onExportCSV);
    on<ResetExport>(_onResetExport);
  }

  /// Handle ExportCSV - generate and send CSV via email.
  ///
  /// Emits:
  /// 1. ExportInProgress - while generating and sending
  /// 2. ExportSuccess - on successful send
  /// 3. ExportError - on failure
  Future<void> _onExportCSV(
    ExportCSV event,
    Emitter<ExportState> emit,
  ) async {
    emit(const ExportInProgress());

    final result = await sendEmailWithCSVUseCase(
      SendEmailParams(
        email: event.email,
        startDate: event.startDate,
        endDate: event.endDate,
        aggregationLevel: event.aggregationLevel,
        latestCycleOnly: event.latestCycleOnly,
        itemIds: event.itemIds,
        includeDeviceColumn: event.includeDeviceColumn,
        deviceNameMap: event.deviceNameMap,
      ),
    );

    result.fold(
      (failure) => emit(ExportError(failure.message)),
      (_) => emit(const ExportSuccess()),
    );
  }

  /// Handle ResetExport - reset to initial state.
  void _onResetExport(
    ResetExport event,
    Emitter<ExportState> emit,
  ) {
    emit(const ExportInitial());
  }
}
