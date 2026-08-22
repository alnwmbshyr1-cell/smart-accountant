import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class ProfitReportScreen extends ConsumerWidget {
  const ProfitReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(selectedReportMonthsProvider);
    final report = ref.watch(monthlyProfitReportProvider(months));
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('الأرباح والتقارير')),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('تعذر تحميل التقرير: $error'),
        ),
        data: (rows) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(monthlyProfitReportProvider(months));
            await ref.read(monthlyProfitReportProvider(months).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'صافي الربح الشهري',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  DropdownButton<int>(
                    value: months,
                    items: const [3, 6, 12]
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text('$value أشهر'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(selectedReportMonthsProvider.notifier).state =
                            value;
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 24, 16, 16),
                  child: SizedBox(
                    height: 300,
                    child: rows.isEmpty
                        ? const Center(
                            child: Text('لا توجد بيانات كافية للرسم'))
                        : BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: _maxY(rows),
                              minY: _minY(rows),
                              gridData: const FlGridData(show: true),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 54,
                                    getTitlesWidget: (value, meta) => Text(
                                      _compact(value),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 34,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index < 0 || index >= rows.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          rows[index]['month'].toString(),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              barGroups: [
                                for (var index = 0;
                                    index < rows.length;
                                    index++)
                                  BarChartGroupData(
                                    x: index,
                                    barRods: [
                                      BarChartRodData(
                                        toY: (rows[index]['profit'] as num)
                                            .toDouble(),
                                        width: 18,
                                        color:
                                            (rows[index]['profit'] as num) >= 0
                                                ? colors.primary
                                                : colors.error,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...rows.reversed.map(
                (row) => ListTile(
                  title: Text(row['month'].toString()),
                  subtitle: Text(
                    'مبيعات: ${_compact((row['sales'] as num).toDouble())}   مصروفات: ${_compact((row['expenses'] as num).toDouble())}',
                  ),
                  trailing: Text(
                    _compact((row['profit'] as num).toDouble()),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: (row['profit'] as num) >= 0
                          ? colors.primary
                          : colors.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double _maxY(List<Map<String, dynamic>> rows) {
    final values = rows.map((row) => (row['profit'] as num).toDouble());
    final max = values.fold<double>(
        0, (current, value) => value > current ? value : current);
    return max <= 0 ? 100 : max * 1.2;
  }

  static double _minY(List<Map<String, dynamic>> rows) {
    final values = rows.map((row) => (row['profit'] as num).toDouble());
    final min = values.fold<double>(
        0, (current, value) => value < current ? value : current);
    return min >= 0 ? 0 : min * 1.2;
  }

  static String _compact(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}م';
    }
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}ك';
    }
    return value.toStringAsFixed(0);
  }
}
