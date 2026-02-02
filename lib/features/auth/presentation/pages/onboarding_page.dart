import 'package:flutter/material.dart';

import '../../../../core/auth/auth_state_notifier.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_util.dart';
import '../../domain/repositories/user_repository.dart';
import '../widgets/onboarding_step_create_item.dart';
import '../widgets/onboarding_step_device.dart';
import '../widgets/onboarding_step_done.dart';
import '../widgets/onboarding_step_intro.dart';
import '../widgets/onboarding_step_profile.dart';

/// Multi-step onboarding wizard shown to new users after signup.
///
/// 5-step PageView flow:
/// 1. User Profile & Preferences (name, use case, referral)
/// 2. Product Introduction (static content)
/// 3. Device Scan & Connect (BLE pairing via BluetoothBloc)
/// 4. Create First Item (simplified item form)
/// 5. Done (conditional — only if steps 3+4 both completed)
///
/// Each step is a separate widget. This page manages the PageView,
/// progress indicator, navigation, and completion logic.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  static const String routeName = 'OnboardingPage';
  static const String routePath = '/onboarding';

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();

  // Current step (0-indexed internally, displayed as 1-5)
  int _currentStep = 0;

  // Loading state for completion calls
  bool _isLoading = false;

  // --- Step 1 state: User Profile ---
  String? selectedUseCase;
  String? selectedReferral;
  String nameText = '';
  String otherUseCaseText = '';
  String otherReferralText = '';

  // --- Step 3 state: Device Pairing ---
  bool devicePaired = false;
  String? pairedDeviceName;

  // --- Step 4 state: Item Creation ---
  bool itemCreated = false;
  String? createdItemName;

  static const _totalSteps = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- Navigation ---

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _goToStep(_currentStep + 1);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  // --- Completion ---

  /// Complete onboarding via any exit path (skip or full completion).
  Future<void> _finishOnboarding() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    // Determine final use case value
    final useCase = _resolveUseCase();

    // Determine final referral value
    final referral = _resolveReferral();

    final userRepository = sl<UserRepository>();
    final result = await userRepository.completeOnboarding(
      displayName: nameText.isNotEmpty ? nameText : null,
      primaryUseCase: useCase,
      referralSource: referral,
      onboardingDevicePaired: devicePaired,
      onboardingItemCreated: itemCreated,
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isLoading = false);
        showErrorSnackBar(context, failure.message);
      },
      (_) {
        // Trigger router redirect to home
        AuthStateNotifier.instance.updateAuthState(
          uid: AuthStateNotifier.instance.uid,
          isLoggedIn: true,
          onboardingCompleted: true,
        );
      },
    );
  }

  String _resolveUseCase() {
    if (selectedUseCase == null) return 'skipped';
    if (selectedUseCase == 'other') {
      return otherUseCaseText.isNotEmpty ? otherUseCaseText : 'Other';
    }
    return selectedUseCase!;
  }

  String? _resolveReferral() {
    if (selectedReferral == null) return null;
    if (selectedReferral == 'other') {
      return otherReferralText.isNotEmpty ? otherReferralText : 'Other';
    }
    return selectedReferral;
  }

  /// Called when Step 3 (device pairing) completes or is skipped.
  void onDevicePairingComplete({required bool paired, String? deviceName}) {
    setState(() {
      devicePaired = paired;
      pairedDeviceName = deviceName;
    });

    if (!paired) {
      // Skipped pairing — also skip item creation, finish onboarding
      _finishOnboarding();
    } else {
      _nextStep(); // Go to Step 4
    }
  }

  /// Called when Step 4 (item creation) completes or is skipped.
  void onItemCreationComplete({required bool created, String? itemName}) {
    setState(() {
      itemCreated = created;
      createdItemName = itemName;
    });

    if (!created || !devicePaired) {
      // Skipped or no device — finish onboarding (no Done screen)
      _finishOnboarding();
    } else {
      // Both complete — show Done screen (Step 5)
      _nextStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);

    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: back button + progress dots
            _buildTopBar(context, primaryText),
            // Step content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  OnboardingStepProfile(
                    selectedUseCase: selectedUseCase,
                    selectedReferral: selectedReferral,
                    nameText: nameText,
                    otherUseCaseText: otherUseCaseText,
                    otherReferralText: otherReferralText,
                    onUseCaseChanged: (value) =>
                        setState(() => selectedUseCase = value),
                    onReferralChanged: (value) =>
                        setState(() => selectedReferral = value),
                    onNameChanged: (value) =>
                        setState(() => nameText = value),
                    onOtherUseCaseChanged: (value) =>
                        setState(() => otherUseCaseText = value),
                    onOtherReferralChanged: (value) =>
                        setState(() => otherReferralText = value),
                  ),
                  const OnboardingStepIntro(),
                  OnboardingStepDevice(
                    onPairingComplete: ({required paired, deviceName}) {
                      onDevicePairingComplete(
                        paired: paired,
                        deviceName: deviceName,
                      );
                    },
                  ),
                  OnboardingStepCreateItem(
                    selectedUseCase: selectedUseCase,
                    onItemCreated: ({required created, itemName}) {
                      onItemCreationComplete(
                        created: created,
                        itemName: itemName,
                      );
                    },
                  ),
                  OnboardingStepDone(
                    deviceName: pairedDeviceName,
                    itemName: createdItemName,
                  ),
                ],
              ),
            ),
            // Bottom actions
            _buildBottomActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Color primaryText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Back button (Steps 2-4 only)
          if (_currentStep >= 1 && _currentStep <= 3)
            IconButton(
              tooltip: 'Back',
              icon: Icon(Icons.arrow_back, color: primaryText),
              onPressed: _isLoading ? null : _previousStep,
            )
          else
            const SizedBox(width: 48), // Spacer to keep dots centered
          // Progress dots
          Expanded(child: _buildProgressDots(context)),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildProgressDots(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalSteps, (index) {
        final isActive = index <= _currentStep;
        final isCurrent = index == _currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isCurrent ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary action button (hidden on Step 3 — BLE step handles its own flow,
          // and Step 4 — create item step has its own Create button)
          if (_currentStep != 2 && _currentStep != 3)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isLoading ? null : _onPrimaryAction,
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
                        _primaryButtonLabel,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          // Skip option (Steps 1, 3, 4 only)
          if (_showSkip) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isLoading ? null : _onSkip,
              child: Text(
                _skipLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: secondaryText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Button logic per step ---

  String get _primaryButtonLabel {
    switch (_currentStep) {
      case 0:
        return 'Continue';
      case 1:
        return 'Continue';
      case 2:
        return 'Continue'; // Placeholder — Step 3 will handle its own actions
      case 3:
        return 'Continue'; // Placeholder — Step 4 will handle its own actions
      case 4:
        return 'Get Started';
      default:
        return 'Continue';
    }
  }

  bool get _showSkip {
    // Steps 1, 3, 4 have skip options. Step 2 (intro) and Step 5 (done) do not.
    return _currentStep == 0 || _currentStep == 2 || _currentStep == 3;
  }

  String get _skipLabel {
    switch (_currentStep) {
      case 0:
        return 'Skip for now';
      case 2:
        return "I don't have a device yet";
      case 3:
        return 'Skip';
      default:
        return 'Skip';
    }
  }

  void _onPrimaryAction() {
    switch (_currentStep) {
      case 0: // Step 1: validate and continue
        _nextStep();
        break;
      case 1: // Step 2: continue
        _nextStep();
        break;
      case 2: // Step 3: placeholder — will be wired to BLE connect
        _nextStep();
        break;
      case 3: // Step 4: placeholder — will be wired to item creation
        _nextStep();
        break;
      case 4: // Step 5: Done — finish onboarding
        _finishOnboarding();
        break;
    }
  }

  void _onSkip() {
    switch (_currentStep) {
      case 0: // Skip profile — set use case to skipped, advance
        setState(() => selectedUseCase = null);
        _nextStep();
        break;
      case 2: // Skip pairing — finish onboarding
        onDevicePairingComplete(paired: false);
        break;
      case 3: // Skip item creation — finish onboarding
        onItemCreationComplete(created: false);
        break;
    }
  }
}
