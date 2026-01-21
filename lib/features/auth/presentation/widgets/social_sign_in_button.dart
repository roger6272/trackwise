import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final isGoogle = provider == SocialProvider.google;

    return SizedBox(
      width: double.infinity,
      height: 48.0,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: isGoogle ? const Color(0xFF1F1F1F) : Colors.white,
          backgroundColor: isGoogle ? Colors.white : Colors.black,
          elevation: isGoogle ? 1.0 : 0.0,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(
              color: isGoogle ? const Color(0xFFDADCE0) : Colors.black,
              width: 1.0,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIcon(),
            const SizedBox(width: 12.0),
            Text(
              _label,
              style: GoogleFonts.inter(
                fontSize: 15.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (provider) {
      case SocialProvider.google:
        // Official Google "G" colors
        return SizedBox(
          width: 20.0,
          height: 20.0,
          child: CustomPaint(
            painter: _GoogleLogoPainter(),
          ),
        );
      case SocialProvider.apple:
        return const Icon(Icons.apple, size: 22.0);
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
}

/// Paints the official Google "G" logo with correct colors.
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Scale factor based on original 24x24 design
    final double scale = width / 24.0;

    // Blue part (right side of G)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final bluePath = Path()
      ..moveTo(23.52 * scale, 12.27 * scale)
      ..cubicTo(23.52 * scale, 11.48 * scale, 23.45 * scale, 10.72 * scale, 23.32 * scale, 10.0 * scale)
      ..lineTo(12.0 * scale, 10.0 * scale)
      ..lineTo(12.0 * scale, 14.26 * scale)
      ..lineTo(18.47 * scale, 14.26 * scale)
      ..cubicTo(18.2 * scale, 15.63 * scale, 17.4 * scale, 16.79 * scale, 16.22 * scale, 17.56 * scale)
      ..lineTo(16.22 * scale, 20.34 * scale)
      ..lineTo(20.04 * scale, 20.34 * scale)
      ..cubicTo(22.24 * scale, 18.34 * scale, 23.52 * scale, 15.52 * scale, 23.52 * scale, 12.27 * scale)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green part (bottom right)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;

    final greenPath = Path()
      ..moveTo(12.0 * scale, 24.0 * scale)
      ..cubicTo(15.03 * scale, 24.0 * scale, 17.59 * scale, 23.02 * scale, 19.51 * scale, 21.35 * scale)
      ..lineTo(16.22 * scale, 17.56 * scale)
      ..cubicTo(15.22 * scale, 18.23 * scale, 13.94 * scale, 18.63 * scale, 12.0 * scale, 18.63 * scale)
      ..cubicTo(9.08 * scale, 18.63 * scale, 6.61 * scale, 16.61 * scale, 5.76 * scale, 13.94 * scale)
      ..lineTo(1.85 * scale, 13.94 * scale)
      ..lineTo(1.85 * scale, 16.81 * scale)
      ..cubicTo(3.81 * scale, 20.8 * scale, 7.65 * scale, 24.0 * scale, 12.0 * scale, 24.0 * scale)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow part (bottom left)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;

    final yellowPath = Path()
      ..moveTo(5.76 * scale, 13.94 * scale)
      ..cubicTo(5.52 * scale, 13.27 * scale, 5.38 * scale, 12.55 * scale, 5.38 * scale, 11.81 * scale)
      ..cubicTo(5.38 * scale, 11.07 * scale, 5.52 * scale, 10.35 * scale, 5.76 * scale, 9.68 * scale)
      ..lineTo(5.76 * scale, 6.81 * scale)
      ..lineTo(1.85 * scale, 6.81 * scale)
      ..cubicTo(0.95 * scale, 8.55 * scale, 0.48 * scale, 10.48 * scale, 0.48 * scale, 12.0 * scale)
      ..cubicTo(0.48 * scale, 13.52 * scale, 0.95 * scale, 15.45 * scale, 1.85 * scale, 17.19 * scale)
      ..lineTo(5.76 * scale, 13.94 * scale)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red part (top left)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;

    final redPath = Path()
      ..moveTo(12.0 * scale, 5.38 * scale)
      ..cubicTo(13.94 * scale, 5.38 * scale, 15.68 * scale, 6.05 * scale, 17.04 * scale, 7.35 * scale)
      ..lineTo(20.13 * scale, 4.26 * scale)
      ..cubicTo(17.95 * scale, 2.19 * scale, 15.03 * scale, 0.91 * scale, 12.0 * scale, 0.91 * scale)
      ..cubicTo(7.65 * scale, 0.91 * scale, 3.81 * scale, 4.11 * scale, 1.85 * scale, 8.1 * scale)
      ..lineTo(5.76 * scale, 10.97 * scale)
      ..cubicTo(6.61 * scale, 8.3 * scale, 9.08 * scale, 5.38 * scale, 12.0 * scale, 5.38 * scale)
      ..close();
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
