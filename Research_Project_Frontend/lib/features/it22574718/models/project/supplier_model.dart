// --- Hardware Store ----------------------------------------------------------
class HardwareStore {
  final String storeId;
  final String? storeName;
  final String? phone;
  final String? address;
  final String? contactPerson;
  final List<String> notes;

  HardwareStore({
    required this.storeId,
    this.storeName,
    this.phone,
    this.address,
    this.contactPerson,
    List<String>? notes,
  }) : notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'storeId': storeId,
        'storeName': storeName,
        'phone': phone,
        'address': address,
        'contactPerson': contactPerson,
        'notes': notes,
      };

  factory HardwareStore.fromMap(Map<String, dynamic> d) => HardwareStore(
        storeId: d['storeId'] ?? '',
        storeName: d['storeName'],
        phone: d['phone'],
        address: d['address'],
        contactPerson: d['contactPerson'],
        notes: List<String>.from(d['notes'] ?? []),
      );
}

// --- Payment Terms -----------------------------------------------------------
class PaymentTerms {
  final int? creditDays;
  final double? advancePercent;

  PaymentTerms({this.creditDays, this.advancePercent});

  Map<String, dynamic> toMap() =>
      {'creditDays': creditDays, 'advancePercent': advancePercent};

  factory PaymentTerms.fromMap(Map<String, dynamic> d) => PaymentTerms(
        creditDays: d['creditDays'],
        advancePercent: (d['advancePercent'] as num?)?.toDouble(),
      );
}

// --- Supplier ----------------------------------------------------------------
enum SupplierType {
  hardwareStore,
  directSupplier,
  transport,
  labourSubcontractor
}

class SupplierModel {
  final String supplierId;
  final String? supplierName;
  final String supplierType; // 'Hardware Store|Direct Supplier|Transport|Labour Subcontractor'
  final String? phone;
  final String? email;
  final String? address;
  final String? relatedStoreId;
  final PaymentTerms paymentTerms;
  final List<String> notes;

  SupplierModel({
    required this.supplierId,
    this.supplierName,
    this.supplierType = 'Direct Supplier',
    this.phone,
    this.email,
    this.address,
    this.relatedStoreId,
    PaymentTerms? paymentTerms,
    List<String>? notes,
  })  : paymentTerms = paymentTerms ?? PaymentTerms(),
        notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'supplierId': supplierId,
        'supplierName': supplierName,
        'supplierType': supplierType,
        'phone': phone,
        'email': email,
        'address': address,
        'relatedStoreId': relatedStoreId,
        'paymentTerms': paymentTerms.toMap(),
        'notes': notes,
      };

  factory SupplierModel.fromMap(Map<String, dynamic> d) => SupplierModel(
        supplierId: d['supplierId'] ?? '',
        supplierName: d['supplierName'],
        supplierType: d['supplierType'] ?? 'Direct Supplier',
        phone: d['phone'],
        email: d['email'],
        address: d['address'],
        relatedStoreId: d['relatedStoreId'],
        paymentTerms: d['paymentTerms'] != null
            ? PaymentTerms.fromMap(d['paymentTerms'])
            : null,
        notes: List<String>.from(d['notes'] ?? []),
      );
}
