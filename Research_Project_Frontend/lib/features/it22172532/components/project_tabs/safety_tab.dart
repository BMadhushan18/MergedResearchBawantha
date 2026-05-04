import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:boq_frontend/features/it22172532/providers/project_provider.dart';
import 'package:boq_frontend/features/it22172532/models/project/safety_model.dart';

class SafetyTab extends StatelessWidget {
  const SafetyTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Color(0xFF1565C0),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF1565C0),
              tabs: [
                Tab(text: 'Incidents'),
                Tab(text: 'Toolbox'),
                Tab(text: 'Permits'),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            _IncidentList(),
            _ToolboxList(),
            _PermitList(),
          ],
        ),
        floatingActionButton: Builder(
          builder: (ctx) {
            final tabIndex = DefaultTabController.of(ctx).index;
            return FloatingActionButton(
              onPressed: () => _showAdd(context, tabIndex),
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            );
          },
        ),
      ),
    );
  }

  void _showAdd(BuildContext context, int tab) {
    if (tab == 0) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => const _AddIncidentSheet(),
      );
    } else if (tab == 1) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => const _AddToolboxSheet(),
      );
    }
  }
}

// â”€â”€ Incident List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _IncidentList extends StatelessWidget {
  const _IncidentList();

  @override
  Widget build(BuildContext context) {
    final incidents = context.watch<ProjectProvider>().incidents;
    if (incidents.isEmpty) {
      return _centred('No incidents recorded',
          Icons.check_circle_outline, Colors.green);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: incidents.length,
      itemBuilder: (_, i) => _IncidentTile(incident: incidents[i]),
    );
  }
}

class _IncidentTile extends StatelessWidget {
  final Incident incident;
  const _IncidentTile({required this.incident});

  Color get _severityColor {
    switch (incident.severity) {
      case 'Fatal':
        return Colors.black;
      case 'Major':
        return Colors.red;
      case 'Minor':
        return Colors.orange;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = incident.date != null
        ? '${incident.date!.day}/${incident.date!.month}/${incident.date!.year}'
        : 'â€”';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _severityColor.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.warning_amber,
              color: _severityColor, size: 22),
        ),
        title: Text(incident.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$date Â· ${incident.location ?? "â€”"}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _severityColor.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(incident.severity,
                  style: TextStyle(
                      fontSize: 10,
                      color: _severityColor,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Toolbox List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ToolboxList extends StatelessWidget {
  const _ToolboxList();

  @override
  Widget build(BuildContext context) {
    final meetings =
        context.watch<ProjectProvider>().toolboxMeetings;
    if (meetings.isEmpty) {
      return _centred(
          'No toolbox meetings yet', Icons.groups_outlined, Colors.blue);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meetings.length,
      itemBuilder: (_, i) => _ToolboxTile(meeting: meetings[i]),
    );
  }
}

class _ToolboxTile extends StatelessWidget {
  final ToolboxMeeting meeting;
  const _ToolboxTile({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final date = meeting.date != null
        ? '${meeting.date!.day}/${meeting.date!.month}/${meeting.date!.year}'
        : 'â€”';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.groups, color: Colors.blue, size: 22),
        ),
        title: Text(meeting.topic,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$date Â· ${meeting.attendees.length} attendees'),
        trailing: meeting.conductedBy != null
            ? Text(meeting.conductedBy!,
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 12))
            : null,
      ),
    );
  }
}

// â”€â”€ Permit List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _PermitList extends StatelessWidget {
  const _PermitList();

  @override
  Widget build(BuildContext context) {
    final permits = context.watch<ProjectProvider>().permits;
    if (permits.isEmpty) {
      return _centred(
          'No permits yet', Icons.assignment_outlined, Colors.purple);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: permits.length,
      itemBuilder: (_, i) => _PermitTile(permit: permits[i]),
    );
  }
}

class _PermitTile extends StatelessWidget {
  final Permit permit;
  const _PermitTile({required this.permit});

  Color get _statusColor {
    switch (permit.status) {
      case 'Active':
        return Colors.green;
      case 'Expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = permit.date != null
        ? '${permit.date!.day}/${permit.date!.month}/${permit.date!.year}'
        : 'â€”';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const Icon(Icons.assignment, color: Colors.purple),
        title: Text(permit.permitType,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Issued: $date'),
        trailing: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor.withAlpha(25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(permit.status,
              style: TextStyle(
                  color: _statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// â”€â”€ Add Sheets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _AddIncidentSheet extends StatefulWidget {
  const _AddIncidentSheet();
  @override
  State<_AddIncidentSheet> createState() => _AddIncidentSheetState();
}

class _AddIncidentSheetState extends State<_AddIncidentSheet> {
  final _form = GlobalKey<FormState>();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  final _action = TextEditingController();
  String _severity = 'Near Miss';
  bool _saving = false;

  final _severities = ['Near Miss', 'Minor', 'Major', 'Fatal'];

  @override
  void dispose() {
    _desc.dispose();
    _location.dispose();
    _action.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Report Incident',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _tf(_desc, 'Description *',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null),
            _tf(_location, 'Location'),
            DropdownButtonFormField<String>(
              value: _severity,
              decoration: InputDecoration(
                labelText: 'Severity',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
              items: _severities
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _severity = v!),
            ),
            const SizedBox(height: 10),
            _tf(_action, 'Action Taken'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tf(TextEditingController c, String label,
      {String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final pp = context.read<ProjectProvider>();
    await pp.addIncident(Incident(
      incidentId: const Uuid().v4(),
      date: DateTime.now(),
      description: _desc.text.trim(),
      location:
          _location.text.trim().isEmpty ? null : _location.text.trim(),
      severity: _severity,
      actionTaken: _action.text.trim().isEmpty
          ? null
          : _action.text.trim(),
    ));
    setState(() => _saving = false);
    if (context.mounted) Navigator.pop(context);
  }
}

class _AddToolboxSheet extends StatefulWidget {
  const _AddToolboxSheet();
  @override
  State<_AddToolboxSheet> createState() => _AddToolboxSheetState();
}

class _AddToolboxSheetState extends State<_AddToolboxSheet> {
  final _form = GlobalKey<FormState>();
  final _topic = TextEditingController();
  final _conductor = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _topic.dispose();
    _conductor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Toolbox Meeting',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _tf(_topic, 'Topic *',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null),
            _tf(_conductor, 'Conducted By'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tf(TextEditingController c, String label,
      {String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final pp = context.read<ProjectProvider>();
    await pp.addToolboxMeeting(ToolboxMeeting(
      meetingId: const Uuid().v4(),
      date: DateTime.now(),
      topic: _topic.text.trim(),
      conductedBy: _conductor.text.trim().isEmpty
          ? null
          : _conductor.text.trim(),
    ));
    setState(() => _saving = false);
    if (context.mounted) Navigator.pop(context);
  }
}

// â”€â”€ Helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Widget _centred(String text, IconData icon, Color color) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: color.withAlpha(80)),
          const SizedBox(height: 12),
          Text(text,
              style: const TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
