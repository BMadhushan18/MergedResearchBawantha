// --- Hire Rate ---------------------------------------------------------------
class HireRate {
  final String rateType; // 'Per Trip|Per Day|Per Hour|Per km'
  final double? rate;

  HireRate({this.rateType = 'Per Trip', this.rate});

  Map<String, dynamic> toMap() => {'rateType': rateType, 'rate': rate};

  factory HireRate.fromMap(Map<String, dynamic> d) =>
      HireRate(rateType: d['rateType'] ?? 'Per Trip',
          rate: (d['rate'] as num?)?.toDouble());
}

// --- Vehicle -----------------------------------------------------------------
class VehicleModel {
  final String vehicleId;
  final String vehicleType; // 'Tipper|Concrete Mixer|Truck|Backhoe|JCB|Crane|Water Bowser'
  final String? plateNumber;
  final String owner; // 'Company|Hired'
  final String? supplierId;
  final double? capacity;
  final String capacityUnit; // 'm3|tons|ltr'
  final String? driverName;
  final String? driverPhone;
  final HireRate hireRate;
  final List<String> notes;

  VehicleModel({
    required this.vehicleId,
    this.vehicleType = 'Tipper',
    this.plateNumber,
    this.owner = 'Hired',
    this.supplierId,
    this.capacity,
    this.capacityUnit = 'm3',
    this.driverName,
    this.driverPhone,
    HireRate? hireRate,
    List<String>? notes,
  })  : hireRate = hireRate ?? HireRate(),
        notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'vehicleId': vehicleId,
        'vehicleType': vehicleType,
        'plateNumber': plateNumber,
        'owner': owner,
        'supplierId': supplierId,
        'capacity': capacity,
        'capacityUnit': capacityUnit,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'hireRate': hireRate.toMap(),
        'notes': notes,
      };

  factory VehicleModel.fromMap(Map<String, dynamic> d) => VehicleModel(
        vehicleId: d['vehicleId'] ?? '',
        vehicleType: d['vehicleType'] ?? 'Tipper',
        plateNumber: d['plateNumber'],
        owner: d['owner'] ?? 'Hired',
        supplierId: d['supplierId'],
        capacity: (d['capacity'] as num?)?.toDouble(),
        capacityUnit: d['capacityUnit'] ?? 'm3',
        driverName: d['driverName'],
        driverPhone: d['driverPhone'],
        hireRate: d['hireRate'] != null ? HireRate.fromMap(d['hireRate']) : null,
        notes: List<String>.from(d['notes'] ?? []),
      );
}
