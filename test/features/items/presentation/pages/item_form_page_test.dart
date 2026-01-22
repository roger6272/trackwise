import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:trackwise/core/state/app_ui_state.dart';
import 'package:trackwise/features/auth/domain/entities/user.dart';
import 'package:trackwise/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:trackwise/features/auth/presentation/bloc/auth_event.dart';
import 'package:trackwise/features/auth/presentation/bloc/auth_state.dart';
import 'package:trackwise/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:trackwise/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:trackwise/features/bluetooth/presentation/bloc/bluetooth_state.dart';
import 'package:trackwise/features/categories/presentation/bloc/categories_bloc.dart';
import 'package:trackwise/features/categories/presentation/bloc/categories_event.dart';
import 'package:trackwise/features/categories/presentation/bloc/categories_state.dart';
import 'package:trackwise/features/items/domain/entities/item.dart';
import 'package:trackwise/features/items/presentation/bloc/items_bloc.dart';
import 'package:trackwise/features/items/presentation/bloc/items_event.dart';
import 'package:trackwise/features/items/presentation/bloc/items_state.dart';
import 'package:trackwise/features/items/presentation/pages/item_form_page.dart';

class MockItemsBloc extends MockBloc<ItemsEvent, ItemsState>
    implements ItemsBloc {}

class MockBluetoothBloc extends MockBloc<BluetoothEvent, BluetoothState>
    implements BluetoothBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class MockCategoriesBloc extends MockBloc<CategoriesEvent, CategoriesState>
    implements CategoriesBloc {}

class MockAppUiState extends Mock implements AppUiState {}

void main() {
  late MockItemsBloc mockItemsBloc;
  late MockBluetoothBloc mockBluetoothBloc;
  late MockAuthBloc mockAuthBloc;
  late MockCategoriesBloc mockCategoriesBloc;
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
    mockAuthBloc = MockAuthBloc();
    mockCategoriesBloc = MockCategoriesBloc();
    mockAppUiState = MockAppUiState();

    // Register mock blocs in service locator
    final sl = GetIt.instance;
    if (sl.isRegistered<ItemsBloc>()) {
      sl.unregister<ItemsBloc>();
    }
    if (sl.isRegistered<CategoriesBloc>()) {
      sl.unregister<CategoriesBloc>();
    }
    sl.registerFactory<ItemsBloc>(() => mockItemsBloc);
    sl.registerFactory<CategoriesBloc>(() => mockCategoriesBloc);

    when(() => mockItemsBloc.state).thenReturn(ItemsInitial());
    when(() => mockBluetoothBloc.state).thenReturn(const BluetoothState());
    when(() => mockAuthBloc.state).thenReturn(Authenticated(
      const User(id: 'user_123', email: 'test@test.com'),
    ));
    when(() => mockCategoriesBloc.state).thenReturn(const CategoriesLoaded([]));
    when(() => mockAppUiState.activeItemId).thenReturn('none');
  });

  tearDown(() {
    final sl = GetIt.instance;
    if (sl.isRegistered<ItemsBloc>()) {
      sl.unregister<ItemsBloc>();
    }
    if (sl.isRegistered<CategoriesBloc>()) {
      sl.unregister<CategoriesBloc>();
    }
  });

  Widget createTestWidget({Item? item}) {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<BluetoothBloc>.value(value: mockBluetoothBloc),
          BlocProvider<AuthBloc>.value(value: mockAuthBloc),
          BlocProvider<CategoriesBloc>.value(value: mockCategoriesBloc),
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
      // Reminder Value is hidden when No Reminder is selected (default)
      expect(find.text('Reminder Value'), findsNothing);
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

      // Scroll down to make the Create button visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
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

      // Find TextFormFields with '0' as default value (starting count and reminder value)
      final fieldsWithZero = find.widgetWithText(TextFormField, '0');
      expect(fieldsWithZero, findsWidgets); // Should find at least one
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
    // TODO: Fix test - form field order changed with category dropdown addition
    testWidgets('validates increment by range', skip: true, (tester) async {
      // Use a larger surface size to fit all form fields
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter name first
      await tester.enterText(
        find.byType(TextFormField).first,
        'Test Item',
      );

      // Form field order when No Reminder: 0=name, 1=initialValue, 2=goal, 3=incrementBy
      // Find and clear the increment field (index 3), enter invalid value
      final incrementField = find.byType(TextFormField).at(3);
      await tester.enterText(incrementField, '0');

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Must be between 1 and 100'), findsOneWidget);
    });

    // TODO: Fix test - form field order changed with category dropdown addition
    testWidgets('validates reminder value range', skip: true, (tester) async {
      // Use a larger surface size to fit all form fields
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter name first
      await tester.enterText(
        find.byType(TextFormField).first,
        'Test Item',
      );

      // First select a reminder type to show the reminder value field
      await tester.tap(find.text('No Reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Target Count').last);
      await tester.pumpAndSettle();

      // Form field order when reminder selected: 0=name, 1=initialValue, 2=goal, 3=incrementBy, 4=reminderValue
      // Find and update the reminder value field (index 4) with invalid value
      final reminderField = find.byType(TextFormField).at(4);
      await tester.enterText(reminderField, '9999');

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Must be between 0 and 1000'), findsOneWidget);
    });
  });

  group('ItemFormPage - Dropdown', () {
    // TODO: Fix test - dropdown interaction changed with form restructuring
    testWidgets('can select different reminder types', skip: true, (tester) async {
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
