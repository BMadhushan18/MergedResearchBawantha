import 'package:flutter/material.dart';

/// Measurement Report Screen
/// Displays all building parts with measurements in a table format
/// Each part has a button to view detailed BOQ (Bill of Quantities)
class MeasurementReportScreen extends StatefulWidget {
  final Map<String, dynamic> analysisData;
  final String filename;

  const MeasurementReportScreen({
    Key? key,
    required this.analysisData,
    required this.filename,
  }) : super(key: key);

  @override
  State<MeasurementReportScreen> createState() => _MeasurementReportScreenState();
}

class _MeasurementReportScreenState extends State<MeasurementReportScreen> {
  List<Map<String, dynamic>> buildingParts = [];
  Map<String, dynamic>? planMetadata;

  @override
  void initState() {
    super.initState();
    _parseAnalysisData();
  }

  void _parseAnalysisData() {
    final analysis = widget.analysisData['analysis'];
    planMetadata = analysis['plan_metadata'];
    buildingParts = List<Map<String, dynamic>>.from(analysis['building_parts'] ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Measurement Report'),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportReport,
            tooltip: 'Export Report',
          ),
        ],
      ),
      body: Column(
        children: [
          // Plan metadata card
          _buildMetadataCard(),
          
          // Parts table
          Expanded(
            child: _buildPartsTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard() {
    if (planMetadata == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan: ${widget.filename}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _buildInfoChip('Type', planMetadata!['plan_type'] ?? 'N/A'),
                _buildInfoChip('Built-up Area', planMetadata!['total_built_up_area'] ?? 'N/A'),
                _buildInfoChip('Carpet Area', planMetadata!['total_carpet_area'] ?? 'N/A'),
                _buildInfoChip('Plot Area', planMetadata!['plot_area'] ?? 'N/A'),
                _buildInfoChip('Scale', planMetadata!['scale'] ?? 'N/A'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Chip(
      avatar: const Icon(Icons.info_outline, size: 18),
      label: Text('$label: $value'),
      backgroundColor: Colors.blue.shade50,
    );
  }

  Widget _buildPartsTable() {
    if (buildingParts.isEmpty) {
      return const Center(
        child: Text('No building parts found in analysis'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Card(
          margin: const EdgeInsets.all(16),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.blue.shade100),
            columns: const [
              DataColumn(label: Text('Part Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Length', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Width', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Height', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Area', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Volume', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('BOQ', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: buildingParts.map((part) {
              final measurements = part['measurements'] ?? {};
              return DataRow(
                cells: [
                  DataCell(Text(part['part_name'] ?? 'Unknown')),
                  DataCell(
                    Chip(
                      label: Text(
                        part['category'] ?? 'N/A',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: _getCategoryColor(part['category']),
                    ),
                  ),
                  DataCell(Text(measurements['length'] ?? 'N/A')),
                  DataCell(Text(measurements['width'] ?? 'N/A')),
                  DataCell(Text(measurements['height'] ?? 'N/A')),
                  DataCell(Text(measurements['area'] ?? 'N/A')),
                  DataCell(Text(measurements['volume'] ?? 'N/A')),
                  DataCell(
                    ElevatedButton.icon(
                      icon: const Icon(Icons.assignment, size: 18),
                      label: const Text('View BOQ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _navigateToBOQ(part),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'room':
        return Colors.blue.shade100;
      case 'bathroom':
      case 'toilet':
        return Colors.cyan.shade100;
      case 'kitchen':
        return Colors.orange.shade100;
      case 'outdoor':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  void _navigateToBOQ(Map<String, dynamic> part) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BOQReportScreen(
          partData: part,
          planMetadata: planMetadata,
        ),
      ),
    );
  }

  void _exportReport() {
    // TODO: Implement PDF export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}


/// BOQ (Bill of Quantities) Report Screen
/// Shows detailed material breakdown for a selected building part
class BOQReportScreen extends StatefulWidget {
  final Map<String, dynamic> partData;
  final Map<String, dynamic>? planMetadata;

  const BOQReportScreen({
    Key? key,
    required this.partData,
    this.planMetadata,
  }) : super(key: key);

  @override
  State<BOQReportScreen> createState() => _BOQReportScreenState();
}

class _BOQReportScreenState extends State<BOQReportScreen> {
  Map<String, List<MaterialItem>> selectedMaterials = {};
  Map<String, dynamic> materialCategories = {};

  @override
  void initState() {
    super.initState();
    _parseMaterialCategories();
  }

  void _parseMaterialCategories() {
    materialCategories = widget.partData['material_categories'] ?? {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BOQ - ${widget.partData['part_name']}'),
        backgroundColor: Colors.green.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: _viewSelectedBOQ,
            tooltip: 'View Selected BOQ',
          ),
        ],
      ),
      body: ListView(
        children: [
          // Part summary card
          _buildPartSummaryCard(),
          
          // Material categories
          ...materialCategories.entries.map((entry) {
            return _buildCategorySection(entry.key, entry.value);
          }).toList(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildPartSummaryCard() {
    final measurements = widget.partData['measurements'] ?? {};
    
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.partData['part_name'] ?? 'Unknown Part',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Category: ${widget.partData['category'] ?? 'N/A'}'),
            const Divider(),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildMeasurementChip('Area', measurements['area']),
                _buildMeasurementChip('Volume', measurements['volume']),
                _buildMeasurementChip('Perimeter', measurements['perimeter']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementChip(String label, dynamic value) {
    return Chip(
      label: Text('$label: ${value ?? 'N/A'}'),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildCategorySection(String categoryName, Map<String, dynamic> categoryData) {
    final materials = List<Map<String, dynamic>>.from(categoryData['materials'] ?? []);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(
          categoryName.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text('${materials.length} materials'),
        leading: Icon(_getCategoryIcon(categoryName), color: Colors.green),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade200),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Material', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Select', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                ...materials.map((material) {
                  return _buildMaterialRow(categoryName, material, categoryData);
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildMaterialRow(String category, Map<String, dynamic> material, Map<String, dynamic> categoryData) {
    final materialName = material['name'] ?? 'Unknown';
    final unit = material['unit'] ?? 'unit';
    
    // Calculate quantity
    final quantity = _calculateMaterialQuantity(material, categoryData);
    
    final isSelected = selectedMaterials[category]?.any((item) => item.name == materialName) ?? false;

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(materialName),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(unit),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(quantity.toStringAsFixed(2)),
        ),
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: Checkbox(
            value: isSelected,
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _addMaterial(category, MaterialItem(
                    name: materialName,
                    unit: unit,
                    quantity: quantity,
                    category: category,
                  ));
                } else {
                  _removeMaterial(category, materialName);
                }
              });
            },
          ),
        ),
      ],
    );
  }

  double _calculateMaterialQuantity(Map<String, dynamic> material, Map<String, dynamic> categoryData) {
    final area = _parseArea(categoryData['area']);
    
    // If quantity is directly provided
    if (material.containsKey('quantity')) {
      return double.tryParse(material['quantity'].toString()) ?? 0.0;
    }
    
    // Calculate based on rate per sqft
    if (material.containsKey('rate_per_sqft')) {
      final rate = double.tryParse(material['rate_per_sqft'].toString()) ?? 0.0;
      var quantity = area * rate;
      
      // Apply wastage factor if present
      if (material.containsKey('wastage_factor')) {
        final wastage = double.tryParse(material['wastage_factor'].toString()) ?? 1.0;
        quantity *= wastage;
      }
      
      return quantity;
    }
    
    return 0.0;
  }

  double _parseArea(dynamic areaValue) {
    if (areaValue == null) return 0.0;
    final areaStr = areaValue.toString().replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(areaStr) ?? 0.0;
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'floor':
        return Icons.layers;
      case 'wall':
        return Icons.view_column;
      case 'ceiling':
        return Icons.roofing;
      case 'beam':
        return Icons.construction;
      case 'roof':
        return Icons.roofing;
      default:
        return Icons.category;
    }
  }

  void _addMaterial(String category, MaterialItem item) {
    if (!selectedMaterials.containsKey(category)) {
      selectedMaterials[category] = [];
    }
    selectedMaterials[category]!.add(item);
  }

  void _removeMaterial(String category, String materialName) {
    selectedMaterials[category]?.removeWhere((item) => item.name == materialName);
    if (selectedMaterials[category]?.isEmpty ?? false) {
      selectedMaterials.remove(category);
    }
  }

  Widget _buildBottomBar() {
    final totalItems = selectedMaterials.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$totalItems materials selected',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add to BOQ Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: totalItems > 0 ? _addToBOQReport : null,
          ),
        ],
      ),
    );
  }

  void _viewSelectedBOQ() {
    if (selectedMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No materials selected yet')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectedBOQScreen(
          selectedMaterials: selectedMaterials,
          partName: widget.partData['part_name'] ?? 'Unknown',
        ),
      ),
    );
  }

  void _addToBOQReport() {
    // TODO: Save to persistent BOQ report
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${selectedMaterials.values.fold<int>(0, (sum, list) => sum + list.length)} materials to BOQ Report'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
    
    Navigator.pop(context);
  }
}


/// Selected BOQ Screen - Shows cart of selected materials
class SelectedBOQScreen extends StatelessWidget {
  final Map<String, List<MaterialItem>> selectedMaterials;
  final String partName;

  const SelectedBOQScreen({
    Key? key,
    required this.selectedMaterials,
    required this.partName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selected BOQ'),
        backgroundColor: Colors.green.shade700,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Part: $partName',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...selectedMaterials.entries.map((entry) {
            return _buildCategoryCard(entry.key, entry.value);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String category, List<MaterialItem> materials) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category.toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const Divider(),
            ...materials.map((item) {
              return ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(item.name),
                subtitle: Text('${item.quantity.toStringAsFixed(2)} ${item.unit}'),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}


/// Material Item Model
class MaterialItem {
  final String name;
  final String unit;
  final double quantity;
  final String category;

  MaterialItem({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.category,
  });
}
