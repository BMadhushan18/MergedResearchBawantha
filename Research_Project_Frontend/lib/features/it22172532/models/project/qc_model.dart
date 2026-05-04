// ─── QC Checklist Item ────────────────────────────────────────────────────────
class QCCheckItem {
  final String point;
  final String status; // 'Pass|Fail|NA'
  final String? remarks;

  QCCheckItem({required this.point, this.status = 'NA', this.remarks});

  Map<String, dynamic> toMap() =>
      {'point': point, 'status': status, 'remarks': remarks};

  factory QCCheckItem.fromMap(Map<String, dynamic> d) => QCCheckItem(
        point: d['point'] ?? '',
        status: d['status'] ?? 'NA',
        remarks: d['remarks'],
      );
}

// ─── QC Checklist ────────────────────────────────────────────────────────────
class QCChecklist {
  final String checklistId;
  final String name;
  final List<QCCheckItem> items;
  final DateTime? inspectedDate;
  final String? inspectedBy;
  final List<String> notes;

  QCChecklist({
    required this.checklistId,
    required this.name,
    List<QCCheckItem>? items,
    this.inspectedDate,
    this.inspectedBy,
    List<String>? notes,
  })  : items = items ?? [],
        notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'checklistId': checklistId,
        'name': name,
        'items': items.map((i) => i.toMap()).toList(),
        'inspectedDate': inspectedDate?.toIso8601String(),
        'inspectedBy': inspectedBy,
        'notes': notes,
      };

  factory QCChecklist.fromMap(Map<String, dynamic> d) => QCChecklist(
        checklistId: d['checklistId'] ?? '',
        name: d['name'] ?? '',
        items: (d['items'] as List<dynamic>?)
                ?.map((i) => QCCheckItem.fromMap(i))
                .toList() ??
            [],
        inspectedDate: d['inspectedDate'] != null
            ? DateTime.tryParse(d['inspectedDate'].toString())
            : null,
        inspectedBy: d['inspectedBy'],
        notes: List<String>.from(d['notes'] ?? []),
      );

  // Template factory
  static QCChecklist rebarTemplate() => QCChecklist(
        checklistId: 'QC-REBAR-001',
        name: 'Rebar Before Concrete',
        items: [
          QCCheckItem(point: 'Bar diameter matches drawing'),
          QCCheckItem(point: 'Cover blocks provided'),
          QCCheckItem(point: 'Lap lengths correct'),
          QCCheckItem(point: 'No rust or contamination'),
        ],
      );
}

// ─── NCR (Non-Conformance Report) ────────────────────────────────────────────
class NCReport {
  final String ncrId;
  final DateTime? date;
  final String description;
  final String? location;
  final String status; // 'Open|Closed'
  final String? closedDate;
  final List<String> notes;

  NCReport({
    required this.ncrId,
    this.date,
    required this.description,
    this.location,
    this.status = 'Open',
    this.closedDate,
    List<String>? notes,
  }) : notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'ncrId': ncrId,
        'date': date?.toIso8601String(),
        'description': description,
        'location': location,
        'status': status,
        'closedDate': closedDate,
        'notes': notes,
      };

  factory NCReport.fromMap(Map<String, dynamic> d) => NCReport(
        ncrId: d['ncrId'] ?? '',
        date: d['date'] != null ? DateTime.tryParse(d['date'].toString()) : null,
        description: d['description'] ?? '',
        location: d['location'],
        status: d['status'] ?? 'Open',
        closedDate: d['closedDate'],
        notes: List<String>.from(d['notes'] ?? []),
      );
}
