import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class DeviceColorPickerDialog extends StatelessWidget {
  final int currentColor;
  final ValueChanged<int> onColorSelected;

  const DeviceColorPickerDialog({
    super.key,
    required this.currentColor,
    required this.onColorSelected,
  });

  static const _colorNames = [
    'Blue', 'Green', 'Orange', 'Purple', 'Red',
    'Teal', 'Pink', 'Amber', 'Indigo', 'Brown',
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AlertDialog(
      backgroundColor: AppColors.secondaryBackground(brightness),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Choose Color', style: TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.primaryText(brightness),
      )),
      content: SizedBox(
        width: 280,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, mainAxisSpacing: 12, crossAxisSpacing: 12),
          itemCount: 10,
          itemBuilder: (ctx, i) => Semantics(
            label: _colorNames[i],
            child: InkWell(
              onTap: () => onColorSelected(i),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.deviceColor(i, brightness),
                  shape: BoxShape.circle,
                  border: i == currentColor
                      ? Border.all(color: AppColors.primaryText(brightness), width: 3)
                      : null,
                ),
                child: i == currentColor
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(
            color: AppColors.secondaryText(brightness),
          )),
        ),
      ],
    );
  }
}
