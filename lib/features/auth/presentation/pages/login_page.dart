import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_util.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/social_sign_in_button.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';

/// Login page with email/password and social sign-in options.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const String routeName = 'LoginPage';
  static const String routePath = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthBloc>(),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: BlocConsumer<AuthBloc, AuthState>(
            listener: _handleAuthStateChange,
            builder: (context, state) {
              return Container(
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.tertiary,
                    ],
                    stops: const [0.0, 1.0],
                    begin: const AlignmentDirectional(0.87, -1.0),
                    end: const AlignmentDirectional(-0.87, 1.0),
                  ),
                ),
                alignment: const AlignmentDirectional(0.0, -1.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLogo(context),
                        _buildLoginCard(context, state),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0.0, 70.0, 0.0, 32.0),
      child: Text(
        'Traxelos',
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          color: Colors.white,
          letterSpacing: 0.0,
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context, AuthState state) {
    final isLoading = state is AuthLoading;
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          maxWidth: 570.0,
        ),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground(brightness),
          boxShadow: const [
            BoxShadow(
              blurRadius: 4.0,
              color: Color(0x33000000),
              offset: Offset(0.0, 2.0),
            ),
          ],
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Align(
          alignment: const AlignmentDirectional(0.0, 0.0),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.primaryText(brightness),
                    letterSpacing: 0.0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 24.0),
                  child: Text(
                    'Fill out the information below in order to access your account.',
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.secondaryText(brightness),
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _buildEmailField(context, brightness),
                const SizedBox(height: 16),
                _buildPasswordField(context, brightness),
                const SizedBox(height: 16),
                _buildSignInButton(context, isLoading, brightness),
                _buildDivider(context, brightness),
                _buildSocialButtons(context, isLoading, brightness),
                _buildSignUpLink(context, brightness),
                _buildForgotPasswordButton(context, brightness),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField(BuildContext context, Brightness brightness) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 16.0),
      child: SizedBox(
        width: double.infinity,
        child: TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          cursorColor: AppColors.primary,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.primaryText(brightness),
            letterSpacing: 0.0,
          ),
          decoration: InputDecoration(
            labelText: 'Email',
            labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.secondaryText(brightness),
              letterSpacing: 0.0,
              fontWeight: FontWeight.w500,
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.alternate(brightness),
                width: 2.0,
              ),
              borderRadius: BorderRadius.circular(12.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2.0,
              ),
              borderRadius: BorderRadius.circular(12.0),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 2.0,
              ),
              borderRadius: BorderRadius.circular(12.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 2.0,
              ),
              borderRadius: BorderRadius.circular(12.0),
            ),
            filled: true,
            fillColor: AppColors.primaryBackground(brightness),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildPasswordField(BuildContext context, Brightness brightness) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 16.0),
      child: SizedBox(
        width: double.infinity,
        child: TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          cursorColor: AppColors.primary,
          onFieldSubmitted: (_) => _signIn(context),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.primaryText(brightness),
            letterSpacing: 0.0,
          ),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.secondaryText(brightness),
              letterSpacing: 0.0,
              fontWeight: FontWeight.w500,
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.alternate(brightness),
                width: 2.0,
              ),
              borderRadius: BorderRadius.circular(12.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2.0,
              ),
              borderRadius: BorderRadius.circular(12.0),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 2.0,
              ),
              borderRadius: BorderRadius.circular(12.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 2.0,
              ),
              borderRadius: BorderRadius.circular(12.0),
            ),
            filled: true,
            fillColor: AppColors.primaryBackground(brightness),
            suffixIcon: InkWell(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              focusNode: FocusNode(skipTraversal: true),
              child: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.secondaryText(brightness),
                size: 24.0,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildSignInButton(BuildContext context, bool isLoading, Brightness brightness) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 16.0),
      child: SizedBox(
        width: double.infinity,
        height: 44.0,
        child: ElevatedButton(
          onPressed: isLoading ? null : () => _signIn(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 3.0,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Sign In',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context, Brightness brightness) {
    return Align(
      alignment: const AlignmentDirectional(0.0, 0.0),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 24.0),
        child: Text(
          'Or sign in with',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.secondaryText(brightness),
            letterSpacing: 0.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButtons(BuildContext context, bool isLoading, Brightness brightness) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 16.0),
      child: Column(
        children: [
          SocialSignInButton(
            provider: SocialProvider.google,
            onPressed: isLoading
                ? null
                : () => context.read<AuthBloc>().add(const SignInWithGoogleEvent()),
          ),
          if (Platform.isIOS) ...[
            const SizedBox(height: 12),
            SocialSignInButton(
              provider: SocialProvider.apple,
              onPressed: isLoading
                  ? null
                  : () => context.read<AuthBloc>().add(const SignInWithAppleEvent()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignUpLink(BuildContext context, Brightness brightness) {
    return Align(
      alignment: const AlignmentDirectional(0.0, 0.0),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 12.0),
        child: InkWell(
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: () => context.push(SignupPage.routePath),
          child: RichText(
            textScaler: MediaQuery.of(context).textScaler,
            text: TextSpan(
              children: [
                TextSpan(
                  text: "Don't have an account? ",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primaryText(brightness),
                    letterSpacing: 0.0,
                  ),
                ),
                TextSpan(
                  text: 'Create Account',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordButton(BuildContext context, Brightness brightness) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
      child: SizedBox(
        width: double.infinity,
        height: 44.0,
        child: OutlinedButton(
          onPressed: () => context.push(ForgotPasswordPage.routePath),
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.primaryBackground(brightness),
            foregroundColor: AppColors.primaryText(brightness),
            elevation: 0,
            padding: EdgeInsets.zero,
            side: BorderSide(
              color: AppColors.primaryBackground(brightness),
              width: 2.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
          child: Text(
            'Forgot password?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.primaryText(brightness),
              letterSpacing: 0.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _signIn(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            SignInWithEmailEvent(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          );
    }
  }

  void _handleAuthStateChange(BuildContext context, AuthState state) {
    if (state is Authenticated) {
      // Check if user needs onboarding (new user via Google/Apple sign-in)
      if (!state.user.onboardingCompleted) {
        context.go('/onboarding');
      } else {
        // Navigate to main app (root route shows ItemsListPage)
        context.go('/');
      }
    } else if (state is AuthError) {
      showErrorSnackBar(context, state.message);
      // Clear password on error
      _passwordController.clear();
    }
  }
}
