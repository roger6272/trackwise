import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
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

  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(const LoadProfileEvent());
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
            'Profile',
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
                      _buildSettingsCard(context, [
                        _buildSettingItem(
                          context,
                          icon: Icons.download_outlined,
                          title: 'Export My Data',
                          onTap: () => context.push('/profile/export'),
                          isPrimary: true,
                        ),
                        _buildDivider(context),
                        _buildSettingItem(
                          context,
                          icon: Icons.delete_outline,
                          title: 'Recently Deleted',
                          onTap: () => context.push('/profile/deleted-items'),
                        ),
                      ]),
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
                      const SizedBox(height: 32.0),
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
          Container(
            width: 120.0,
            height: 120.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _primary, width: 3.0),
              image: profile.photoUrl != null
                  ? DecorationImage(
                      fit: BoxFit.cover,
                      image: NetworkImage(profile.photoUrl!),
                    )
                  : const DecorationImage(
                      fit: BoxFit.cover,
                      image: NetworkImage(
                        'https://images.unsplash.com/photo-1607346256330-dee7af15f7c5?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHJhbmRvbXx8fHx8fHx8fDE3NTQwNzQzODZ8&ixlib=rb-4.1.0&q=80&w=1080',
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16.0),
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
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final primaryColor = AppColors.primaryAdaptive(brightness);

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: isPrimary ? primaryColor : primaryText,
                    size: 24.0,
                  ),
                  const SizedBox(width: 12.0),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: isPrimary ? primaryColor : primaryText,
                      fontSize: 16.0,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.chevron_right,
                color: secondaryText,
                size: 20.0,
              ),
            ],
          ),
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
    // Navigate to login screen and clear stack
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
