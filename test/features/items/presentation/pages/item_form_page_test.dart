import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:trackwise/core/state/app_ui_state.dart';
import 'package:trackwise/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:trackwise/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:trackwise/features/bluetooth/presentation/bloc/bluetooth_state.dart';
import 'package:trackwise/features/items/domain/entities/item.dart';
import 'package:trackwise/features/items/presentation/bloc/items_bloc.dart';
import 'package:trackwise/features/items/presentation/bloc/items_event.dart';
import 'package:trackwise/features/items/presentation/bloc/items_state.dart';
import 'package:trackwise/features/items/presentation/pages/item_form_page.dart';

class MockItemsBloc extends MockBloc<ItemsEvent, ItemsState>
    implements ItemsBloc {}

class MockBluetoothBloc extends MockBloc<BluetoothEvent, BluetoothState>
    implements BluetoothBloc {}

class MockAppUiState extends Mock implements AppUiState {}

void main() {
  late MockItemsBloc mockItemsBloc;
  late MockBluetoothBloc mockBluetoothBloc;
  late MockAppUiState mockAppUiState;

  final testItem = Item(
    id: 'test_item_1',
    name: 'Coffee',
    count: 10,
    todayCount: 5,
    incrementBy: 1,
    reminder: ReminderType.target,
    reminderValue: 20,
    lastResetTime: DateTime(2026, 1, 4),
    lastUpdated: DateTime(2026, 1, 4),
    userId: 'user_123',
  );

  setUpAll(() {
    registerFallbackValue(CreateItemEvent(
      name: 'Test',
      incrementBy: 1,
      reminder: ReminderType.none,
      reminderValue: 0,
      userId: 'user_123',
    ));
    registerFallbackValue(UpdateItemEvent(testItem));
  });

  setUp(() {
    mockItemsBloc = MockItemsBloc();
    mockBluetoothBloc = MockBluetoothBloc();
    mockAppUiState = MockAppUiState();

    // Register mock bloc in service locator
    final sl = GetIt.instance;
    if (sl.isRegistered<ItemsBloc>()) {
      sl.unregister<ItemsBloc>();
    }
    sl.registerFactory<ItemsBloc>(() => mockItemsBloc);

    when(() => mockItemsBloc.state).thenReturn(ItemsInitial());
    when(() => mockBluetoothBloc.state).thenReturn(const BluetoothState());
    when(() => mockAppUiState.activeItemId).thenReturn('none');
  });

  tearDown(() {
    final sl = GetIt.instance;
    if (sl.isRegistered<ItemsBloc>()) {
      sl.unregister<ItemsBloc>();
    }
  });

  Widget createTestWidget({Item? item}) {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<BluetoothBloc>.value(value: mockBluetoothBloc),
        ],
        child: ChangeNotifierProvider<AppUiState>.value(
          value: mockAppUiState,
          child: ItemFormPage(item: item),
        ),
      ),
    );
  }

  group('ItemFormPage - Create Mode', () {
    testWidgets('displays app bar with Create Item title', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Create Item'), findsOneWidget);
    });

    testWidgets('displays all form fields', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Item Name'), findsOneWidget);
      expect(find.text('Increment By'), findsOneWidget);
      expect(find.text('Reminder Type'), findsOneWidget);
      expect(find.text('Reminder Value'), findsOneWidget);
    });

    testWidgets('displays Create button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('displays Cancel button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('validates empty name', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Clear the name field and submit
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('increment by field has default value of 1', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the TextFormField for increment
      final incrementField = find.widgetWithText(TextFormField, '1');
      expect(incrementField, findsOneWidget);
    });

    testWidgets('reminder value field has default value of 0', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the TextFormField for reminder value
      final reminderField = find.widgetWithText(TextFormField, '0');
      expect(reminderField, findsOneWidget);
    });

    testWidgets('displays No Reminder as default reminder type', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No Reminder'), findsOneWidget);
    });
  });

  group('ItemFormPage - Edit Mode', () {
    testWidgets('displays app bar with Edit Item title', (tester) async {
      await tester.pumpWidget(createTestWidget(item: testItem));
      await tester.pumpAndSettle();

      expect(find.text('Edit Item'), findsOneWidget);
    });

    testWidgets('displays Update button in edit mode', (tester) async {
      await tester.pumpWidget(createTestWidget(item: testItem));
      await tester.pumpAndSettle();

      expect(find.text('Update'), findsOneWidget);
    });

    testWidgets('populates form with existing item data', (tester) async {
      await tester.pumpWidget(createTestWidget(item: testItem));
      await tester.pumpAndSettle();

      // Find the name field with the item name
      expect(find.text('Coffee'), findsOneWidget);
    });

    testWidgets('displays existing increment value', (tester) async {
      await tester.pumpWidget(createTestWidget(item: testItem));
      await tester.pumpAndSettle();

      // Item has incrementBy: 1
      final incrementField = find.widgetWithText(TextFormField, '1');
      expect(incrementField, findsWidgets);
    });

    testWidgets('displays existing reminder value', (tester) async {
      await tester.pumpWidget(createTestWidget(item: testItem));
      await tester.pumpAndSettle();

      // Item has reminderValue: 20
      final reminderValueField = find.widgetWithText(TextFormField, '20');
      expect(reminderValueField, findsOneWidget);
    });
  });

  group('ItemFormPage - Validation', () {
    testWidgets('validates increment by range', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter name first
      await tester.enterText(
        find.byType(TextFormField).first,
        'Test Item',
      );

      // Find and clear the increment field, enter invalid value
      final incrementField = find.byType(TextFormField).at(1);
      await tester.enterText(incrementField, '0');

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Must be between 1 and 100'), findsOneWidget);
    });

    testWidgets('validates reminder value range', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter name first
      await tester.enterText(
        find.byType(TextFormField).first,
        'Test Item',
      );

      // Find and update the reminder value field with invalid value
      final reminderField = find.byType(TextFormField).at(2);
      await tester.enterText(reminderField, '9999');

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Must be between 0 and 1000'), findsOneWidget);
    });
  });

  group('ItemFormPage - Dropdown', () {
    testWidgets('can select different reminder types', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on the dropdown
      await tester.tap(find.text('No Reminder'));
      await tester.pumpAndSettle();

      // Select Target Count
      await tester.tap(find.text('Target Count').last);
      await tester.pumpAndSettle();

      expect(find.text('Target Count'), findsOneWidget);
    });
  });
}
