import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../flutter_flow/flutter_flow_theme.dart';

/// Social sign-in provider options.
enum SocialProvider { google, apple }

/// Button for social sign-in (Google, Apple).
class SocialSignInButton extends StatelessWidget {
  final SocialProvider provider;
  final VoidCallback? onPressed;

  const SocialSignInButton({
    super.key,
    required this.provider,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: _buildIcon(),
      label: Text(_label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _foregroundColor(context),
        backgroundColor: _backgroundColor(context),
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: FlutterFlowTheme.of(context).alternate),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (provider) {
      case SocialProvider.google:
        return const FaIcon(FontAwesomeIcons.google, size: 20);
      case SocialProvider.apple:
        return const FaIcon(FontAwesomeIcons.apple, size: 20);
    }
  }

  String get _label {
    switch (provider) {
      case SocialProvider.google:
        return 'Continue with Google';
      case SocialProvider.apple:
        return 'Continue with Apple';
    }
  }

  Color _foregroundColor(BuildContext context) {
    switch (provider) {
      case SocialProvider.google:
        return FlutterFlowTheme.of(context).primaryText;
      case SocialProvider.apple:
        return FlutterFlowTheme.of(context).primaryText;
    }
  }

  Color _backgroundColor(BuildContext context) {
    return FlutterFlowTheme.of(context).secondaryBackground;
  }
}
