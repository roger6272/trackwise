import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/ota_bloc.dart';
import '../bloc/ota_event.dart';
import '../bloc/ota_state.dart';
import 'ota_progress_sheet.dart';

/// Banner widget that appears on the bluetooth page when a firmware update
/// is available, the app needs updating, or OTA is in progress.
///
/// - Optional update: Dismissable with tap to open progress sheet
/// - Required update: Non-dismissable, persistent
/// - App update required: Informational message
/// - Transfer in progress: Shows current step
class UpdateBanner extends StatelessWidget {
  /// Negotiated BLE MTU for the connected device.
  final int negotiatedMtu;

  const UpdateBanner({super.key, required this.negotiatedMtu});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OtaBloc, OtaBlocState>(
      builder: (context, state) {
        return switch (state) {
          OtaUpdateAvailable() => _UpdateAvailableBanner(
              state: state,
              negotiatedMtu: negotiatedMtu,
            ),
          OtaAppUpdateRequired() => _AppUpdateBanner(state: state),
          OtaBlocDownloading() => _TransferProgressBanner(
              label: 'Downloading firmware...',
              progress: state.progress,
            ),
          OtaBlocTransferring() => _TransferProgressBanner(
              label: 'Transferring to device...',
              progress: state.progress,
              showWarning: true,
            ),
          OtaBlocVerifying() => _TransferProgressBanner(
              label: 'Verifying firmware...',
              progress: null,
              showWarning: true,
            ),
          OtaBlocRebooting() => _TransferProgressBanner(
              label: 'Device is rebooting...',
              progress: null,
            ),
          OtaBlocComplete() => _CompleteBanner(newVersion: state.newVersion),
          OtaBlocError() => _ErrorBanner(message: state.message),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

// ========== Update Available Banner ==========

class _UpdateAvailableBanner extends StatelessWidget {
  final OtaUpdateAvailable state;
  final int negotiatedMtu;

  const _UpdateAvailableBanner({required this.state, required this.negotiatedMtu});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = AppColors.primaryAdaptive(brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Semantics(
        label: 'Firmware update available: version ${state.info.version}',
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8.0),
              onTap: () => _showProgressSheet(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                child: Row(
                  children: [
                    Icon(Icons.system_update, size: 20, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Firmware v${state.info.version} available',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (state.info.changelog.isNotEmpty)
                            Text(
                              state.info.changelog,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: color.withValues(alpha: 0.7),
                                    fontSize: 11.0,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    if (!state.isRequired)
                      Semantics(
                        label: 'Dismiss update banner',
                        child: IconButton(
                          icon: Icon(Icons.close, size: 18, color: color),
                          onPressed: () {
                            context.read<OtaBloc>().add(const DismissUpdateBanner());
                          },
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showProgressSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<OtaBloc>(),
        child: OtaProgressSheet(
          firmwareInfo: state.info,
          negotiatedMtu: negotiatedMtu,
        ),
      ),
    );
  }
}

// ========== App Update Banner ==========

class _AppUpdateBanner extends StatelessWidget {
  final OtaAppUpdateRequired state;

  const _AppUpdateBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Semantics(
        label: 'App update required to version ${state.minAppVersion}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.phone_android, size: 20, color: AppColors.warningText(Theme.of(context).brightness)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Update the Traxelos app to use this feature',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.warningText(Theme.of(context).brightness),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== Transfer Progress Banner ==========

class _TransferProgressBanner extends StatelessWidget {
  final String label;
  final double? progress;
  final bool showWarning;

  const _TransferProgressBanner({
    required this.label,
    this.progress,
    this.showWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = AppColors.primaryAdaptive(brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Semantics(
        label: progress != null
            ? '$label ${(progress! * 100).toInt()} percent'
            : label,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: color,
                      value: progress,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  if (progress != null)
                    Text(
                      '${(progress! * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: color.withValues(alpha: 0.15),
                    color: color,
                    minHeight: 3,
                  ),
                ),
              ],
              if (showWarning) ...[
                const SizedBox(height: 4),
                Text(
                  'Don\'t turn off your device',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 10.0,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ========== Complete Banner ==========

class _CompleteBanner extends StatelessWidget {
  final String newVersion;

  const _CompleteBanner({required this.newVersion});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Semantics(
        label: 'Firmware updated to version $newVersion',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 20, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Firmware updated to v$newVersion',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== Error Banner ==========

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Semantics(
        label: 'Firmware update error: $message',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, size: 20, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
