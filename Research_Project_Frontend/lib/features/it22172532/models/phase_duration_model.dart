class PhaseDurationModel {
  final String? id; // Mongo _id (string)
  final String pid;
  final String phaseId;
  final String phaseName;
  final int durationDays;
  final int laborCount;

  final String? createdAt;
  final String? updatedAt;

  const PhaseDurationModel({
    this.id,
    required this.pid,
    required this.phaseId,
    required this.phaseName,
    required this.durationDays,
    required this.laborCount,
    this.createdAt,
    this.updatedAt,
  });

  factory PhaseDurationModel.fromMap(Map<String, dynamic> map) {
    return PhaseDurationModel(
      id: (map['_id'] ?? map['id'])?.toString(),
      pid: (map['pid'] ?? '').toString(),
      phaseId: (map['phaseId'] ?? '').toString(),
      phaseName: (map['phaseName'] ?? '').toString(),
      durationDays: _toInt(map['durationDays']),
      laborCount: _toInt(map['laborCount']),
      createdAt: map['createdAt']?.toString(),
      updatedAt: map['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) '_id': id,
      'pid': pid,
      'phaseId': phaseId,
      'phaseName': phaseName,
      'durationDays': durationDays,
      'laborCount': laborCount,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}