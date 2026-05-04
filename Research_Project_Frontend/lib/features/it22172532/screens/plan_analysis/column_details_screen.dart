import 'package:flutter/material.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';

class ColumnDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> resultMap;

  const ColumnDetailsScreen({super.key, required this.resultMap});

  @override
  Widget build(BuildContext context) {
    final groundFloor = resultMap['groundFloor'] as Map<String, dynamic>?;
    final columns = groundFloor?['columns'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Column Details'),
        backgroundColor: AppColors.primary,
      ),
      body: columns.isEmpty
          ? const Center(
              child: Text('No column data available'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: columns.length,
              itemBuilder: (context, index) {
                final columnId = columns.keys.elementAt(index);
                final columnData = columns[columnId] as Map<String, dynamic>;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Column $columnId',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow('Height', columnData['height']),
                        _buildDetailRow('Width', columnData['width']),
                        _buildDetailRow('Length', columnData['length']),
                        _buildDetailRow('Total Area', columnData['totalArea']),
                        const SizedBox(height: 12),
                        const Text(
                          'Concrete Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Concrete Ratio', columnData['Concrete']?['concreteRatio']),
                        const SizedBox(height: 8),
                        const Text(
                          'Quantities',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildDetailRow('Sand', columnData['Concrete']?['Quantity']?['sand']),
                        _buildDetailRow('Cement', columnData['Concrete']?['Quantity']?['cement']),
                        _buildDetailRow('Aggregate', columnData['Concrete']?['Quantity']?['aggregate']),
                        _buildDetailRow('Steel', columnData['Concrete']?['Quantity']?['steels']),
                        _buildDetailRow('Binding Wire', columnData['Concrete']?['Quantity']?['bindingWire']),
                        if (columnData['notes'] != null && (columnData['notes'] as List).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Notes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (columnData['notes'] as List).join('\n'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: TextStyle(
                color: value == null ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
