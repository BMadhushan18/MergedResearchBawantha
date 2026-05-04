
// --- Attendance Entry ---------------------------------------------------------
class AttendanceEntry {
  final String workerId;
  final String tradeId;
  final bool present;
  final double? hours;
  final double? otHours;

  AttendanceEntry({
    required this.workerId,
    required this.tradeId,
    this.present = true,
    this.hours,
    this.otHours,
  });

  Map<String, dynamic> toMap() => {
        'workerId': workerId,
        'tradeId': tradeId,
        'present': present,
        'hours': hours,
        'otHours': otHours,
      };

  factory AttendanceEntry.fromMap(Map<String, dynamic> d) => AttendanceEntry(
        workerId: d['workerId'] ?? '',
        tradeId: d['tradeId'] ?? '',
        present: d['present'] ?? true,
        hours: (d['hours'] as num?)?.toDouble(),
        otHours: (d['otHours'] as num?)?.toDouble(),
      );
}

// --- Daily Attendance ---------------------------------------------------------
// One document per date. docId = 'YYYY-MM-DD'
class DailyAttendance {
  final DateTime date;
  final List<AttendanceEntry> entries;

  DailyAttendance({required this.date, List<AttendanceEntry>? entries})
      : entries = entries ?? [];

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'entries': entries.map((e) => e.toMap()).toList(),
      };

  factory DailyAttendance.fromMap(Map<String, dynamic> d) => DailyAttendance(
        date: (DateTime.tryParse(d["date"].toString()) ?? DateTime.now()),
        entries: (d['entries'] as List<dynamic>?)
                ?.map((e) => AttendanceEntry.fromMap(e))
                .toList() ??
            [],
      );
}

// --- Work Allocation ---------------------------------------------------------
class WorkAllocation {
  final String allocationId;
  final DateTime? date;
  final String task;
  final List<String> workerIds;
  final double? plannedOutput;
  final double? actualOutput;
  final List<String> notes;

  WorkAllocation({
    required this.allocationId,
    this.date,
    required this.task,
    List<String>? workerIds,
    this.plannedOutput,
    this.actualOutput,
    List<String>? notes,
  })  : workerIds = workerIds ?? [],
        notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'allocationId': allocationId,
        'date': date?.toIso8601String(),
        'task': task,
        'workerIds': workerIds,
        'plannedOutput': plannedOutput,
        'actualOutput': actualOutput,
        'notes': notes,
      };

  factory WorkAllocation.fromMap(Map<String, dynamic> d) => WorkAllocation(
        allocationId: d['allocationId'] ?? '',
        date: d["date"] != null ? DateTime.tryParse(d["date"].toString()) : null,
        task: d['task'] ?? '',
        workerIds: List<String>.from(d['workerIds'] ?? []),
        plannedOutput: (d['plannedOutput'] as num?)?.toDouble(),
        actualOutput: (d['actualOutput'] as num?)?.toDouble(),
        notes: List<String>.from(d['notes'] ?? []),
      );
}
