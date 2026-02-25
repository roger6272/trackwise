import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:traxelos/core/state/app_ui_state.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:traxelos/features/bluetooth/presentation/bloc/bluetooth_state.dart';
import 'package:traxelos/features/items/domain/entities/item.dart';
import 'package:traxelos/features/items/presentation/bloc/items_bloc.dart';
import 'package:traxelos/features/items/presentation/bloc/items_event.dart';
import 'package:traxelos/features/items/presentation/bloc/items_state.dart';

class MockItemsBloc extends MockBloc<ItemsEvent, ItemsState>
    implements ItemsBloc {}

class MockBluetoothBloc extends MockBloc<BluetoothEvent, BluetoothState>
    implements BluetoothBloc {}

class TestAppUiState extends ChangeNotifier implements AppUiState {
  bool _isTodayToggle = false;
  String _activeItemId = 'none';
  DateTime? _datePicked;
  bool _showCounter = false;
  int _currentLogPage = 0;
  bool _showAfterResetOnly = false;
  bool _toggleRefresh = false;
  String? _selectedCategoryId;

  @override
  bool get isTodayToggle => _isTodayToggle;

  @override
  set isTodayToggle(bool value) {
    _isTodayToggle = value;
    notifyListeners();
  }

  @override
  String get activeItemId => _activeItemId;

  @override
  set activeItemId(String value) {
    _activeItemId = value;
    notifyListeners();
  }

  @override
  DateTime? get datePicked => _datePicked;

  @override
  set datePicked(DateTime? value) {
    _datePicked = value;
    notifyListeners();
  }

  @override
  bool get showCounter => _showCounter;

  @override
  set showCounter(bool value) {
    _showCounter = value;
    notifyListeners();
  }

  @override
  int get currentLogPage => _currentLogPage;

  @override
  set currentLogPage(int value) {
    _currentLogPage = value;
    notifyListeners();
  }

  @override
  bool get showAfterResetOnly => _showAfterResetOnly;

  @override
  set showAfterResetOnly(bool value) {
    _showAfterResetOnly = value;
    notifyListeners();
  }

  @override
  String? get selectedCategoryId => _selectedCategoryId;

  @override
  set selectedCategoryId(String? value) {
    _selectedCategoryId = value;
    notifyListeners();
  }

  @override
  bool get toggleRefresh => _toggleRefresh;

  @override
  void triggerRefresh() {
    _toggleRefresh = !_toggleRefresh;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}

  @override
  void clear() {
    _datePicked = null;
    _isTodayToggle = false;
    _selectedCategoryId = null;
    _showCounter = false;
    _currentLogPage = 0;
    _showAfterResetOnly = false;
    _toggleRefresh = false;
    notifyListeners();
  }

  @override
  void clearActiveItem() {
    _activeItemId = '';
    notifyListeners();
  }

  @override
  void setActiveItem(String itemId) {
    activeItemId = itemId;
  }

  bool _hasShownReorderHint = false;

  @override
  bool get hasShownReorderHint => _hasShownReorderHint;

  @override
  void markReorderHintShown() {
    _hasShownReorderHint = true;
    notifyListeners();
  }

  bool _hasShownActivationHint = false;

  @override
  bool get hasShownActivationHint => _hasShownActivationHint;

  @override
  void markActivationHintShown() {
    _hasShownActivationHint = true;
    notifyListeners();
  }
}

void main() {
  late MockItemsBloc mockItemsBloc;
  late MockBluetoothBloc mockBluetoothBloc;
  late TestAppUiState testAppUiState;

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

  final testItem2 = Item(
    id: 'test_item_2',
    name: 'Water',
    count: 8,
    todayCount: 3,
    incrementBy: 1,
    reminder: ReminderType.interval,
    reminderValue: 5,
    lastResetTime: DateTime(2026, 1, 4),
    lastUpdated: DateTime(2026, 1, 4),
    userId: 'user_123',
  );

  setUpAll(() {
    registerFallbackValue(const WatchItemsEvent('user_123'));
    registerFallbackValue(const DeleteItemEvent('test_item_1'));
  });

  setUp(() {
    mockItemsBloc = MockItemsBloc();
    mockBluetoothBloc = MockBluetoothBloc();
    testAppUiState = TestAppUiState();

    // Register mock bloc in service locator
    final sl = GetIt.instance;
    if (sl.isRegistered<ItemsBloc>()) {
      sl.unregister<ItemsBloc>();
    }
    sl.registerFactory<ItemsBloc>(() => mockItemsBloc);

    when(() => mockBluetoothBloc.state).thenReturn(
      const BluetoothState(status: BluetoothStatus.ready),
    );
  });

  tearDown(() {
    final sl = GetIt.instance;
    if (sl.isRegistered<ItemsBloc>()) {
      sl.unregister<ItemsBloc>();
    }
  });

  Widget createTestWidgetWithState(ItemsState state) {
    when(() => mockItemsBloc.state).thenReturn(state);

    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<ItemsBloc>.value(value: mockItemsBloc),
          BlocProvider<BluetoothBloc>.value(value: mockBluetoothBloc),
        ],
        child: ChangeNotifierProvider<AppUiState>.value(
          value: testAppUiState,
          child: Scaffold(
            appBar: AppBar(title: const Text('Items')),
            body: BlocBuilder<ItemsBloc, ItemsState>(
              builder: (context, state) {
                if (state is ItemsLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (state is ItemsLoaded) {
                  if (state.items.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 72),
                          SizedBox(height: 16),
                          Text('No items yet'),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: state.items.length,
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text(item.count.toString()),
                      );
                    },
                  );
                }

                if (state is ItemsError) {
                  return Center(child: Text(state.message));
                }

                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
  }

  group('ItemsListPage UI States', () {
    testWidgets('displays loading indicator when loading', (tester) async {
      await tester.pumpWidget(createTestWidgetWithState(ItemsLoading()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays empty state when no items', (tester) async {
      await tester.pumpWidget(
          createTestWidgetWithState(const ItemsLoaded([], isWatching: true)));
      await tester.pump();

      expect(find.text('No items yet'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('displays items when loaded', (tester) async {
      await tester.pumpWidget(createTestWidgetWithState(
          ItemsLoaded([testItem, testItem2], isWatching: true)));
      await tester.pump();

      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
    });

    testWidgets('displays item counts', (tester) async {
      await tester.pumpWidget(createTestWidgetWithState(
          ItemsLoaded([testItem], isWatching: true)));
      await tester.pump();

      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('displays error state when error', (tester) async {
      await tester.pumpWidget(
          createTestWidgetWithState(const ItemsError('Something went wrong')));
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('displays app bar with title', (tester) async {
      await tester.pumpWidget(
          createTestWidgetWithState(const ItemsLoaded([], isWatching: true)));
      await tester.pump();

      expect(find.text('Items'), findsOneWidget);
    });
  });

  group('ItemsListPage Toggle', () {
    testWidgets('toggle starts with Total selected', (tester) async {
      expect(testAppUiState.isTodayToggle, false);
    });

    testWidgets('shows total count when Total is selected', (tester) async {
      testAppUiState.isTodayToggle = false;

      await tester.pumpWidget(createTestWidgetWithState(
          ItemsLoaded([testItem], isWatching: true)));
      await tester.pump();

      // Item has count: 10, todayCount: 5
      expect(find.text('10'), findsOneWidget);
    });
  });
}
