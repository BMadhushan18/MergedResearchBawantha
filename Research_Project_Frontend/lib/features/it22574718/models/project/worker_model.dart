// --- Worker (Labour) ---------------------------------------------------------
class WorkerModel {
  final String workerId;
  final String? name;
  final String tradeId;
  final String? phone;
  final String? nicId;
  final double? dailyRateOverride;
  final List<String> notes;

  WorkerModel({
    required this.workerId,
    this.name,
    this.tradeId = 'LAB-HELP',
    this.phone,
    this.nicId,
    this.dailyRateOverride,
    List<String>? notes,
  }) : notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'workerId': workerId,
        'name': name,
        'tradeId': tradeId,
        'phone': phone,
        'nicId': nicId,
        'dailyRateOverride': dailyRateOverride,
        'notes': notes,
      };

  factory WorkerModel.fromMap(Map<String, dynamic> d) => WorkerModel(
        workerId: d['workerId'] ?? '',
        name: d['name'],
        tradeId: d['tradeId'] ?? 'LAB-HELP',
        phone: d['phone'],
        nicId: d['nicId'],
        dailyRateOverride: (d['dailyRateOverride'] as num?)?.toDouble(),
        notes: List<String>.from(d['notes'] ?? []),
      );
}
