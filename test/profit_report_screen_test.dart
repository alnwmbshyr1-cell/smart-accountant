import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_accountant/profit_report_screen.dart';
import 'package:smart_accountant/providers.dart';

Widget reportApp({
  Future<List<Map<String, dynamic>>> Function(Ref ref)? report,
}) {
  return ProviderScope(
    overrides: [
      if (report != null) monthlyProfitReportProvider(6).overrideWith(report),
    ],
    child: const MaterialApp(home: ProfitReportScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows loading state while report is pending', (tester) async {
    await tester.pumpWidget(
      reportApp(
        report: (_) => Future<List<Map<String, dynamic>>>.delayed(
          const Duration(seconds: 1),
          () => <Map<String, dynamic>>[],
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('shows empty report message when there are no rows',
      (tester) async {
    await tester.pumpWidget(
      reportApp(
        report: (_) async => <Map<String, dynamic>>[],
      ),
    );
    await tester.pump();

    expect(find.text('صافي الربح الشهري'), findsOneWidget);
    expect(find.text('لا توجد بيانات كافية للرسم'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('renders positive and negative profits with summary rows',
      (tester) async {
    final rows = [
      <String, dynamic>{
        'month': '2026-01',
        'sales': 250000,
        'expenses': 100000,
        'profit': 150000,
      },
      <String, dynamic>{
        'month': '2026-02',
        'sales': 50000,
        'expenses': 90000,
        'profit': -40000,
      },
    ];
    await tester.pumpWidget(reportApp(report: (_) async => rows));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('2026-01'), findsNWidgets(2));
    expect(find.text('2026-02'), findsNWidgets(2));
    expect(find.textContaining('مبيعات:'), findsNWidgets(2));
    expect(find.textContaining('مصروفات:'), findsNWidgets(2));
  });

  testWidgets('shows an error message when report loading fails',
      (tester) async {
    await tester.pumpWidget(
      reportApp(
        report: (_) async => throw StateError('database unavailable'),
      ),
    );
    await tester.pump();

    expect(find.textContaining('تعذر تحميل التقرير'), findsOneWidget);
  });

  testWidgets('changes selected report period from dropdown', (tester) async {
    final container = ProviderContainer(
      overrides: [
        monthlyProfitReportProvider(6).overrideWith(
          (_) async => <Map<String, dynamic>>[],
        ),
        monthlyProfitReportProvider(3).overrideWith(
          (_) async => <Map<String, dynamic>>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProfitReportScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('6 أشهر'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pump();
    await tester.tap(find.text('3 أشهر').last);
    await tester.pump();

    expect(container.read(selectedReportMonthsProvider), 3);
  });
}
