import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_util.dart';
import '../../../../core/utils/logger.dart';
import '../../../../main.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth;
import '../../../bluetooth/domain/repositories/bluetooth_repository.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_event.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_state.dart';
import '../../../bluetooth/presentation/utils/device_sync_helper.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../../items/domain/entities/item.dart';
import '../../../items/domain/repositories/item_repository.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import 'privacy_policy_page.dart';

/// Profile page styled to match FlutterFlow ProfilePageWidget design.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  static String routeName = 'ProfilePage';
  static String routePath = '/profile';

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(const LoadProfileEvent());
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${packageInfo.version} (${packageInfo.buildNumber})';
        });
      }
    } catch (e) {
      AppLogger.debug('Failed to load app version: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;

    // Theme-aware colors
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        backgroundColor: primaryBackground,
        appBar: AppBar(
          backgroundColor: primaryBackground,
          automaticallyImplyLeading: false,
          title: Text(
            'Account',
            style: textTheme.titleLarge?.copyWith(
              color: primaryText,
            ),
          ),
          centerTitle: true,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: BlocConsumer<ProfileBloc, ProfileState>(
            listener: (context, state) async {
              if (state is AccountDeleted) {
                await _handleAccountDeleted(context);
              } else if (state is ProfileError) {
                // If deletion failed due to re-auth required, show reauthentication dialog
                if (state.message.toLowerCase().contains('sign in') ||
                    state.message.toLowerCase().contains('log in')) {
                  _showReauthenticationDialog(context);
                  return;
                }
                showErrorSnackBar(context, state.message);
              }
            },
            builder: (context, state) {
              if (state is ProfileLoading || state is AccountDeleting) {
                return Center(
                  child: SizedBox(
                    width: 50.0,
                    height: 50.0,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24.0),
                      // Profile header
                      if (state is ProfileLoaded || state is ProfileUpdated)
                        _buildProfileHeader(context, state),
                      const SizedBox(height: 24.0),
                      // Divider
                      Container(
                        width: double.infinity,
                        height: 1.0,
                        color: alternate,
                      ),
                      const SizedBox(height: 24.0),
                      // Appearance
                      _buildSectionTitle(context, 'Appearance'),
                      const SizedBox(height: 16.0),
                      _buildSettingsCard(context, [
                        _buildSettingItem(
                          context,
                          icon: Icons.dark_mode_outlined,
                          title: 'Dark Mode',
                          trailing: Semantics(
                            label: 'Dark mode',
                            toggled: brightness == Brightness.dark,
                            child: Switch.adaptive(
                              value: brightness == Brightness.dark,
                              activeColor: AppColors.primary,
                              onChanged: (value) {
                                MyApp.of(context).setThemeMode(
                                  value ? ThemeMode.dark : ThemeMode.light,
                                );
                              },
                            ),
                          ),
                          onTap: () {
                            final isDark = brightness == Brightness.dark;
                            MyApp.of(context).setThemeMode(
                              isDark ? ThemeMode.light : ThemeMode.dark,
                            );
                          },
                        ),
                      ]),
                      const SizedBox(height: 24.0),
                      // Account Settings
                      _buildSectionTitle(context, 'Account Settings'),
                      const SizedBox(height: 16.0),
                      _buildSettingsCard(context, [
                        _buildSettingItem(
                          context,
                          icon: Icons.person_outline,
                          title: 'Edit Profile',
                          onTap: () => _navigateToEditProfile(context, state),
                        ),
                        _buildDivider(context),
                        _buildSettingItem(
                          context,
                          icon: Icons.lock_outline,
                          title: 'Privacy & Security',
                          onTap: () => _showPrivacyPolicy(context),
                        ),
                      ]),
                      const SizedBox(height: 24.0),
                      // Data Management
                      _buildSectionTitle(context, 'Data Management'),
                      const SizedBox(height: 16.0),
                      BlocBuilder<BluetoothBloc, BluetoothState>(
                        builder: (context, bluetoothState) {
                          final isConnected = bluetoothState.isConnected;
                          return _buildSettingsCard(context, [
                            _buildSettingItem(
                              context,
                              icon: Icons.category_outlined,
                              title: 'Manage Categories',
                              onTap: () => context.push('/profile/categories'),
                            ),
                            _buildDivider(context),
                            _buildSettingItem(
                              context,
                              icon: Icons.watch_outlined,
                              title: 'Paired Devices',
                              onTap: () => context.push('/profile/paired-devices'),
                            ),
                            _buildDivider(context),
                            _buildSettingItem(
                              context,
                              icon: Icons.restart_alt_outlined,
                              title: 'Start New Cycle',
                              subtitle: isConnected ? null : 'Requires device connection',
                              enabled: isConnected,
                              onTap: isConnected
                                  ? () => _showStartNewCycleDialog(context)
                                  : null,
                            ),
                            _buildDivider(context),
                            _buildSettingItem(
                              context,
                              icon: Icons.download_outlined,
                              title: 'Export My Data',
                              onTap: () => context.push('/profile/export'),
                            ),
                            _buildDivider(context),
                            _buildSettingItem(
                              context,
                              icon: Icons.delete_outline,
                              title: 'Recently Deleted',
                              onTap: () => context.push('/profile/deleted-items'),
                            ),
                          ]);
                        },
                      ),
                      const SizedBox(height: 24.0),
                      // Support
                      _buildSectionTitle(context, 'Support'),
                      const SizedBox(height: 16.0),
                      _buildSettingsCard(context, [
                        _buildSettingItem(
                          context,
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                          onTap: () => context.push('/profile/help'),
                        ),
                      ]),
                      const SizedBox(height: 24.0),
                      // Divider
                      Container(
                        width: double.infinity,
                        height: 1.0,
                        color: alternate,
                      ),
                      const SizedBox(height: 24.0),
                      // Logout button
                      _buildLogoutButton(context),
                      const SizedBox(height: 24.0),
                      // Danger Zone
                      _buildSectionTitle(context, 'Danger Zone'),
                      const SizedBox(height: 16.0),
                      _buildDeleteAccountButton(context),
                      const SizedBox(height: 32.0),
                      // App version
                      Center(
                        child: Text(
                          _appVersion,
                          style: textTheme.bodySmall?.copyWith(
                            color: secondaryText.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24.0),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, ProfileState state) {
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    final profile = state is ProfileLoaded
        ? state.profile
        : (state as ProfileUpdated).profile;

    return Center(
      child: Column(
        children: [
          Text(
            profile.displayName ?? 'No name set',
            style: textTheme.headlineSmall?.copyWith(
              color: primaryText,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            profile.email,
            style: textTheme.bodyMedium?.copyWith(
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final primaryText = AppColors.primaryText(Theme.of(context).brightness);
    final textTheme = Theme.of(context).textTheme;
    return Text(
      title,
      style: textTheme.titleSmall?.copyWith(
        color: primaryText,
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    final secondaryBackground = AppColors.secondaryBackground(Theme.of(context).brightness);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    String? subtitle,
    bool isPrimary = false,
    bool enabled = true,
    Widget? trailing,
  }) {
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final primaryColor = AppColors.primaryAdaptive(brightness);
    final disabledColor = secondaryText.withValues(alpha: 0.5);

    final effectiveColor = enabled
        ? (isPrimary ? primaryColor : primaryText)
        : disabledColor;

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: effectiveColor,
                    size: 24.0,
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: textTheme.bodyLarge?.copyWith(
                            color: effectiveColor,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2.0),
                          Text(
                            subtitle,
                            style: textTheme.bodySmall?.copyWith(
                              color: disabledColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            trailing ?? Icon(
              Icons.chevron_right,
              color: enabled ? secondaryText : disabledColor,
              size: 20.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final alternate = AppColors.alternate(Theme.of(context).brightness);
    return Divider(
      height: 1.0,
      thickness: 0.5,
      indent: 52.0,
      color: alternate,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56.0,
      child: ElevatedButton.icon(
        onPressed: () => _showSignOutConfirmation(context),
        icon: Icon(Icons.logout, color: AppColors.error, size: 24.0),
        label: Text(
          'Log Out',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.error,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.errorBackground(Theme.of(context).brightness),
          foregroundColor: AppColors.error,
          elevation: 0.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(color: AppColors.error, width: 1.0),
          ),
          padding: const EdgeInsets.all(8.0),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;
    final secondaryBackground = AppColors.secondaryBackground(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    return InkWell(
      onTap: () => _showDeleteConfirmation(context),
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 24.0,
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete Account',
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    'Permanently delete your account and all data',
                    style: textTheme.bodySmall?.copyWith(
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: secondaryText,
              size: 20.0,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);
    final isConnected = context.read<BluetoothBloc>().state.isConnected;

    final deviceMessage = isConnected
        ? 'Your connected device will be automatically reset and unpaired.'
        : 'Any paired devices not currently connected will need to be factory reset.\n\nOn device: Hold A+B for 7 seconds.';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete all your data including:\n\n'
              '• Your profile\n'
              '• All items\n'
              '• All event logs\n'
              '• Your account\n\n'
              'This action cannot be undone.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isConnected ? Icons.bluetooth_connected : Icons.info_outline,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      deviceMessage,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 13.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showFinalDeleteConfirmation(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFinalDeleteConfirmation(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Type DELETE to confirm account deletion:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Type DELETE',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text == 'DELETE') {
                Navigator.pop(dialogContext);
                // Clean up device BEFORE deleting account.
                // Account deletion triggers auth state change which redirects
                // to login, potentially before BlocConsumer listener runs.
                // Use page context (not dialog context) since dialog is dismissed.
                await _cleanupDevice(context);
                if (!context.mounted) return;
                context.read<ProfileBloc>().add(const DeleteAccountEvent());
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Please type DELETE to confirm'),
                    backgroundColor: AppColors.warning,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  void _showSignOutConfirmation(BuildContext context) {
    final bluetoothBloc = context.read<BluetoothBloc>();
    final authBloc = context.read<AuthBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Disconnect from device if connected (don't clear data, just disconnect)
              if (bluetoothBloc.state.isConnected) {
                bluetoothBloc.add(const DisconnectFromDevice());
                await Future.delayed(const Duration(milliseconds: 200));
              }
              authBloc.add(const SignOutEvent());
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog to reauthenticate before sensitive operations like account deletion.
  void _showReauthenticationDialog(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: primaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Session Expired',
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'For security, please sign in again to delete your account.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: secondaryText),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signing in...')),
              );
              // Reauthenticate and retry deletion
              final authRepository = sl<AuthRepository>();
              final result = await authRepository.reauthenticate();
              result.fold(
                (failure) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  showErrorSnackBar(context, failure.message);
                },
                (_) async {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  // Clean up device BEFORE deleting account (same reason as above)
                  await _cleanupDevice(context);
                  if (!context.mounted) return;
                  context.read<ProfileBloc>().add(const DeleteAccountEvent());
                },
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text(
              'Sign In & Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showStartNewCycleDialog(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: primaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Start New Cycle',
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will reset all items to start a new cycle:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: primaryText,
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              '• All counts will be set to 0\n'
              '• A new cycle will begin for each item\n'
              '• Historical data will be preserved',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: secondaryText,
                fontSize: 13.0,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              'This action cannot be undone.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
                fontSize: 13.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _executeStartNewCycle(context);
            },
            child: Text(
              'Start New Cycle',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeStartNewCycle(BuildContext context) async {
    // Get user ID
    final authState = context.read<AuthBloc>().state;
    if (authState is! auth.Authenticated) {
      showErrorSnackBar(context, 'Please sign in to continue');
      return;
    }
    final userId = authState.user.id;

    // Capture references before showing dialog
    final navigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final bluetoothBloc = context.read<BluetoothBloc>();

    // Show loading indicator using root navigator
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );

    String? errorMessage;
    List<Item>? resetItems;

    try {
      // Reset all items
      final itemRepository = sl<ItemRepository>();
      final result = await itemRepository.resetAllItems(userId);

      result.fold(
        (failure) {
          errorMessage = 'Failed to reset items: ${failure.message}';
        },
        (items) {
          resetItems = items;
        },
      );
    } catch (e) {
      errorMessage = 'Error: $e';
    }

    // Close loading indicator safely
    if (navigator.canPop()) {
      navigator.pop();
    }

    // Handle result after dialog is closed
    if (errorMessage != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (resetItems != null && resetItems!.isNotEmpty) {
      // Sync to device
      if (bluetoothBloc.state.isConnected) {
        // Get category names for device sync
        final categoryRepository = sl<CategoryRepository>();
        final categoriesResult = await categoryRepository.getCategories(userId);
        final categoryNames = categoriesResult.fold(
          (_) => <String, String>{},
          (categories) => {for (final c in categories) c.id: c.name},
        );

        syncItemsToDevice(
          bluetoothBloc: bluetoothBloc,
          allItems: resetItems!,
          deviceSelectedId: bluetoothBloc.state.selectedItemId,
          categoryNames: categoryNames,
        );
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Started new cycle for ${resetItems!.length} items'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showPrivacyPolicy(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PrivacyPolicyPage(),
      ),
    );
  }

  void _navigateToEditProfile(BuildContext context, ProfileState state) {
    if (state is ProfileLoaded) {
      context.push('/profile/edit', extra: state.profile);
    } else if (state is ProfileUpdated) {
      context.push('/profile/edit', extra: state.profile);
    }
  }

  Future<void> _handleAccountDeleted(BuildContext context) async {
    // Device cleanup already happened before DeleteAccountEvent was dispatched.
    // Navigate to login screen using go_router (replaces entire stack).
    context.go('/login');
  }

  /// Cleans up the Bluetooth device by unpairing and disconnecting.
  /// Called BEFORE account deletion to ensure the unpair command is sent
  /// while the page is still mounted (account deletion triggers auth state
  /// change which redirects to login via GoRouter).
  Future<void> _cleanupDevice(BuildContext context) async {
    try {
      final bluetoothBloc = context.read<BluetoothBloc>();
      final deviceId = bluetoothBloc.state.connectedDevice?.id;
      if (deviceId == null) return;

      // Send unpair directly via repository (awaited) to guarantee the
      // BLE write completes before proceeding to account deletion.
      final repository = sl<BluetoothRepository>();
      await repository.unpairDevice(deviceId);

      // Wait for firmware to process and commit NVS
      await Future.delayed(const Duration(milliseconds: 500));

      // Disconnect
      bluetoothBloc.add(const DisconnectFromDevice());
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      // Ignore errors during cleanup - account deletion should proceed
      AppLogger.debug('Device cleanup error: $e');
    }
  }
}
