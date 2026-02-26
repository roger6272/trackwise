import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/features/items/presentation/widgets/unlock_confirm_dialog.dart';

void main() {
  testWidgets('online: shows names, no break-glass warning', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => showUnlockConfirmDialog(
            context: ctx,
            itemName: 'Push-ups',
            deviceName: 'Office',
            isBreakGlass: false,
          ),
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Push-ups'), findsOneWidget);
    expect(find.textContaining('Office'), findsOneWidget);
    expect(find.textContaining('discarded'), findsNothing);
  });

  testWidgets('offline: shows break-glass warning', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => showUnlockConfirmDialog(
            context: ctx,
            itemName: 'Push-ups',
            deviceName: 'Home',
            isBreakGlass: true,
          ),
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('discarded'), findsOneWidget);
  });

  testWidgets('returns true on Release', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            result = await showUnlockConfirmDialog(
              context: ctx,
              itemName: 'X',
              deviceName: 'D',
              isBreakGlass: false,
            );
          },
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Release'));
    await tester.pumpAndSettle();
    expect(result, true);
  });

  testWidgets('returns false on Cancel', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            result = await showUnlockConfirmDialog(
              context: ctx,
              itemName: 'X',
              deviceName: 'D',
              isBreakGlass: false,
            );
          },
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, false);
  });
}
