import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/auth/auth_state_notifier.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/repositories/user_repository.dart';

/// Onboarding page shown to new users after signup.
///
/// Collects:
/// - User's name (optional)
/// - Primary use case (required)
/// - How they heard about us (optional)
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  static const String routeName = 'OnboardingPage';
  static const String routePath = '/onboarding';

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _nameController = TextEditingController();
  final _otherUseCaseController = TextEditingController();
  final _otherReferralController = TextEditingController();

  String? _selectedUseCase;
  String? _selectedReferral;
  bool _isLoading = false;
  String? _errorMessage;

  static const _useCases = [
    ('inventory', 'Inventory Tracking', 'Track stock, supplies, or materials'),
    ('habits', 'Habit Tracking', 'Build and maintain daily habits'),
    ('fitness', 'Fitness & Exercise', 'Count reps, sets, or workouts'),
    ('manufacturing', 'Manufacturing', 'Track production or quality counts'),
    ('other', 'Other', 'Something else'),
  ];

  static const _referralSources = [
    ('friend', 'Friend or Colleague'),
    ('social', 'Social Media'),
    ('search', 'Search Engine'),
    ('appstore', 'App Store'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _otherUseCaseController.dispose();
    _otherReferralController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_selectedUseCase == null) {
      setState(() => _errorMessage = 'Please select how you plan to use Traxelos');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Determine final use case value
    final useCase = _selectedUseCase == 'other'
        ? _otherUseCaseController.text.trim().isNotEmpty
            ? _otherUseCaseController.text.trim()
            : 'Other'
        : _selectedUseCase!;

    // Determine final referral value
    String? referral;
    if (_selectedReferral != null) {
      referral = _selectedReferral == 'other'
          ? _otherReferralController.text.trim().isNotEmpty
              ? _otherReferralController.text.trim()
              : 'Other'
          : _selectedReferral;
    }

    final userRepository = sl<UserRepository>();
    final result = await userRepository.completeOnboarding(
      displayName: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : null,
      primaryUseCase: useCase,
      referralSource: referral,
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = failure.message;
        });
      },
      (_) {
        // Update auth state notifier so router allows navigation
        AuthStateNotifier.instance.updateAuthState(
          uid: AuthStateNotifier.instance.uid,
          isLoggedIn: true,
          onboardingCompleted: true,
        );
        // Navigate to main app
        context.go('/');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final secondaryBackground = AppColors.secondaryBackground(brightness);

    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // Welcome header
              Text(
                'Welcome to Traxelos!',
                style: GoogleFonts.interTight(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Let\'s personalize your experience.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: secondaryText,
                ),
              ),
              const SizedBox(height: 32),

              // Name field (optional)
              Text(
                'What should we call you?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(color: primaryText),
                decoration: InputDecoration(
                  hintText: 'Your name (optional)',
                  hintStyle: GoogleFonts.inter(color: secondaryText.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: secondaryBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 24),

              // Use case selection (required)
              Text(
                'How do you plan to use Traxelos?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 12),
              ..._useCases.map((useCase) => _buildUseCaseOption(
                    context,
                    value: useCase.$1,
                    title: useCase.$2,
                    subtitle: useCase.$3,
                    secondaryBackground: secondaryBackground,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  )),

              // Other use case text field
              if (_selectedUseCase == 'other') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _otherUseCaseController,
                  style: GoogleFonts.inter(color: primaryText),
                  decoration: InputDecoration(
                    hintText: 'Please describe your use case',
                    hintStyle: GoogleFonts.inter(color: secondaryText.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: secondaryBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Referral source (optional)
              Text(
                'How did you hear about us?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Optional',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: secondaryText.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _referralSources.map((source) => _buildReferralChip(
                      context,
                      value: source.$1,
                      label: source.$2,
                      secondaryBackground: secondaryBackground,
                      primaryText: primaryText,
                    )).toList(),
              ),

              // Other referral text field
              if (_selectedReferral == 'other') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otherReferralController,
                  style: GoogleFonts.inter(color: primaryText),
                  decoration: InputDecoration(
                    hintText: 'Please specify',
                    hintStyle: GoogleFonts.inter(color: secondaryText.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: secondaryBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isLoading ? null : _completeOnboarding,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Get Started',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Skip button
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : () => _skipOnboarding(),
                  child: Text(
                    'Skip for now',
                    style: GoogleFonts.inter(
                      color: secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUseCaseOption(
    BuildContext context, {
    required String value,
    required String title,
    required String subtitle,
    required Color secondaryBackground,
    required Color primaryText,
    required Color secondaryText,
  }) {
    final isSelected = _selectedUseCase == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedUseCase = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : secondaryText.withValues(alpha: 0.3),
                  width: 2,
                ),
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: primaryText,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralChip(
    BuildContext context, {
    required String value,
    required String label,
    required Color secondaryBackground,
    required Color primaryText,
  }) {
    final isSelected = _selectedReferral == value;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedReferral = _selectedReferral == value ? null : value;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : secondaryBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? AppColors.primary : primaryText,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _skipOnboarding() async {
    setState(() => _isLoading = true);

    final userRepository = sl<UserRepository>();
    final result = await userRepository.completeOnboarding(
      primaryUseCase: 'skipped',
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = failure.message;
        });
      },
      (_) {
        // Update auth state notifier so router allows navigation
        AuthStateNotifier.instance.updateAuthState(
          uid: AuthStateNotifier.instance.uid,
          isLoggedIn: true,
          onboardingCompleted: true,
        );
        context.go('/');
      },
    );
  }
}
