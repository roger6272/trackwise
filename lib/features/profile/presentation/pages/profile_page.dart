import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth;
import '../../../bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_event.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_state.dart';
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
  // Static colors (theme-independent)
  static const Color _primary = Color(0xFF4B39EF);
  static const Color _error = Color(0xFFFF5963);

  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(const LoadProfileEvent());
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'v${packageInfo.version} (${packageInfo.buildNumber})';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final secondaryBackground = AppColors.secondaryBackground(brightness);
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
            style: GoogleFonts.interTight(
              color: primaryText,
              fontSize: 20.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: BlocConsumer<ProfileBloc, ProfileState>(
            listener: (context, state) {
              if (state is AccountDeleted) {
                _handleAccountDeleted(context);
              } else if (state is ProfileError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: _error,
                  ),
                );
              }
            },
            builder: (context, state) {
              if (state is ProfileLoading || state is AccountDeleting) {
                return Center(
                  child: SizedBox(
                    width: 50.0,
                    height: 50.0,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(_primary),
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
                          style: GoogleFonts.inter(
                            color: secondaryText.withValues(alpha: 0.5),
                            fontSize: 12.0,
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
            style: GoogleFonts.interTight(
              color: primaryText,
              fontSize: 24.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            profile.email,
            style: GoogleFonts.inter(
              color: secondaryText,
              fontSize: 14.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final primaryText = AppColors.primaryText(Theme.of(context).brightness);
    return Text(
      title,
      style: GoogleFonts.interTight(
        color: primaryText,
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
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
  }) {
    final brightness = Theme.of(context).brightness;
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
                          style: GoogleFonts.inter(
                            color: effectiveColor,
                            fontSize: 16.0,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2.0),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              color: disabledColor,
                              fontSize: 12.0,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
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
        icon: Icon(Icons.logout, color: _error, size: 24.0),
        label: Text(
          'Log Out',
          style: GoogleFonts.interTight(
            color: _error,
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFE6E6),
          foregroundColor: _error,
          elevation: 0.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(color: _error, width: 1.0),
          ),
          padding: const EdgeInsets.all(8.0),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton(BuildContext context) {
    final brightness = Theme.of(context).brightness;
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
            color: _error.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: _error,
              size: 24.0,
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete Account',
                    style: GoogleFonts.inter(
                      color: _error,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    'Permanently delete your account and all data',
                    style: GoogleFonts.inter(
                      color: secondaryText,
                      fontSize: 12.0,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete all your data including:\n\n'
          '- Your profile\n'
          '- All items\n'
          '- All event logs\n'
          '- Your account\n\n'
          'This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showFinalDeleteConfirmation(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text == 'DELETE') {
                Navigator.pop(context);
                context.read<ProfileBloc>().add(const DeleteAccountEvent());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please type DELETE to confirm'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  void _showSignOutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(const SignOutEvent());
            },
            child: const Text('Sign Out'),
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
          style: GoogleFonts.interTight(
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
              style: GoogleFonts.inter(
                color: primaryText,
                fontSize: 14.0,
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              '• All counts will be set to 0\n'
              '• A new cycle will begin for each item\n'
              '• Historical data will be preserved',
              style: GoogleFonts.inter(
                color: secondaryText,
                fontSize: 13.0,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              'This action cannot be undone.',
              style: GoogleFonts.inter(
                color: _error,
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
              style: GoogleFonts.inter(
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
              style: GoogleFonts.inter(
                color: _primary,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to continue'),
          backgroundColor: _error,
        ),
      );
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
          backgroundColor: _error,
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

        // Send reset items to device
        bluetoothBloc.add(SendItemsToDevice(resetItems!, categoryNames: categoryNames));
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Started new cycle for ${resetItems!.length} items'),
          backgroundColor: Colors.green,
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

  void _handleAccountDeleted(BuildContext context) {
    // Clean up device if connected
    try {
      final bluetoothBloc = context.read<BluetoothBloc>();
      if (bluetoothBloc.state.isConnected) {
        // Clear all items from device (send empty list)
        bluetoothBloc.add(const SendItemsToDevice([]));
        // Deselect current item
        bluetoothBloc.add(const SendSelectedItem('none'));
        // Clear device logs
        bluetoothBloc.add(const ClearDeviceLogs());
      }
    } catch (e) {
      // Ignore errors during cleanup - account deletion should proceed
      debugPrint('Device cleanup error during account deletion: $e');
    }

    // Navigate to login screen and clear stack
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
