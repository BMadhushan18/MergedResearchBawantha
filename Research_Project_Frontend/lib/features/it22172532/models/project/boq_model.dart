
// --- BOQ Item -----------------------------------------------------------------
// floor / section / subsection drive hierarchy in the UI;
// each BOQ item stores its own position references.
class BOQItem {
  final String boqItemId;
  final String floor;        // e.g. 'Ground Floor'
  final String section;      // e.g. 'Substructure'
  final String subsection;   // e.g. 'Footings'
  final String description;
  final String unit;
  final double? qty;
  final double? wastagePercent;
  final double? unitRate;
  final double? amount;      // computed: qty * (1+wastage%) * unitRate
  final String materialId;
  final String? brandId;
  final String? sizeId;
  final List<String> notes;
  final DateTime? createdAt;

  BOQItem({
    required this.boqItemId,
    this.floor = 'Ground Floor',
    this.section = 'Substructure',
    this.subsection = 'Footings',
    required this.description,
    this.unit = 'm3',
    this.qty,
    this.wastagePercent,
    this.unitRate,
    this.amount,
    this.materialId = '',
    this.brandId,
    this.sizeId,
    List<String>? notes,
    this.createdAt,
  }) : notes = notes ?? [];

  double get computedAmount {
    if (qty == null || unitRate == null) return 0;
    final waste = 1 + ((wastagePercent ?? 0) / 100);
    return qty! * waste * unitRate!;
  }

  Map<String, dynamic> toMap() => {
        'boqItemId': boqItemId,
        'floor': floor,
        'section': section,
        'subsection': subsection,
        'description': description,
        'unit': unit,
        'qty': qty,
        'wastagePercent': wastagePercent,
        'unitRate': unitRate,
        'amount': computedAmount,
        'materialId': materialId,
        'brandId': brandId,
        'sizeId': sizeId,
        'notes': notes,
        'createdAt':
            createdAt?.toIso8601String(),
      };

  factory BOQItem.fromMap(Map<String, dynamic> d) => BOQItem(
        boqItemId: d['boqItemId'] ?? '',
        floor: d['floor'] ?? 'Ground Floor',
        section: d['section'] ?? 'Substructure',
        subsection: d['subsection'] ?? '',
        description: d['description'] ?? '',
        unit: d['unit'] ?? 'm3',
        qty: (d['qty'] as num?)?.toDouble(),
        wastagePercent: (d['wastagePercent'] as num?)?.toDouble(),
        unitRate: (d['unitRate'] as num?)?.toDouble(),
        amount: (d['amount'] as num?)?.toDouble(),
        materialId: d['materialId'] ?? '',
        brandId: d['brandId'],
        sizeId: d['sizeId'],
        notes: List<String>.from(d['notes'] ?? []),
        createdAt: d["createdAt"] != null ? DateTime.tryParse(d["createdAt"].toString()) : null,
      );
}
