import 'package:equatable/equatable.dart';

/// Base state class for Export BLoC.
abstract class ExportState extends Equatable {
  const ExportState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any export is triggered.
class ExportInitial extends ExportState {
  const ExportInitial();
}

/// Loading state while generating and sending export.
class ExportInProgress extends ExportState {
  const ExportInProgress();
}

/// Success state after export is sent.
class ExportSuccess extends ExportState {
  const ExportSuccess();
}

/// Error state with failure message.
class ExportError extends ExportState {
  final String message;

  const ExportError(this.message);

  @override
  List<Object?> get props => [message];
}
