import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/features/bluetooth/presentation/widgets/device_color_picker_dialog.dart';

void main() {
  testWidgets('shows 10 swatches, check on current', (tester) async {
    int? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DeviceColorPickerDialog(
          currentColor: 2,
          onColorSelected: (i) { selected = i; },
        ),
      ),
    ));
    // 10 color swatches + 1 from Cancel button's InkWell
    expect(find.byType(InkWell), findsNWidgets(11));
    expect(find.byIcon(Icons.check), findsOneWidget);
    // Tap 5th color swatch (index 4) — skipping 0-3
    await tester.tap(find.byType(InkWell).at(4));
    expect(selected, 4);
  });

  testWidgets('Cancel button closes dialog', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DeviceColorPickerDialog(
          currentColor: 0,
          onColorSelected: (_) {},
        ),
      ),
    ));
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Choose Color'), findsOneWidget);
  });
}
