import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widget displaying summary statistics cards with slide/fade animations.
///
/// Shows Current Count and Average values in two side-by-side cards
/// that animate in when the widget is first displayed.
class SummaryCards extends StatefulWidget {
  const SummaryCards({
    super.key,
    required this.currentCount,
    required this.average,
  });

  final int currentCount;
  final double average;

  @override
  State<SummaryCards> createState() => _SummaryCardsState();
}

class _SummaryCardsState extends State<SummaryCards>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: _SummaryCard(
                value: widget.currentCount.toString(),
                label: 'Current Count',
                width: MediaQuery.sizeOf(context).width * 0.42,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: _SummaryCard(
                value: widget.average.toStringAsFixed(1),
                label: 'Average',
                width: MediaQuery.sizeOf(context).width * 0.42,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.value,
    required this.label,
    required this.width,
  });

  final String value;
  final String label;
  final double width;

  static const Color _alternate = Color(0xFFE0E3E7);
  static const Color _secondaryBackground = Color(0xFFFFFFFF);
  static const Color _primaryText = Color(0xFF14181B);
  static const Color _secondaryText = Color(0xFF57636C);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 80.0,
      decoration: BoxDecoration(
        color: _secondaryBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: _alternate,
          width: 0.0,
        ),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0.0, 4.0, 0.0, 2.0),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: GoogleFonts.interTight(
                fontSize: 20.0,
                fontWeight: FontWeight.w600,
                color: _primaryText,
              ),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.0,
              color: _secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
