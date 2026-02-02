import 'package:flutter/material.dart';

class BleStatusBanner extends StatelessWidget {
  final String message;
  final Color color;
  final Widget? action;

  const BleStatusBanner({
    super.key,
    required this.message,
    required this.color,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: color,
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
