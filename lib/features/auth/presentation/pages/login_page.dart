import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
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
                    begin: const AlignmentDirectional(0.87, -1.0),
                    end: const AlignmentDirectional(-0.87, 1.0),
                  ),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 48),
                          _buildLogo(context),
                          const SizedBox(height: 48),
                          _buildLoginCard(context, state),
                        ],
                      ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.flourescent_rounded,
          color: Colors.white,
          size: 44,
        ),
        const SizedBox(width: 12),
        Text(
          'Trackwise',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontFamily: 'Urbanist',
                color: Colors.white,
                letterSpacing: 0.0,
              ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context, AuthState state) {
    final isLoading = state is AuthLoading;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome Back',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to continue tracking',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Plus Jakarta Sans',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.0,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildEmailField(context),
          const SizedBox(height: 16),
          _buildPasswordField(context),
          const SizedBox(height: 8),
          _buildForgotPasswordLink(context),
          const SizedBox(height: 24),
          _buildSignInButton(context, isLoading),
          const SizedBox(height: 16),
          _buildDivider(context),
          const SizedBox(height: 16),
          _buildSocialButtons(context, isLoading),
          const SizedBox(height: 24),
          _buildSignUpLink(context),
        ],
      ),
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'Enter your email',
        prefixIcon: const Icon(Icons.email_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _signIn(context),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        return null;
      },
    );
  }

  Widget _buildForgotPasswordLink(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => context.push(ForgotPasswordPage.routePath),
        child: Text(
          'Forgot Password?',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'Plus Jakarta Sans',
                color: AppColors.primary,
                letterSpacing: 0.0,
              ),
        ),
      ),
    );
  }

  Widget _buildSignInButton(BuildContext context, bool isLoading) {
    return ElevatedButton(
      onPressed: isLoading ? null : () => _signIn(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
          : const Text(
              'Sign In',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
      ],
    );
  }

  Widget _buildSocialButtons(BuildContext context, bool isLoading) {
    return Column(
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
    );
  }

  Widget _buildSignUpLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        TextButton(
          onPressed: () => context.push(SignupPage.routePath),
          child: Text(
            'Sign Up',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Plus Jakarta Sans',
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.0,
                ),
          ),
        ),
      ],
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
      // Navigate to main app
      context.go('/items');
    } else if (state is AuthError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: AppColors.error,
        ),
      );
      // Clear password on error
      _passwordController.clear();
    }
  }
}
