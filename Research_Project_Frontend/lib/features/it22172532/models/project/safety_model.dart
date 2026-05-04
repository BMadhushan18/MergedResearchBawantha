
// --- Toolbox Meeting ----------------------------------------------------------
class ToolboxMeeting {
  final String meetingId;
  final DateTime? date;
  final String topic;
  final List<String> attendees;
  final String? conductedBy;
  final List<String> notes;

  ToolboxMeeting({
    required this.meetingId,
    this.date,
    required this.topic,
    List<String>? attendees,
    this.conductedBy,
    List<String>? notes,
  })  : attendees = attendees ?? [],
        notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'meetingId': meetingId,
        'date': date?.toIso8601String(),
        'topic': topic,
        'attendees': attendees,
        'conductedBy': conductedBy,
        'notes': notes,
      };

  factory ToolboxMeeting.fromMap(Map<String, dynamic> d) => ToolboxMeeting(
        meetingId: d['meetingId'] ?? '',
        date: d["date"] != null ? DateTime.tryParse(d["date"].toString()) : null,
        topic: d['topic'] ?? '',
        attendees: List<String>.from(d['attendees'] ?? []),
        conductedBy: d['conductedBy'],
        notes: List<String>.from(d['notes'] ?? []),
      );
}

// --- Permit -------------------------------------------------------------------
class Permit {
  final String permitId;
  final String permitType; // 'Hot Work|Confined Space|Excavation|General'
  final DateTime? date;
  final DateTime? expiryDate;
  final String? issuedBy;
  final String status; // 'Active|Expired|Cancelled'
  final List<String> conditions;
  final List<String> notes;

  Permit({
    required this.permitId,
    required this.permitType,
    this.date,
    this.expiryDate,
    this.issuedBy,
    this.status = 'Active',
    List<String>? conditions,
    List<String>? notes,
  })  : conditions = conditions ?? [],
        notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'permitId': permitId,
        'permitType': permitType,
        'date': date?.toIso8601String(),
        'expiryDate':
            expiryDate?.toIso8601String(),
        'issuedBy': issuedBy,
        'status': status,
        'conditions': conditions,
        'notes': notes,
      };

  factory Permit.fromMap(Map<String, dynamic> d) => Permit(
        permitId: d['permitId'] ?? '',
        permitType: d['permitType'] ?? 'General',
        date: d["date"] != null ? DateTime.tryParse(d["date"].toString()) : null,
        expiryDate: d["expiryDate"] != null ? DateTime.tryParse(d["expiryDate"].toString()) : null,
        issuedBy: d['issuedBy'],
        status: d['status'] ?? 'Active',
        conditions: List<String>.from(d['conditions'] ?? []),
        notes: List<String>.from(d['notes'] ?? []),
      );
}

// --- Incident Report ----------------------------------------------------------
class Incident {
  final String incidentId;
  final DateTime? date;
  final String description;
  final String? location;
  final String severity; // 'Near Miss|Minor|Major|Fatal'
  final List<String> injured;
  final String? actionTaken;
  final String status; // 'Reported|Investigating|Closed'
  final List<String> notes;

  Incident({
    required this.incidentId,
    this.date,
    required this.description,
    this.location,
    this.severity = 'Near Miss',
    List<String>? injured,
    this.actionTaken,
    this.status = 'Reported',
    List<String>? notes,
  })  : injured = injured ?? [],
        notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'incidentId': incidentId,
        'date': date?.toIso8601String(),
        'description': description,
        'location': location,
        'severity': severity,
        'injured': injured,
        'actionTaken': actionTaken,
        'status': status,
        'notes': notes,
      };

  factory Incident.fromMap(Map<String, dynamic> d) => Incident(
        incidentId: d['incidentId'] ?? '',
        date: d["date"] != null ? DateTime.tryParse(d["date"].toString()) : null,
        description: d['description'] ?? '',
        location: d['location'],
        severity: d['severity'] ?? 'Near Miss',
        injured: List<String>.from(d['injured'] ?? []),
        actionTaken: d['actionTaken'],
        status: d['status'] ?? 'Reported',
        notes: List<String>.from(d['notes'] ?? []),
      );
}
