import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/features/auth/domain/entities/user.dart';
import 'package:traxelos/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:traxelos/features/auth/presentation/bloc/auth_event.dart';
import 'package:traxelos/features/auth/presentation/bloc/auth_state.dart';
import 'package:traxelos/features/categories/domain/entities/category.dart';
import 'package:traxelos/features/categories/domain/repositories/category_repository.dart';
import 'package:traxelos/features/export/domain/entities/csv_export_config.dart';
import 'package:traxelos/features/export/presentation/bloc/export_bloc.dart';
import 'package:traxelos/features/export/presentation/bloc/export_event.dart';
import 'package:traxelos/features/export/presentation/bloc/export_state.dart';
import 'package:traxelos/features/export/presentation/pages/export_page.dart';
import 'package:traxelos/features/items/domain/entities/item.dart';
import 'package:traxelos/features/items/domain/repositories/item_repository.dart';

class MockExportBloc extends MockBloc<ExportEvent, ExportState>
    implements ExportBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  late MockExportBloc mockExportBloc;
  late MockAuthBloc mockAuthBloc;
  late MockItemRepository mockItemRepository;
  late MockCategoryRepository mockCategoryRepository;

  setUpAll(() {
    registerFallbackValue(ExportCSV(
      startDate: DateTime.now(),
      endDate: DateTime.now(),
      aggregationLevel: ExportAggregationLevel.daily,
      email: 'test@example.com',
    ));
  });

  setUp(() {
    mockExportBloc = MockExportBloc();
    mockAuthBloc = MockAuthBloc();
    mockItemRepository = MockItemRepository();
    mockCategoryRepository = MockCategoryRepository();

    // Register mocks in service locator
    final sl = GetIt.instance;
    if (sl.isRegistered<ExportBloc>()) {
      sl.unregister<ExportBloc>();
    }
    if (sl.isRegistered<ItemRepository>()) {
      sl.unregister<ItemRepository>();
    }
    if (sl.isRegistered<CategoryRepository>()) {
      sl.unregister<CategoryRepository>();
    }
    sl.registerFactory<ExportBloc>(() => mockExportBloc);
    sl.registerFactory<ItemRepository>(() => mockItemRepository);
    sl.registerFactory<CategoryRepository>(() => mockCategoryRepository);

    when(() => mockExportBloc.state).thenReturn(const ExportInitial());
    when(() => mockAuthBloc.state).thenReturn(
      const Authenticated(User(id: 'user_1', email: 'test@test.com')),
    );
    when(() => mockItemRepository.getItems(any())).thenAnswer(
      (_) async => Right([
        Item(
          id: 'item_1',
          name: 'Coffee',
          categoryId: 'cat_1',
          userId: 'user_1',
          count: 0,
          todayCount: 0,
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          lastUpdated: DateTime.now(),
          order: 0,
        ),
        Item(
          id: 'item_2',
          name: 'Tea',
          categoryId: 'cat_1',
          userId: 'user_1',
          count: 0,
          todayCount: 0,
          incrementBy: 1,
          reminder: ReminderType.none,
          reminderValue: 0,
          lastUpdated: DateTime.now(),
          order: 1,
        ),
      ]),
    );
    when(() => mockCategoryRepository.getCategories(any())).thenAnswer(
      (_) async => Right([
        Category(
          id: 'cat_1',
          name: 'Drinks',
          userId: 'user_1',
          order: 0,
          createdAt: DateTime.now(),
          lastUpdated: DateTime.now(),
        ),
      ]),
    );
  });

  tearDown(() {
    final sl = GetIt.instance;
    if (sl.isRegistered<ExportBloc>()) {
      sl.unregister<ExportBloc>();
    }
    if (sl.isRegistered<ItemRepository>()) {
      sl.unregister<ItemRepository>();
    }
    if (sl.isRegistered<CategoryRepository>()) {
      sl.unregister<CategoryRepository>();
    }
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: mockAuthBloc,
        child: const ExportPage(),
      ),
    );
  }

  group('ExportPage', () {
    testWidgets('renders scaffold', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays date range section', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Date Range'), findsOneWidget);
    });

    testWidgets('displays aggregation level section', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Aggregation Level'), findsOneWidget);
    });

    testWidgets('displays items section', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Items'), findsOneWidget);
    });

    testWidgets('displays email section', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Email Address'), findsOneWidget);
    });

    testWidgets('displays export button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Export to Email'), findsOneWidget);
    });

    testWidgets('shows loading state during export', (tester) async {
      when(() => mockExportBloc.state).thenReturn(const ExportInProgress());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Exporting...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
    });

    testWidgets('shows item dropdown with all items selected by default', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Dropdown field shows "All items" and preview also shows "All items"
      expect(find.text('All items'), findsNWidgets(2));
    });

    testWidgets('opens item picker bottom sheet on tap', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Scroll to the dropdown and tap it
      await tester.scrollUntilVisible(
        find.byIcon(Icons.checklist_rounded),
        100.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byIcon(Icons.checklist_rounded));
      await tester.pumpAndSettle();

      // Bottom sheet shows items and search field
      expect(find.text('Select Items'), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Tea'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });
  });
}
