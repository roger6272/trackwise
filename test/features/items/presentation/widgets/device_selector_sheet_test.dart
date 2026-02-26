import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/features/items/presentation/widgets/device_selector_sheet.dart';

void main() {
  testWidgets('shows device names and calls onDeviceSelected', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DeviceSelectorSheet(
          devices: [
            (instanceId: 'dev1', name: 'Office'),
            (instanceId: 'dev2', name: 'Home'),
          ],
          onDeviceSelected: (id) {
            selected = id;
          },
        ),
      ),
    ));
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    await tester.tap(find.text('Office'));
    expect(selected, 'dev1');
  });

  testWidgets('shows Select Device title', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DeviceSelectorSheet(
          devices: [(instanceId: 'dev1', name: 'Test')],
          onDeviceSelected: (_) {},
        ),
      ),
    ));
    expect(find.text('Select Device'), findsOneWidget);
  });
}
