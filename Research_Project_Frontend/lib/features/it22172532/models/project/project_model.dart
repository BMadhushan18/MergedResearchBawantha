
// ─── Project (root document) ───────────────────────────────────────────────
class ProjectModel {
  final String projectId;
  final String? projectName;
  final String? client;
  final String? location;
  final String currency;
  final String units;
  final DateTime? createdDate;
  final DateTime? lastUpdated;
  final List<String> notes;

  // Embedded config sections
  final PriceRules priceRules;
  final BOQRules boqRules;
  final List<LabourTrade> labourTrades;
  final List<DefaultDailyRate> defaultDailyRates;
  final List<FuelType> fuelTypes;
  final BaselinePlan baselinePlan;

  // Firestore owner
  final String ownerUid;
  final String? threeJsHtml;

  ProjectModel({
    required this.projectId,
    this.projectName,
    this.client,
    this.location,
    this.currency = 'LKR',
    this.units = 'Metric',
    this.createdDate,
    this.lastUpdated,
    List<String>? notes,
    PriceRules? priceRules,
    BOQRules? boqRules,
    List<LabourTrade>? labourTrades,
    List<DefaultDailyRate>? defaultDailyRates,
    List<FuelType>? fuelTypes,
    BaselinePlan? baselinePlan,
    required this.ownerUid,
    this.threeJsHtml,
  })  : notes = notes ?? [],
        priceRules = priceRules ?? PriceRules(),
        boqRules = boqRules ?? BOQRules(),
        labourTrades = labourTrades ?? _defaultTrades(),
        defaultDailyRates = defaultDailyRates ?? [],
        fuelTypes = fuelTypes ?? _defaultFuelTypes(),
        baselinePlan = baselinePlan ?? BaselinePlan();

  static List<LabourTrade> _defaultTrades() => [
        LabourTrade(tradeId: 'LAB-MASON', tradeName: 'Mason'),
        LabourTrade(tradeId: 'LAB-CARP', tradeName: 'Carpenter'),
        LabourTrade(tradeId: 'LAB-STEEL', tradeName: 'Steel Fixer'),
        LabourTrade(tradeId: 'LAB-PAINT', tradeName: 'Painter'),
        LabourTrade(tradeId: 'LAB-HELP', tradeName: 'Helper'),
      ];

  static List<FuelType> _defaultFuelTypes() => [
        FuelType(
            fuelId: 'FUEL-DIESEL',
            name: 'Diesel',
            unit: 'ltr',
            latestUnitPrice: null,
            lastUpdated: null),
      ];

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'projectName': projectName,
        'client': client,
        'location': location,
        'currency': currency,
        'units': units,
        'createdDate':
            createdDate?.toIso8601String(),
        'lastUpdated':
            lastUpdated?.toIso8601String(),
        'notes': notes,
        'priceRules': priceRules.toMap(),
        'boqRules': boqRules.toMap(),
        'labourTrades': labourTrades.map((t) => t.toMap()).toList(),
        'defaultDailyRates': defaultDailyRates.map((r) => r.toMap()).toList(),
        'fuelTypes': fuelTypes.map((f) => f.toMap()).toList(),
        'baselinePlan': baselinePlan.toMap(),
        'ownerUid': ownerUid,
      'threeJsHtml': threeJsHtml,
      };

  factory ProjectModel.fromMap(String id, Map<String, dynamic> data) =>
      ProjectModel(
        projectId: id,
        projectName: data['projectName'],
        client: data['client'],
        location: data['location'],
        currency: data['currency'] ?? 'LKR',
        units: data['units'] ?? 'Metric',
        createdDate: data['createdDate'] != null ? DateTime.tryParse(data['createdDate'].toString()) : null,
        lastUpdated: data['lastUpdated'] != null ? DateTime.tryParse(data['lastUpdated'].toString()) : null,
        notes: List<String>.from(data['notes'] ?? []),
        priceRules: data['priceRules'] != null
            ? PriceRules.fromMap(data['priceRules'])
            : null,
        boqRules: data['boqRules'] != null
            ? BOQRules.fromMap(data['boqRules'])
            : null,
        labourTrades: (data['labourTrades'] as List<dynamic>?)
                ?.map((t) => LabourTrade.fromMap(t))
                .toList() ??
            _defaultTrades(),
        defaultDailyRates: (data['defaultDailyRates'] as List<dynamic>?)
                ?.map((r) => DefaultDailyRate.fromMap(r))
                .toList() ??
            [],
        fuelTypes: (data['fuelTypes'] as List<dynamic>?)
                ?.map((f) => FuelType.fromMap(f))
                .toList() ??
            _defaultFuelTypes(),
        baselinePlan: data['baselinePlan'] != null
            ? BaselinePlan.fromMap(data['baselinePlan'])
            : null,
        ownerUid: data['ownerUid'] ?? '',
      threeJsHtml: data['threeJsHtml'],
      );

  ProjectModel copyWith({
    String? projectName,
    String? client,
    String? location,
    String? currency,
    String? units,
    String? notes,
    String? threeJsHtml,
  }) =>
      ProjectModel(
        projectId: projectId,
        projectName: projectName ?? this.projectName,
        client: client ?? this.client,
        location: location ?? this.location,
        currency: currency ?? this.currency,
        units: units ?? this.units,
        createdDate: createdDate,
        lastUpdated: DateTime.now(),
        priceRules: priceRules,
        boqRules: boqRules,
        labourTrades: labourTrades,
        defaultDailyRates: defaultDailyRates,
        fuelTypes: fuelTypes,
        baselinePlan: baselinePlan,
        ownerUid: ownerUid,
      threeJsHtml: threeJsHtml ?? this.threeJsHtml,
      );
}

// ─── Price Rules ──────────────────────────────────────────────────────────
class PriceRules {
  final String defaultPricingMode;
  final double? taxPercent;
  final String transportAddOnMode;
  final String roundingRule;

  PriceRules({
    this.defaultPricingMode = 'Use Latest Store Price',
    this.taxPercent,
    this.transportAddOnMode = 'Separate',
    this.roundingRule = '2 decimals',
  });

  Map<String, dynamic> toMap() => {
        'defaultPricingMode': defaultPricingMode,
        'taxPercent': taxPercent,
        'transportAddOnMode': transportAddOnMode,
        'roundingRule': roundingRule,
      };

  factory PriceRules.fromMap(Map<String, dynamic> d) => PriceRules(
        defaultPricingMode:
            d['defaultPricingMode'] ?? 'Use Latest Store Price',
        taxPercent: (d['taxPercent'] as num?)?.toDouble(),
        transportAddOnMode: d['transportAddOnMode'] ?? 'Separate',
        roundingRule: d['roundingRule'] ?? '2 decimals',
      );
}

// ─── BOQ Rules ────────────────────────────────────────────────────────────
class BOQRules {
  final double defaultWastagePercent;
  final bool deductOpenings;
  final int qtyRound;
  final int amountRound;

  BOQRules({
    this.defaultWastagePercent = 5,
    this.deductOpenings = true,
    this.qtyRound = 2,
    this.amountRound = 2,
  });

  Map<String, dynamic> toMap() => {
        'defaultWastagePercent': defaultWastagePercent,
        'deductOpenings': deductOpenings,
        'qtyRound': qtyRound,
        'amountRound': amountRound,
      };

  factory BOQRules.fromMap(Map<String, dynamic> d) => BOQRules(
        defaultWastagePercent:
            (d['defaultWastagePercent'] as num?)?.toDouble() ?? 5,
        deductOpenings: d['deductOpenings'] ?? true,
        qtyRound: d['qtyRound'] ?? 2,
        amountRound: d['amountRound'] ?? 2,
      );
}

// ─── Labour Trade ─────────────────────────────────────────────────────────
class LabourTrade {
  final String tradeId;
  final String tradeName;

  LabourTrade({required this.tradeId, required this.tradeName});

  Map<String, dynamic> toMap() => {'tradeId': tradeId, 'tradeName': tradeName};

  factory LabourTrade.fromMap(Map<String, dynamic> d) =>
      LabourTrade(tradeId: d['tradeId'] ?? '', tradeName: d['tradeName'] ?? '');
}

// ─── Default Daily Rate ───────────────────────────────────────────────────
class DefaultDailyRate {
  final String tradeId;
  final double? rate;
  final DateTime? lastUpdated;

  DefaultDailyRate(
      {required this.tradeId, this.rate, this.lastUpdated});

  Map<String, dynamic> toMap() => {
        'tradeId': tradeId,
        'rate': rate,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  factory DefaultDailyRate.fromMap(Map<String, dynamic> d) => DefaultDailyRate(
        tradeId: d['tradeId'] ?? '',
        rate: (d['rate'] as num?)?.toDouble(),
        lastUpdated: d["lastUpdated"] != null ? DateTime.tryParse(d["lastUpdated"].toString()) : null,
      );
}

// ─── Fuel Type ────────────────────────────────────────────────────────────
class FuelType {
  final String fuelId;
  final String name;
  final String unit;
  final double? latestUnitPrice;
  final DateTime? lastUpdated;

  FuelType({
    required this.fuelId,
    required this.name,
    this.unit = 'ltr',
    this.latestUnitPrice,
    this.lastUpdated,
  });

  Map<String, dynamic> toMap() => {
        'fuelId': fuelId,
        'name': name,
        'unit': unit,
        'latestUnitPrice': latestUnitPrice,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  factory FuelType.fromMap(Map<String, dynamic> d) => FuelType(
        fuelId: d['fuelId'] ?? '',
        name: d['name'] ?? '',
        unit: d['unit'] ?? 'ltr',
        latestUnitPrice: (d['latestUnitPrice'] as num?)?.toDouble(),
        lastUpdated: d["lastUpdated"] != null ? DateTime.tryParse(d["lastUpdated"].toString()) : null,
      );
}

// ─── Baseline Plan ─────────────────────────────────────────────────────────
class Milestone {
  final String name;
  final DateTime? targetDate;
  final bool completed;

  Milestone({required this.name, this.targetDate, this.completed = false});

  Map<String, dynamic> toMap() => {
        'name': name,
        'targetDate':
            targetDate?.toIso8601String(),
        'completed': completed,
      };

  factory Milestone.fromMap(Map<String, dynamic> d) => Milestone(
        name: d['name'] ?? '',
        targetDate: d["targetDate"] != null ? DateTime.tryParse(d["targetDate"].toString()) : null,
        completed: d['completed'] ?? false,
      );
}

class BaselinePlan {
  final DateTime? startDate;
  final DateTime? targetFinishDate;
  final List<Milestone> milestones;

  BaselinePlan(
      {this.startDate,
      this.targetFinishDate,
      List<Milestone>? milestones})
      : milestones = milestones ?? [];

  Map<String, dynamic> toMap() => {
        'startDate':
            startDate?.toIso8601String(),
        'targetFinishDate': targetFinishDate?.toIso8601String(),
        'milestones': milestones.map((m) => m.toMap()).toList(),
      };

  factory BaselinePlan.fromMap(Map<String, dynamic> d) => BaselinePlan(
        startDate: d["startDate"] != null ? DateTime.tryParse(d["startDate"].toString()) : null,
        targetFinishDate: d["targetFinishDate"] != null ? DateTime.tryParse(d["targetFinishDate"].toString()) : null,
        milestones: (d['milestones'] as List<dynamic>?)
                ?.map((m) => Milestone.fromMap(m))
                .toList() ??
            [],
      );
}
