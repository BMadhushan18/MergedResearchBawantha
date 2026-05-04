// Bar chart for Vehicle, Labour, and Machinery totals.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/dashboard_models.dart';

class TotalsChart extends StatelessWidget {
  final DashboardSummary summary;
  final int vehicleCount;
  final int machineryCount;
  final int gangCount;

  const TotalsChart({
    super.key,
    required this.summary,
    required this.vehicleCount,
    required this.machineryCount,
    required this.gangCount,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = [
      vehicleCount.toDouble(),
      machineryCount.toDouble(),
      gangCount.toDouble(),
    ].reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resources Overview', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxY <= 0 ? 10 : maxY * 1.2,
                  barGroups: [
                    _group(0, vehicleCount.toDouble(), const Color(0xFFFF6B35)),
                    _group(1, gangCount.toDouble(), const Color(0xFF3F51B5)),
                    _group(2, machineryCount.toDouble(), const Color(0xFF00897B)),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const labels = ['Vehicle Cost', 'Labour Cost', 'Machinery Cost'];
                          final idx = value.toInt();
                          if (idx < 0 || idx >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(labels[idx], style: const TextStyle(fontSize: 11)),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _group(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 28,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }
}
