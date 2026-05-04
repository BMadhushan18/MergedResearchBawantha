
// --- Material Carried (in a trip) ---------------------------------------------
class MaterialCarried {
  final String materialId;
  final double? qty;
  final String unit;

  MaterialCarried({required this.materialId, this.qty, this.unit = 'bag'});

  Map<String, dynamic> toMap() =>
      {'materialId': materialId, 'qty': qty, 'unit': unit};

  factory MaterialCarried.fromMap(Map<String, dynamic> d) => MaterialCarried(
        materialId: d['materialId'] ?? '',
        qty: (d['qty'] as num?)?.toDouble(),
        unit: d['unit'] ?? 'bag',
      );
}

// --- Trip --------------------------------------------------------------------
class TripModel {
  final String tripId;
  final DateTime? date;
  final String? vehicleId;
  final String? supplierId;
  final String? from;
  final String to;
  final List<MaterialCarried> materialCarried;
  final String? driverName;
  final double? fuelUsedLtr;
  final double? tripCost;
  final List<String> notes;

  TripModel({
    required this.tripId,
    this.date,
    this.vehicleId,
    this.supplierId,
    this.from,
    this.to = 'Site',
    List<MaterialCarried>? materialCarried,
    this.driverName,
    this.fuelUsedLtr,
    this.tripCost,
    List<String>? notes,
  })  : materialCarried = materialCarried ?? [],
        notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'tripId': tripId,
        'date': date?.toIso8601String(),
        'vehicleId': vehicleId,
        'supplierId': supplierId,
        'from': from,
        'to': to,
        'materialCarried': materialCarried.map((m) => m.toMap()).toList(),
        'driverName': driverName,
        'fuelUsedLtr': fuelUsedLtr,
        'tripCost': tripCost,
        'notes': notes,
      };

  factory TripModel.fromMap(Map<String, dynamic> d) => TripModel(
        tripId: d['tripId'] ?? '',
        date: d["date"] != null ? DateTime.tryParse(d["date"].toString()) : null,
        vehicleId: d['vehicleId'],
        supplierId: d['supplierId'],
        from: d['from'],
        to: d['to'] ?? 'Site',
        materialCarried: (d['materialCarried'] as List<dynamic>?)
                ?.map((m) => MaterialCarried.fromMap(m))
                .toList() ??
            [],
        driverName: d['driverName'],
        fuelUsedLtr: (d['fuelUsedLtr'] as num?)?.toDouble(),
        tripCost: (d['tripCost'] as num?)?.toDouble(),
        notes: List<String>.from(d['notes'] ?? []),
      );
}
