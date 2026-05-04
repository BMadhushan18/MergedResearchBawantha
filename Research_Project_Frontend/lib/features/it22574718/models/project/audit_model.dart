
// ─── Audit Modules Enum ──────────────────────────────────────────────────────
enum AuditModule {
  project,
  material,
  supplier,
  vehicle,
  worker,
  equipment,
  price,
  boq,
  purchasing,
  stock,
  transport,
  labour,
  progress,
  qc,
  safety,
}

extension AuditModuleExt on AuditModule {
  String get value => toString().split('.').last;
  static AuditModule fromString(String s) =>
      AuditModule.values.firstWhere(
        (e) => e.value == s,
        orElse: () => AuditModule.project,
      );
}

// ─── Audit Log Entry ──────────────────────────────────────────────────────────
class AuditLog {
  final String logId;
  final DateTime dateTime;
  final String userId;
  final String userName;
  final AuditModule module;
  final String action; // 'Create|Update|Delete|View'
  final String recordId; // ID of the affected document
  final String? recordRef; // human-readable reference (e.g. "PO-001")
  final Map<String, dynamic>? before; // snapshot before change
  final Map<String, dynamic>? after; // snapshot after change
  final String? reason;

  AuditLog({
    required this.logId,
    required this.dateTime,
    required this.userId,
    required this.userName,
    required this.module,
    required this.action,
    required this.recordId,
    this.recordRef,
    this.before,
    this.after,
    this.reason,
  });

  Map<String, dynamic> toMap() => {
        'logId': logId,
        'dateTime': dateTime.toIso8601String(),
        'userId': userId,
        'userName': userName,
        'module': module.value,
        'action': action,
        'recordId': recordId,
        'recordRef': recordRef,
        'before': before,
        'after': after,
        'reason': reason,
      };

  factory AuditLog.fromMap(Map<String, dynamic> d) => AuditLog(
        logId: d['logId'] ?? '',
        dateTime:
            d["dateTime"] != null ? (DateTime.tryParse(d["dateTime"].toString()) ?? DateTime.now()) : DateTime.now(),
        userId: d['userId'] ?? '',
        userName: d['userName'] ?? '',
        module: AuditModuleExt.fromString(d['module'] ?? ''),
        action: d['action'] ?? 'Update',
        recordId: d['recordId'] ?? '',
        recordRef: d['recordRef'],
        before: d['before'] != null
            ? Map<String, dynamic>.from(d['before'])
            : null,
        after: d['after'] != null
            ? Map<String, dynamic>.from(d['after'])
            : null,
        reason: d['reason'],
      );

  /// Factory for quick Create-type log entry
  factory AuditLog.create({
    required String logId,
    required String userId,
    required String userName,
    required AuditModule module,
    required String recordId,
    String? recordRef,
    Map<String, dynamic>? after,
    String? reason,
  }) =>
      AuditLog(
        logId: logId,
        dateTime: DateTime.now(),
        userId: userId,
        userName: userName,
        module: module,
        action: 'Create',
        recordId: recordId,
        recordRef: recordRef,
        after: after,
        reason: reason,
      );

  /// Factory for quick Update-type log entry
  factory AuditLog.update({
    required String logId,
    required String userId,
    required String userName,
    required AuditModule module,
    required String recordId,
    String? recordRef,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    String? reason,
  }) =>
      AuditLog(
        logId: logId,
        dateTime: DateTime.now(),
        userId: userId,
        userName: userName,
        module: module,
        action: 'Update',
        recordId: recordId,
        recordRef: recordRef,
        before: before,
        after: after,
        reason: reason,
      );
}
