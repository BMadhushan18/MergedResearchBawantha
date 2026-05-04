import 'package:flutter/material.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import 'material_detail_screen.dart';

// BoQ Item Model
class BoqItem {
  final String week;
  final String description;
  final String unit;
  final double quantity;
  final double rate;
  final double amount;
  final String? type; // 'wall' or 'floor'

  BoqItem({
    required this.week,
    required this.description,
    required this.unit,
    required this.quantity,
    required this.rate,
    this.type,
  }) : amount = quantity * rate;
}

class MaterialEstimateScreen extends StatefulWidget {
  const MaterialEstimateScreen({super.key});

  @override
  State<MaterialEstimateScreen> createState() => _MaterialEstimateScreenState();
}

class _MaterialEstimateScreenState extends State<MaterialEstimateScreen> {
  List<BoqItem> boqItems = [
    BoqItem(week: '01', description: 'Excavation', unit: 'm³', quantity: 500, rate: 10.00),
    BoqItem(week: '02', description: 'Concrete (Grade B20)', unit: 'm³', quantity: 200, rate: 80.00),
    BoqItem(week: '03', description: 'Brickwork (230mm)', unit: 'm²', quantity: 1000, rate: 25.00),
    BoqItem(week: '04', description: 'Roofing (Metal Sheets)', unit: 'm²', quantity: 500, rate: 50.00),
    BoqItem(week: '05', description: 'Electrical Wiring (2.5mm²)', unit: 'meter', quantity: 1000, rate: 5.00),
    BoqItem(week: '06', description: 'Plumbing Pipes (PVC)', unit: 'meter', quantity: 800, rate: 8.00),
    BoqItem(week: '07', description: 'HVAC Ducting (Galvanized Steel)', unit: 'meter', quantity: 500, rate: 30.00),
    BoqItem(week: '08', description: 'Waterproofing', unit: 'm²', quantity: 800, rate: 15.00),
    BoqItem(week: '09', description: 'Glazing (Double Pane)', unit: 'm²', quantity: 600, rate: 40.00),
  ];

  @override
  Widget build(BuildContext context) {
    double total = boqItems.fold(0, (sum, item) => sum + item.amount);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bill of Quantities (BoQ)'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // TODO: Print or export BoQ
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Share BoQ
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Section with Company Info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Company Logo & Name
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.construction, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CONSTRUCT CORP',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Contact Info
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Chicago, IL 60631', style: TextStyle(fontSize: 11)),
                        Text('info@construct.com', style: TextStyle(fontSize: 11)),
                        Text('construct.com', style: TextStyle(fontSize: 11)),
                        Text('222 555 7777', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(thickness: 1),
                const SizedBox(height: 16),
                // Project Details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Project Name', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        SizedBox(height: 4),
                        Text('Address', style: TextStyle(color: Colors.black54, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('Number', style: TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Date', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        const SizedBox(height: 4),
                        const Text('Total', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          '\$ ${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Title
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: AppColors.primary.withOpacity(0.1),
            child: const Center(
              child: Text(
                'Construction Bill of Quantities (BoQ) table',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          // BoQ Table
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildBoqTable(),
              ),
            ),
          ),

          // Add Item Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: _showAddItemDialog,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Scan Surface'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Items Added',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan walls or floors to add items',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BoqItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _editItem(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Week ${item.week}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '\$ ${item.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.description,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.straighten,
                    label: '${item.quantity.toStringAsFixed(0)} ${item.unit}',
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    icon: Icons.attach_money,
                    label: '${item.rate.toStringAsFixed(2)} / ${item.unit}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editItem(item),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteItem(item),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoqTable() {
    return DataTable(
      headingRowColor: MaterialStateProperty.all(AppColors.primary.withOpacity(0.2)),
      columnSpacing: 40,
      horizontalMargin: 24,
      columns: const [
        DataColumn(label: Text('Week', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Rate (\$)', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Amount (\$)', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: [
        ...boqItems.map((item) => DataRow(
          cells: [
            DataCell(Text(item.week)),
            DataCell(Text(item.description)),
            DataCell(Text(item.unit)),
            DataCell(Text(item.quantity.toStringAsFixed(0))),
            DataCell(Text('\$ ${item.rate.toStringAsFixed(2)}')),
            DataCell(Text('\$ ${item.amount.toStringAsFixed(2)}', 
                         style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _editItem(item),
                    color: Colors.blue,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: () => _deleteItem(item),
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ],
        )),
        // Empty row for adding new item
        DataRow(
          cells: [
            DataCell(
              InkWell(
                onTap: _showAddItemDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                ),
              ),
            ),
            const DataCell(Text('Click + to add item')),
            const DataCell(Text('-')),
            const DataCell(Text('-')),
            const DataCell(Text('-')),
            const DataCell(Text('-')),
            const DataCell(Text('')),
          ],
        ),
      ],
    );
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select surface type to scan and add:'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _scanSurface('wall');
                    },
                    icon: const Icon(Icons.layers),
                    label: const Text('Wall'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _scanSurface('floor');
                    },
                    icon: const Icon(Icons.grid_on),
                    label: const Text('Floor'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _scanSurface(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scan feature not available in this build')),
    );
  }

  void _addItemFromScan(String type, dynamic scanResult) {
    // Calculate quantities based on construction standards
    // This is a simplified example - real implementation would use actual scan data
    
    double area = 0;
    String description = '';
    String unit = 'm²';
    double quantity = 0;
    double rate = 0;
    
    if (type == 'wall') {
      // Example: If wall is 10m² area
      area = scanResult['area'] ?? 10.0;
      description = 'Wall Construction (Scanned)';
      quantity = area;
      rate = 25.00; // Rate per m²
      
      // Add related items based on construction standards
      setState(() {
        String week = (boqItems.length + 1).toString().padLeft(2, '0');
        boqItems.add(BoqItem(
          week: week,
          description: description,
          unit: unit,
          quantity: quantity,
          rate: rate,
          type: type,
        ));
        
        // Auto-add related materials
        boqItems.add(BoqItem(
          week: (boqItems.length + 1).toString().padLeft(2, '0'),
          description: 'Wall Plastering',
          unit: 'm²',
          quantity: quantity,
          rate: 12.00,
          type: type,
        ));
        
        boqItems.add(BoqItem(
          week: (boqItems.length + 1).toString().padLeft(2, '0'),
          description: 'Wall Painting',
          unit: 'm²',
          quantity: quantity,
          rate: 8.00,
          type: type,
        ));
      });
    } else if (type == 'floor') {
      area = scanResult['area'] ?? 15.0;
      description = 'Floor Area (Scanned)';
      quantity = area;
      rate = 30.00;
      
      setState(() {
        String week = (boqItems.length + 1).toString().padLeft(2, '0');
        boqItems.add(BoqItem(
          week: week,
          description: description,
          unit: unit,
          quantity: quantity,
          rate: rate,
          type: type,
        ));
        
        // Auto-add related materials
        boqItems.add(BoqItem(
          week: (boqItems.length + 1).toString().padLeft(2, '0'),
          description: 'Floor Tiles',
          unit: 'm²',
          quantity: quantity,
          rate: 45.00,
          type: type,
        ));
        
        boqItems.add(BoqItem(
          week: (boqItems.length + 1).toString().padLeft(2, '0'),
          description: 'Floor Finishing',
          unit: 'm²',
          quantity: quantity,
          rate: 15.00,
          type: type,
        ));
      });
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $type with area ${area.toStringAsFixed(2)} m²')),
    );
  }

  void _editItem(BoqItem item) {
    // TODO: Implement edit functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon')),
    );
  }

  void _deleteItem(BoqItem item) {
    setState(() {
      boqItems.remove(item);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item deleted')),
    );
  }
}
