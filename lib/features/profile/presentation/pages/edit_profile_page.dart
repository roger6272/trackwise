import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_util.dart';
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
    final textTheme = Theme.of(context).textTheme;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final secondaryBackground = AppColors.secondaryBackground(brightness);

    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileUpdated) {
          setState(() => _isSaving = false);
          showSuccessSnackBar(context, 'Profile updated successfully');
          context.pop();
        } else if (state is ProfileError) {
          setState(() => _isSaving = false);
          showErrorSnackBar(context, state.message);
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: primaryBackground,
          appBar: AppBar(
            backgroundColor: primaryBackground,
            leading: IconButton(
              tooltip: 'Back',
              icon: Icon(Icons.arrow_back_rounded, color: primaryText, size: 30.0),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Edit Profile',
              style: textTheme.titleLarge?.copyWith(
                color: primaryText,
              ),
            ),
            centerTitle: true,
            elevation: 0.0,
            actions: [
              TextButton(
                onPressed: _hasChanges && !_isSaving ? _saveProfile : null,
                child: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Text(
                        'Save',
                        style: textTheme.bodyLarge?.copyWith(
                          color: _hasChanges ? AppColors.primary : secondaryText,
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
                    style: textTheme.bodySmall?.copyWith(
                      color: secondaryText,
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

  Widget _buildTextField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String hintText,
    required Color primaryText,
    required Color secondaryText,
    required Color secondaryBackground,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: primaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8.0),
        TextField(
          controller: controller,
          style: textTheme.bodyLarge?.copyWith(
            color: primaryText,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: secondaryText),
            filled: true,
            fillColor: secondaryBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: AppColors.primary, width: 2.0),
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
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: primaryText,
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
            style: textTheme.bodyLarge?.copyWith(
              color: secondaryText,
            ),
          ),
        ),
      ],
    );
  }
}
