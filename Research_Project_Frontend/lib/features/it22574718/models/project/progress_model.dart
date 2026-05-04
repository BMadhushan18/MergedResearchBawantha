
// ─── Progress Update ──────────────────────────────────────────────────────────
class ProgressUpdate {
  final String progressId;
  final DateTime? date;
  final String? activity;    // description of work performed
  final String? location;    // site area / element
  final String? boqItemId;
  final double? plannedQty;
  final double? executedQty;
  final double? percentComplete;
  final String? notes;       // free-form remarks
  final List<String> photos; // URLs

  ProgressUpdate({
    required this.progressId,
    this.date,
    this.activity,
    this.location,
    this.boqItemId,
    this.plannedQty,
    this.executedQty,
    this.percentComplete,
    this.notes,
    List<String>? photos,
  }) : photos = photos ?? [];

  Map<String, dynamic> toMap() => {
        'progressId': progressId,
        'date': date?.toIso8601String(),
        'activity': activity,
        'location': location,
        'boqItemId': boqItemId,
        'plannedQty': plannedQty,
        'executedQty': executedQty,
        'percentComplete': percentComplete,
        'notes': notes,
        'photos': photos,
      };

  factory ProgressUpdate.fromMap(Map<String, dynamic> d) => ProgressUpdate(
        progressId: d['progressId'] ?? '',
        date: d["date"] != null ? DateTime.tryParse(d["date"].toString()) : null,
        activity: d['activity'],
        location: d['location'],
        boqItemId: d['boqItemId'],
        plannedQty: (d['plannedQty'] as num?)?.toDouble(),
        executedQty: (d['executedQty'] as num?)?.toDouble(),
        percentComplete: (d['percentComplete'] as num?)?.toDouble(),
        notes: d['notes'],
        photos: List<String>.from(d['photos'] ?? []),
      );
}

// ─── IPC Line ─────────────────────────────────────────────────────────────────
class IPCLine {
  final String? boqItemId;
  final double? executedQty;
  final double? rate;
  final double? amount;

  IPCLine({this.boqItemId, this.executedQty, this.rate, this.amount});

  Map<String, dynamic> toMap() => {
        'boqItemId': boqItemId,
        'executedQty': executedQty,
        'rate': rate,
        'amount': amount ?? (executedQty ?? 0) * (rate ?? 0),
      };

  factory IPCLine.fromMap(Map<String, dynamic> d) => IPCLine(
        boqItemId: d['boqItemId'],
        executedQty: (d['executedQty'] as num?)?.toDouble(),
        rate: (d['rate'] as num?)?.toDouble(),
        amount: (d['amount'] as num?)?.toDouble(),
      );
}

// ─── Interim Payment Certificate ──────────────────────────────────────────────
class IPC {
  final String ipcId;
  final String? period; // e.g. '2026-02'
  final List<IPCLine> items;
  final double? retentionPercent;
  final double? advanceRecovery;
  final double? totalPayable;
  final String? approvedBy;
  final DateTime? approvedDate;

  IPC({
    required this.ipcId,
    this.period,
    List<IPCLine>? items,
    this.retentionPercent,
    this.advanceRecovery,
    this.totalPayable,
    this.approvedBy,
    this.approvedDate,
  }) : items = items ?? [];

  Map<String, dynamic> toMap() => {
        'ipcId': ipcId,
        'period': period,
        'items': items.map((i) => i.toMap()).toList(),
        'retentionPercent': retentionPercent,
        'advanceRecovery': advanceRecovery,
        'totalPayable': totalPayable,
        'approvedBy': approvedBy,
        'approvedDate': approvedDate?.toIso8601String(),
      };

  factory IPC.fromMap(Map<String, dynamic> d) => IPC(
        ipcId: d['ipcId'] ?? '',
        period: d['period'],
        items: (d['items'] as List<dynamic>?)
                ?.map((i) => IPCLine.fromMap(i))
                .toList() ??
            [],
        retentionPercent: (d['retentionPercent'] as num?)?.toDouble(),
        advanceRecovery: (d['advanceRecovery'] as num?)?.toDouble(),
        totalPayable: (d['totalPayable'] as num?)?.toDouble(),
        approvedBy: d['approvedBy'],
        approvedDate: d["approvedDate"] != null ? DateTime.tryParse(d["approvedDate"].toString()) : null,
      );
}
