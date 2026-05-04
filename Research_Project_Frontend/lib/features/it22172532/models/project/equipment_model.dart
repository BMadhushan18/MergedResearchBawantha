// --- Equipment ---------------------------------------------------------------
class EquipmentModel {
  final String equipmentId;
  final String equipmentName;
  final String hireType; // 'Owned|Hired'
  final String? supplierId;
  final String rateType; // 'Per Day|Per Hour'
  final double? rate;
  final List<String> notes;

  EquipmentModel({
    required this.equipmentId,
    required this.equipmentName,
    this.hireType = 'Hired',
    this.supplierId,
    this.rateType = 'Per Day',
    this.rate,
    List<String>? notes,
  }) : notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'equipmentId': equipmentId,
        'equipmentName': equipmentName,
        'hireType': hireType,
        'supplierId': supplierId,
        'rateType': rateType,
        'rate': rate,
        'notes': notes,
      };

  factory EquipmentModel.fromMap(Map<String, dynamic> d) => EquipmentModel(
        equipmentId: d['equipmentId'] ?? '',
        equipmentName: d['equipmentName'] ?? '',
        hireType: d['hireType'] ?? 'Hired',
        supplierId: d['supplierId'],
        rateType: d['rateType'] ?? 'Per Day',
        rate: (d['rate'] as num?)?.toDouble(),
        notes: List<String>.from(d['notes'] ?? []),
      );
}

// --- Tool ---------------------------------------------------------------------
class ToolModel {
  final String toolId;
  final String toolName;
  final int? qty;
  final String condition; // 'Good|Repair|Lost'
  final List<String> notes;

  ToolModel({
    required this.toolId,
    required this.toolName,
    this.qty,
    this.condition = 'Good',
    List<String>? notes,
  }) : notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'toolId': toolId,
        'toolName': toolName,
        'qty': qty,
        'condition': condition,
        'notes': notes,
      };

  factory ToolModel.fromMap(Map<String, dynamic> d) => ToolModel(
        toolId: d['toolId'] ?? '',
        toolName: d['toolName'] ?? '',
        qty: d['qty'],
        condition: d['condition'] ?? 'Good',
        notes: List<String>.from(d['notes'] ?? []),
      );
}
