// Donut chart for new schema totals.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/dashboard_models.dart';

class DonutChart extends StatelessWidget {
  final DashboardSummary summary;
  final int vehicleCount;
  final int machineryCount;
  final int gangCount;

  const DonutChart({
    super.key,
    required this.summary,
    required this.vehicleCount,
    required this.machineryCount,
    required this.gangCount,
  });

  @override
  Widget build(BuildContext context) {
    final total = vehicleCount + machineryCount + gangCount;

    if (total == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Resource Distribution', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  'No data available',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    }

    final vehiclePercent = (vehicleCount / total * 100).toStringAsFixed(1);
    final machineryPercent = (machineryCount / total * 100).toStringAsFixed(1);
    final gangPercent = (gangCount / total * 100).toStringAsFixed(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resource Distribution', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 350;
                final chartContent = PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: isNarrow ? 35 : 50,
                    sections: [
                      if (vehicleCount > 0)
                        PieChartSectionData(
                          color: const Color(0xFFFF6B35),
                          value: vehicleCount.toDouble(),
                          title: '$vehiclePercent%',
                          radius: isNarrow ? 45 : 60,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      if (machineryCount > 0)
                        PieChartSectionData(
                          color: const Color(0xFF00897B),
                          value: machineryCount.toDouble(),
                          title: '$machineryPercent%',
                          radius: isNarrow ? 45 : 60,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      if (gangCount > 0)
                        PieChartSectionData(
                          color: const Color(0xFF3F51B5),
                          value: gangCount.toDouble(),
                          title: '$gangPercent%',
                          radius: isNarrow ? 45 : 60,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                );
                
                final legendContent = Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (vehicleCount > 0)
                      _buildLegendItem('Vehicle Count', '$vehicleCount', const Color(0xFFFF6B35)),
                    if (machineryCount > 0)
                      _buildLegendItem('Machinery Count', '$machineryCount', const Color(0xFF00897B)),
                    if (gangCount > 0)
                      _buildLegendItem('Total Gang', '$gangCount', const Color(0xFF3F51B5)),
                  ],
                );
                
                if (isNarrow) {
                  return Column(
                     children: [
                       SizedBox(height: 160, child: chartContent),
                       const SizedBox(height: 16),
                       legendContent,
                     ],
                  );
                }

                return SizedBox(
                  height: 200,
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: chartContent),
                      Expanded(flex: 1, child: legendContent),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
