import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trackwise/features/export/domain/entities/csv_export_config.dart';
import 'package:trackwise/features/export/presentation/bloc/export_bloc.dart';
import 'package:trackwise/features/export/presentation/bloc/export_event.dart';
import 'package:trackwise/features/export/presentation/bloc/export_state.dart';
import 'package:trackwise/features/export/presentation/pages/export_page.dart';

class MockExportBloc extends MockBloc<ExportEvent, ExportState>
    implements ExportBloc {}

void main() {
  late MockExportBloc mockExportBloc;

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

    // Register mock bloc in service locator
    final sl = GetIt.instance;
    if (sl.isRegistered<ExportBloc>()) {
      sl.unregister<ExportBloc>();
    }
    sl.registerFactory<ExportBloc>(() => mockExportBloc);

    when(() => mockExportBloc.state).thenReturn(const ExportInitial());
  });

  tearDown(() {
    final sl = GetIt.instance;
    if (sl.isRegistered<ExportBloc>()) {
      sl.unregister<ExportBloc>();
    }
  });

  Widget createTestWidget() {
    return const MaterialApp(
      home: ExportPage(),
    );
  }

  group('ExportPage', () {
    testWidgets('renders scaffold', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays date range section', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Date Range'), findsOneWidget);
    });

    testWidgets('displays aggregation level section', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Aggregation Level'), findsOneWidget);
    });

    testWidgets('displays email section', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Email Address'), findsOneWidget);
    });

    testWidgets('displays export button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Export to Email'), findsOneWidget);
    });

    testWidgets('shows loading state during export', (tester) async {
      when(() => mockExportBloc.state).thenReturn(const ExportInProgress());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Exporting...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });
}
