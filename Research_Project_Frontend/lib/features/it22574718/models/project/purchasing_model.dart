
// --- Purchase Requisition -----------------------------------------------------
class PurchaseRequisition {
  final String prId;
  final DateTime? date;
  final String materialId;
  final double? qty;
  final String unit;
  final String? requestedBy;
  final String status; // 'Pending|Approved|Rejected'
  final List<String> notes;

  PurchaseRequisition({
    required this.prId,
    this.date,
    required this.materialId,
    this.qty,
    this.unit = 'bag',
    this.requestedBy,
    this.status = 'Pending',
    List<String>? notes,
  }) : notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'prId': prId,
        'date': date?.toIso8601String(),
        'materialId': materialId,
        'qty': qty,
        'unit': unit,
        'requestedBy': requestedBy,
        'status': status,
        'notes': notes,
      };

  factory PurchaseRequisition.fromMap(Map<String, dynamic> d) =>
      PurchaseRequisition(
        prId: d['prId'] ?? '',
        date: d["date"] != null ? DateTime.tryParse(d["date"].toString()) : null,
        materialId: d['materialId'] ?? '',
        qty: (d['qty'] as num?)?.toDouble(),
        unit: d['unit'] ?? 'bag',
        requestedBy: d['requestedBy'],
        status: d['status'] ?? 'Pending',
        notes: List<String>.from(d['notes'] ?? []),
      );
}

// --- Purchase Order Line ------------------------------------------------------
class POLine {
  final String materialId;
  final String? brandId;
  final String? sizeId;
  final double? qty;
  final String unit;
  final double? unitPrice;
  final double? lineTotal;

  POLine({
    required this.materialId,
    this.brandId,
    this.sizeId,
    this.qty,
    this.unit = 'bag',
    this.unitPrice,
    this.lineTotal,
  });

  Map<String, dynamic> toMap() => {
        'materialId': materialId,
        'brandId': brandId,
        'sizeId': sizeId,
        'qty': qty,
        'unit': unit,
        'unitPrice': unitPrice,
        'lineTotal': lineTotal ?? (qty ?? 0) * (unitPrice ?? 0),
      };

  factory POLine.fromMap(Map<String, dynamic> d) => POLine(
        materialId: d['materialId'] ?? '',
        brandId: d['brandId'],
        sizeId: d['sizeId'],
        qty: (d['qty'] as num?)?.toDouble(),
        unit: d['unit'] ?? 'bag',
        unitPrice: (d['unitPrice'] as num?)?.toDouble(),
        lineTotal: (d['lineTotal'] as num?)?.toDouble(),
      );
}

// --- Purchase Order -----------------------------------------------------------
class PurchaseOrder {
  final String poId;
  final DateTime? date;
  final String? supplierId;
  final List<POLine> lines;
  final double? totalAmount;
  final String status; // 'Draft|Sent|Partial|Received|Cancelled'
  final String? approvedBy;
  final List<String> notes;

  PurchaseOrder({
    required this.poId,
    this.date,
    this.supplierId,
    List<POLine>? lines,
    this.totalAmount,
    this.status = 'Draft',
    this.approvedBy,
    List<String>? notes,
  })  : lines = lines ?? [],
        notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'poId': poId,
        'date': date?.toIso8601String(),
        'supplierId': supplierId,
        'lines': lines.map((l) => l.toMap()).toList(),
        'totalAmount': totalAmount ??
            lines.fold<double>(0, (s, l) => s + ((l.lineTotal) ?? 0)),
        'status': status,
        'approvedBy': approvedBy,
        'notes': notes,
      };

  factory PurchaseOrder.fromMap(Map<String, dynamic> d) => PurchaseOrder(
        poId: d['poId'] ?? '',
        date: d["date"] != null ? DateTime.tryParse(d["date"].toString()) : null,
        supplierId: d['supplierId'],
        lines: (d['lines'] as List<dynamic>?)
                ?.map((l) => POLine.fromMap(l))
                .toList() ??
            [],
        totalAmount: (d['totalAmount'] as num?)?.toDouble(),
        status: d['status'] ?? 'Draft',
        approvedBy: d['approvedBy'],
        notes: List<String>.from(d['notes'] ?? []),
      );
}

// --- GRN (Goods Receipt Note) -------------------------------------------------
class GRNLine {
  final String materialId;
  final double? qtyOrdered;
  final double? qtyReceived;
  final String unit;

  GRNLine(
      {required this.materialId, this.qtyOrdered, this.qtyReceived, this.unit = 'bag'});

  Map<String, dynamic> toMap() => {
        'materialId': materialId,
        'qtyOrdered': qtyOrdered,
        'qtyReceived': qtyReceived,
        'unit': unit,
      };

  factory GRNLine.fromMap(Map<String, dynamic> d) => GRNLine(
        materialId: d['materialId'] ?? '',
        qtyOrdered: (d['qtyOrdered'] as num?)?.toDouble(),
        qtyReceived: (d['qtyReceived'] as num?)?.toDouble(),
        unit: d['unit'] ?? 'bag',
      );
}

class GRN {
  final String grnId;
  final DateTime? date;
  final String? poId;
  final String? supplierId;
  final List<GRNLine> lines;
  final String? receivedBy;
  final List<String> notes;

  GRN({
    required this.grnId,
    this.date,
    this.poId,
    this.supplierId,
    List<GRNLine>? lines,
    this.receivedBy,
    List<String>? notes,
  })  : lines = lines ?? [],
        notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'grnId': grnId,
        'date': date?.toIso8601String(),
        'poId': poId,
        'supplierId': supplierId,
        'lines': lines.map((l) => l.toMap()).toList(),
        'receivedBy': receivedBy,
        'notes': notes,
      };

  factory GRN.fromMap(Map<String, dynamic> d) => GRN(
        grnId: d['grnId'] ?? '',
        date: d["date"] != null ? DateTime.tryParse(d["date"].toString()) : null,
        poId: d['poId'],
        supplierId: d['supplierId'],
        lines: (d['lines'] as List<dynamic>?)
                ?.map((l) => GRNLine.fromMap(l))
                .toList() ??
            [],
        receivedBy: d['receivedBy'],
        notes: List<String>.from(d['notes'] ?? []),
      );
}

// --- Supplier Invoice ---------------------------------------------------------
class SupplierInvoice {
  final String invoiceId;
  final String? grnId;
  final String? supplierId;
  final DateTime? invoiceDate;
  final double? amount;
  final double? taxAmount;
  final double? totalPayable;
  final String status; // 'Unpaid|Partial|Paid'
  final List<String> notes;

  SupplierInvoice({
    required this.invoiceId,
    this.grnId,
    this.supplierId,
    this.invoiceDate,
    this.amount,
    this.taxAmount,
    this.totalPayable,
    this.status = 'Unpaid',
    List<String>? notes,
  }) : notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'invoiceId': invoiceId,
        'grnId': grnId,
        'supplierId': supplierId,
        'invoiceDate':
            invoiceDate?.toIso8601String(),
        'amount': amount,
        'taxAmount': taxAmount,
        'totalPayable': totalPayable,
        'status': status,
        'notes': notes,
      };

  factory SupplierInvoice.fromMap(Map<String, dynamic> d) => SupplierInvoice(
        invoiceId: d['invoiceId'] ?? '',
        grnId: d['grnId'],
        supplierId: d['supplierId'],
        invoiceDate: d["invoiceDate"] != null ? DateTime.tryParse(d["invoiceDate"].toString()) : null,
        amount: (d['amount'] as num?)?.toDouble(),
        taxAmount: (d['taxAmount'] as num?)?.toDouble(),
        totalPayable: (d['totalPayable'] as num?)?.toDouble(),
        status: d['status'] ?? 'Unpaid',
        notes: List<String>.from(d['notes'] ?? []),
      );
}

// --- Payment ------------------------------------------------------------------
class PaymentRecord {
  final String paymentId;
  final String? invoiceId;
  final String? supplierId;
  final DateTime? date;
  final double? amount;
  final String paymentMethod; // 'Cash|Bank Transfer|Cheque'
  final String? reference;
  final List<String> notes;

  PaymentRecord({
    required this.paymentId,
    this.invoiceId,
    this.supplierId,
    this.date,
    this.amount,
    this.paymentMethod = 'Cash',
    this.reference,
    List<String>? notes,
  }) : notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'paymentId': paymentId,
        'invoiceId': invoiceId,
        'supplierId': supplierId,
        'date': date?.toIso8601String(),
        'amount': amount,
        'paymentMethod': paymentMethod,
        'reference': reference,
        'notes': notes,
      };

  factory PaymentRecord.fromMap(Map<String, dynamic> d) => PaymentRecord(
        paymentId: d['paymentId'] ?? '',
        invoiceId: d['invoiceId'],
        supplierId: d['supplierId'],
        date: d["date"] != null ? DateTime.tryParse(d["date"].toString()) : null,
        amount: (d['amount'] as num?)?.toDouble(),
        paymentMethod: d['paymentMethod'] ?? 'Cash',
        reference: d['reference'],
        notes: List<String>.from(d['notes'] ?? []),
      );
}
