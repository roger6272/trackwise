import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/bluetooth_constants.dart';
import '../../../bluetooth/domain/entities/paired_device.dart';
import '../../../bluetooth/presentation/bloc/device_connection_state.dart';
import '../bloc/ota_bloc.dart';
import '../bloc/ota_device_status.dart';
import '../bloc/ota_event.dart';
import '../bloc/ota_state.dart';
import 'ota_progress_sheet.dart';

/// Banner widget that appears on the bluetooth page when firmware updates
/// are available, the app needs updating, or OTA is in progress.
///
/// Supports per-device banners by iterating `state.deviceStatuses` and
/// showing an active transfer banner when applicable.
class UpdateBanner extends StatefulWidget {
  /// Connected devices keyed by deviceInstanceId.
  final Map<String, DeviceConnectionState> connectedDevices;

  /// All paired devices (used for name lookup).
  final List<PairedDevice> pairedDevices;

  const UpdateBanner({
    super.key,
    required this.connectedDevices,
    required this.pairedDevices,
  });

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  Timer? _autoDismissTimer;

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  String _deviceName(String deviceInstanceId) {
    final device = widget.pairedDevices
        .where((d) => d.deviceInstanceId == deviceInstanceId)
        .firstOrNull;
    return device?.deviceName ?? 'Unknown Device';
  }

  int _deviceMtu(String deviceInstanceId) {
    return widget.connectedDevices[deviceInstanceId]?.negotiatedMtu ??
        BluetoothConstants.defaultMtuLimit;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OtaBloc, OtaBlocState>(
      listenWhen: (prev, curr) => prev.activeTransfer != curr.activeTransfer,
      listener: (context, state) {
        _autoDismissTimer?.cancel();
        final transfer = state.activeTransfer;
        if (transfer is OtaTransferComplete || transfer is OtaTransferError) {
          _autoDismissTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) {
              context.read<OtaBloc>().add(const DismissTransferResult());
            }
          });
        }
      },
      child: BlocBuilder<OtaBloc, OtaBlocState>(
        builder: (context, state) {
          final banners = <Widget>[];

          // Active transfer banner first (if any)
          final transfer = state.activeTransfer;
          if (transfer != null) {
            banners.add(_buildTransferBanner(context, transfer));
          }

          // Per-device update banners
          for (final entry in state.deviceStatuses.entries) {
            // Skip the device that's actively being updated
            if (transfer != null &&
                entry.key == transfer.deviceInstanceId) {
              continue;
            }

            final status = entry.value;
            final name = _deviceName(entry.key);

            if (status is OtaDeviceUpdateAvailable) {
              banners.add(_UpdateAvailableBanner(
                deviceInstanceId: entry.key,
                deviceName: name,
                status: status,
                negotiatedMtu: _deviceMtu(entry.key),
              ));
            } else if (status is OtaDeviceAppUpdateRequired) {
              banners.add(_AppUpdateBanner(
                deviceName: name,
                minAppVersion: status.minAppVersion,
              ));
            }
          }

          if (banners.isEmpty) return const SizedBox.shrink();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: banners,
          );
        },
      ),
    );
  }

  Widget _buildTransferBanner(BuildContext context, OtaTransferState transfer) {
    final name = _deviceName(transfer.deviceInstanceId);
    return switch (transfer) {
      OtaTransferDownloading() => _TransferProgressBanner(
          label: '$name: Downloading firmware...',
          progress: transfer.progress,
        ),
      OtaTransferTransferring() => _TransferProgressBanner(
          label: '$name: Transferring to device...',
          progress: transfer.progress,
          showWarning: true,
        ),
      OtaTransferVerifying() => _TransferProgressBanner(
          label: '$name: Verifying firmware...',
          progress: null,
          showWarning: true,
        ),
      OtaTransferRebooting() => _TransferProgressBanner(
          label: '$name: Device is rebooting...',
          progress: null,
        ),
      OtaTransferComplete() => _CompleteBanner(
          deviceName: name,
          newVersion: transfer.newVersion,
        ),
      OtaTransferError() => _ErrorBanner(message: transfer.message),
    };
  }
}

// ========== Update Available Banner ==========

class _UpdateAvailableBanner extends StatelessWidget {
  final String deviceInstanceId;
  final String deviceName;
  final OtaDeviceUpdateAvailable status;
  final int negotiatedMtu;

  const _UpdateAvailableBanner({
    required this.deviceInstanceId,
    required this.deviceName,
    required this.status,
    required this.negotiatedMtu,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = AppColors.primaryAdaptive(brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Semantics(
        label: '$deviceName: Firmware update available: version ${status.info.version}',
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
                            '$deviceName: Firmware v${status.info.version} available',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (status.info.changelog.isNotEmpty)
                            Text(
                              status.info.changelog,
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
                    if (!status.isRequired)
                      Semantics(
                        label: 'Dismiss update banner for $deviceName',
                        child: IconButton(
                          icon: Icon(Icons.close, size: 18, color: color),
                          onPressed: () {
                            context.read<OtaBloc>().add(
                              DismissUpdateBanner(deviceInstanceId: deviceInstanceId),
                            );
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
          firmwareInfo: status.info,
          negotiatedMtu: negotiatedMtu,
          deviceInstanceId: deviceInstanceId,
        ),
      ),
    );
  }
}

// ========== App Update Banner ==========

class _AppUpdateBanner extends StatelessWidget {
  final String deviceName;
  final String minAppVersion;

  const _AppUpdateBanner({
    required this.deviceName,
    required this.minAppVersion,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Semantics(
        label: '$deviceName: App update required to version $minAppVersion',
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
                  '$deviceName: Update the Traxelos app to use this feature',
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
  final String deviceName;
  final String newVersion;

  const _CompleteBanner({
    required this.deviceName,
    required this.newVersion,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Semantics(
        label: '$deviceName updated to version $newVersion',
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
                  '$deviceName updated to v$newVersion',
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
