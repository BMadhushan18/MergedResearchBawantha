
// ─── Price Record (Store Wise Price History) ──────────────────────────────────
class PriceRecord {
  final String priceRecordId;
  final DateTime? date;
  final String storeId;
  final String materialId;
  final String? brandId;
  final String? sizeId;
  final String unit;
  final double? unitPrice;
  final double? discountPercent;
  final bool taxIncluded;
  final List<String> notes;

  PriceRecord({
    required this.priceRecordId,
    this.date,
    required this.storeId,
    required this.materialId,
    this.brandId,
    this.sizeId,
    this.unit = 'bag',
    this.unitPrice,
    this.discountPercent,
    this.taxIncluded = false,
    List<String>? notes,
  }) : notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'priceRecordId': priceRecordId,
        'date': date?.toIso8601String(),
        'storeId': storeId,
        'materialId': materialId,
        'brandId': brandId,
        'sizeId': sizeId,
        'unit': unit,
        'unitPrice': unitPrice,
        'discountPercent': discountPercent,
        'taxIncluded': taxIncluded,
        'notes': notes,
      };

  factory PriceRecord.fromMap(Map<String, dynamic> d) => PriceRecord(
        priceRecordId: d['priceRecordId'] ?? '',
        date: d["date"] != null ? DateTime.tryParse(d["date"].toString()) : null,
        storeId: d['storeId'] ?? '',
        materialId: d['materialId'] ?? '',
        brandId: d['brandId'],
        sizeId: d['sizeId'],
        unit: d['unit'] ?? 'bag',
        unitPrice: (d['unitPrice'] as num?)?.toDouble(),
        discountPercent: (d['discountPercent'] as num?)?.toDouble(),
        taxIncluded: d['taxIncluded'] ?? false,
        notes: List<String>.from(d['notes'] ?? []),
      );
}

// ─── Latest Price Snapshot entry ─────────────────────────────────────────────
class LatestPrice {
  final String storeId;
  final String materialId;
  final String? brandId;
  final String? sizeId;
  final double? unitPrice;
  final DateTime? effectiveDate;

  LatestPrice({
    required this.storeId,
    required this.materialId,
    this.brandId,
    this.sizeId,
    this.unitPrice,
    this.effectiveDate,
  });

  Map<String, dynamic> toMap() => {
        'storeId': storeId,
        'materialId': materialId,
        'brandId': brandId,
        'sizeId': sizeId,
        'unitPrice': unitPrice,
        'effectiveDate': effectiveDate?.toIso8601String(),
      };

  factory LatestPrice.fromMap(Map<String, dynamic> d) => LatestPrice(
        storeId: d['storeId'] ?? '',
        materialId: d['materialId'] ?? '',
        brandId: d['brandId'],
        sizeId: d['sizeId'],
        unitPrice: (d['unitPrice'] as num?)?.toDouble(),
        effectiveDate: d["effectiveDate"] != null ? DateTime.tryParse(d["effectiveDate"].toString()) : null,
      );
}
