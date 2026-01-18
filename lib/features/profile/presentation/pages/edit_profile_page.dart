import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/user_profile.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';

/// Page for editing user profile information.
class EditProfilePage extends StatefulWidget {
  final UserProfile profile;

  const EditProfilePage({super.key, required this.profile});

  static const String routeName = 'EditProfilePage';
  static const String routePath = '/profile/edit';

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const Color _primary = Color(0xFF4B39EF);

  late TextEditingController _displayNameController;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile.displayName ?? '',
    );
    _displayNameController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _displayNameController.removeListener(_onFieldChanged);
    _displayNameController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    final hasChanges = _displayNameController.text != (widget.profile.displayName ?? '');
    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  void _saveProfile() {
    if (!_hasChanges || _isSaving) return;

    setState(() => _isSaving = true);

    context.read<ProfileBloc>().add(
          UpdateProfileEvent(
            displayName: _displayNameController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final secondaryBackground = AppColors.secondaryBackground(brightness);

    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileUpdated) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        } else if (state is ProfileError) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: primaryBackground,
          appBar: AppBar(
            backgroundColor: primaryBackground,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: primaryText, size: 30.0),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Edit Profile',
              style: GoogleFonts.interTight(
                color: primaryText,
                fontSize: 20.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
            elevation: 2.0,
            actions: [
              TextButton(
                onPressed: _hasChanges && !_isSaving ? _saveProfile : null,
                child: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primary,
                        ),
                      )
                    : Text(
                        'Save',
                        style: GoogleFonts.inter(
                          color: _hasChanges ? _primary : secondaryText,
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile photo
                  _buildProfilePhoto(context, secondaryText),
                  const SizedBox(height: 32.0),

                  // Display name field
                  _buildTextField(
                    context,
                    label: 'Display Name',
                    controller: _displayNameController,
                    hintText: 'Enter your name',
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    secondaryBackground: secondaryBackground,
                  ),
                  const SizedBox(height: 20.0),

                  // Email field (read-only)
                  _buildReadOnlyField(
                    context,
                    label: 'Email',
                    value: widget.profile.email,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    secondaryBackground: secondaryBackground,
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    'Email cannot be changed',
                    style: GoogleFonts.inter(
                      color: secondaryText,
                      fontSize: 12.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhoto(BuildContext context, Color secondaryText) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120.0,
              height: 120.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _primary, width: 3.0),
                image: widget.profile.photoUrl != null
                    ? DecorationImage(
                        fit: BoxFit.cover,
                        image: NetworkImage(widget.profile.photoUrl!),
                      )
                    : const DecorationImage(
                        fit: BoxFit.cover,
                        image: NetworkImage(
                          'https://images.unsplash.com/photo-1607346256330-dee7af15f7c5?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHJhbmRvbXx8fHx8fHx8fDE3NTQwNzQzODZ8&ixlib=rb-4.1.0&q=80&w=1080',
                        ),
                      ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 36.0,
                height: 36.0,
                decoration: BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.0),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18.0),
                  onPressed: () {
                    // TODO: Implement photo picker
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Photo picker coming soon')),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        Text(
          'Tap to change photo',
          style: GoogleFonts.inter(
            color: secondaryText,
            fontSize: 14.0,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String hintText,
    required Color primaryText,
    required Color secondaryText,
    required Color secondaryBackground,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: primaryText,
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8.0),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(
            color: primaryText,
            fontSize: 16.0,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(color: secondaryText),
            filled: true,
            fillColor: secondaryBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: _primary, width: 2.0),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(
    BuildContext context, {
    required String label,
    required String value,
    required Color primaryText,
    required Color secondaryText,
    required Color secondaryBackground,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: primaryText,
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8.0),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          decoration: BoxDecoration(
            color: secondaryBackground,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: secondaryText,
              fontSize: 16.0,
            ),
          ),
        ),
      ],
    );
  }
}
