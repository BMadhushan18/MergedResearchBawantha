
// --- Stock Ledger Entry -------------------------------------------------------
class StockEntry {
  final String entryId;
  final DateTime? date;
  final String materialId;
  final String? brandId;
  final String? sizeId;
  final String transactionType; // 'IN|OUT|ADJUSTMENT'
  final double? qty;
  final String unit;
  final String? referenceId;   // GRN ID, Issue Note ID, etc.
  final String? referenceType; // 'GRN|Issue|Adjustment'
  final double? balanceAfter;
  final List<String> notes;

  StockEntry({
    required this.entryId,
    this.date,
    required this.materialId,
    this.brandId,
    this.sizeId,
    this.transactionType = 'IN',
    this.qty,
    this.unit = 'bag',
    this.referenceId,
    this.referenceType,
    this.balanceAfter,
    List<String>? notes,
  }) : notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'entryId': entryId,
        'date': date?.toIso8601String(),
        'materialId': materialId,
        'brandId': brandId,
        'sizeId': sizeId,
        'transactionType': transactionType,
        'qty': qty,
        'unit': unit,
        'referenceId': referenceId,
        'referenceType': referenceType,
        'balanceAfter': balanceAfter,
        'notes': notes,
      };

  factory StockEntry.fromMap(Map<String, dynamic> d) => StockEntry(
        entryId: d['entryId'] ?? '',
        date: d["date"] != null ? DateTime.tryParse(d["date"].toString()) : null,
        materialId: d['materialId'] ?? '',
        brandId: d['brandId'],
        sizeId: d['sizeId'],
        transactionType: d['transactionType'] ?? 'IN',
        qty: (d['qty'] as num?)?.toDouble(),
        unit: d['unit'] ?? 'bag',
        referenceId: d['referenceId'],
        referenceType: d['referenceType'],
        balanceAfter: (d['balanceAfter'] as num?)?.toDouble(),
        notes: List<String>.from(d['notes'] ?? []),
      );
}

// --- Issue Note ---------------------------------------------------------------
class IssueNoteLine {
  final String materialId;
  final double? qty;
  final String unit;
  final String? issuedTo; // worker or task

  IssueNoteLine(
      {required this.materialId, this.qty, this.unit = 'bag', this.issuedTo});

  Map<String, dynamic> toMap() => {
        'materialId': materialId,
        'qty': qty,
        'unit': unit,
        'issuedTo': issuedTo,
      };

  factory IssueNoteLine.fromMap(Map<String, dynamic> d) => IssueNoteLine(
        materialId: d['materialId'] ?? '',
        qty: (d['qty'] as num?)?.toDouble(),
        unit: d['unit'] ?? 'bag',
        issuedTo: d['issuedTo'],
      );
}

class IssueNote {
  final String issueNoteId;
  final DateTime? date;
  final List<IssueNoteLine> lines;
  final String? issuedBy;
  final List<String> notes;

  IssueNote({
    required this.issueNoteId,
    this.date,
    List<IssueNoteLine>? lines,
    this.issuedBy,
    List<String>? notes,
  })  : lines = lines ?? [],
        notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'issueNoteId': issueNoteId,
        'date': date?.toIso8601String(),
        'lines': lines.map((l) => l.toMap()).toList(),
        'issuedBy': issuedBy,
        'notes': notes,
      };

  factory IssueNote.fromMap(Map<String, dynamic> d) => IssueNote(
        issueNoteId: d['issueNoteId'] ?? '',
        date: d["date"] != null ? DateTime.tryParse(d["date"].toString()) : null,
        lines: (d['lines'] as List<dynamic>?)
                ?.map((l) => IssueNoteLine.fromMap(l))
                .toList() ??
            [],
        issuedBy: d['issuedBy'],
        notes: List<String>.from(d['notes'] ?? []),
      );
}

// --- Minimum Stock Alert ------------------------------------------------------
class MinStockAlert {
  final String materialId;
  final double minimumQty;
  final String unit;

  MinStockAlert(
      {required this.materialId, required this.minimumQty, this.unit = 'bag'});

  Map<String, dynamic> toMap() => {
        'materialId': materialId,
        'minimumQty': minimumQty,
        'unit': unit,
      };

  factory MinStockAlert.fromMap(Map<String, dynamic> d) => MinStockAlert(
        materialId: d['materialId'] ?? '',
        minimumQty: (d['minimumQty'] as num?)?.toDouble() ?? 0,
        unit: d['unit'] ?? 'bag',
      );
}

// --- Stock Adjustment --------------------------------------------------------
class StockAdjustment {
  final String adjustmentId;
  final DateTime? date;
  final String materialId;
  final String? brandId;
  final String? sizeId;
  final double? qtyBefore;
  final double? qtyAfter;
  double get difference => (qtyAfter ?? 0) - (qtyBefore ?? 0);
  final String reason; // 'Damage|Loss|Count Correction|Expiry|Other'
  final String? adjustedBy;
  final List<String> notes;

  StockAdjustment({
    required this.adjustmentId,
    this.date,
    required this.materialId,
    this.brandId,
    this.sizeId,
    this.qtyBefore,
    this.qtyAfter,
    this.reason = 'Count Correction',
    this.adjustedBy,
    List<String>? notes,
  }) : notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'adjustmentId': adjustmentId,
        'date': date?.toIso8601String(),
        'materialId': materialId,
        'brandId': brandId,
        'sizeId': sizeId,
        'qtyBefore': qtyBefore,
        'qtyAfter': qtyAfter,
        'reason': reason,
        'adjustedBy': adjustedBy,
        'notes': notes,
      };

  factory StockAdjustment.fromMap(Map<String, dynamic> d) => StockAdjustment(
        adjustmentId: d['adjustmentId'] ?? '',
        date: d['date'] != null ? DateTime.tryParse(d['date'].toString()) : null,
        materialId: d['materialId'] ?? '',
        brandId: d['brandId'],
        sizeId: d['sizeId'],
        qtyBefore: (d['qtyBefore'] as num?)?.toDouble(),
        qtyAfter: (d['qtyAfter'] as num?)?.toDouble(),
        reason: d['reason'] ?? 'Count Correction',
        adjustedBy: d['adjustedBy'],
        notes: List<String>.from(d['notes'] ?? []),
      );
}
