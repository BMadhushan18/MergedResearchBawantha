import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:boq_frontend/features/it22172532/providers/auth_provider.dart';
import 'package:boq_frontend/features/it22172532/providers/project_provider.dart';
import 'package:boq_frontend/features/it22172532/models/project/project_model.dart';

class CreateProjectScreen extends StatefulWidget {
  /// Pass a project to edit an existing one; null = create new
  final ProjectModel? existing;
  const CreateProjectScreen({super.key, this.existing});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _client;
  late final TextEditingController _location;
  late final TextEditingController _notes;

  String _currency = 'LKR';
  String _units = 'Metric';
  bool _saving = false;

  final _currencies = ['LKR', 'USD', 'EUR', 'GBP', 'SGD', 'AUD'];
  final _unitSystems = ['Metric', 'Imperial'];

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.projectName ?? '');
    _client = TextEditingController(text: p?.client ?? '');
    _location = TextEditingController(text: p?.location ?? '');
    _notes = TextEditingController(text: p?.notes.join(', ') ?? '');
    _currency = p?.currency ?? 'LKR';
    _units = p?.units ?? 'Metric';
  }

  @override
  void dispose() {
    _name.dispose();
    _client.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final uid =
        context.read<AuthProvider>().userProfile?.uid ?? '';
    final pp = context.read<ProjectProvider>();
    final isEdit = widget.existing != null;

    final project = ProjectModel(
      projectId: widget.existing?.projectId ?? const Uuid().v4(),
      projectName: _name.text.trim(),
      client: _client.text.trim().isEmpty ? null : _client.text.trim(),
      location:
          _location.text.trim().isEmpty ? null : _location.text.trim(),
      currency: _currency,
      units: _units,
      createdDate: widget.existing?.createdDate ?? DateTime.now(),
      lastUpdated: DateTime.now(),
      notes: _notes.text.trim().isEmpty
          ? []
          : _notes.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
      ownerUid: uid,
    );

    if (isEdit) {
      await pp.updateProject(project);
    } else {
      await pp.createProject(project);
    }

    setState(() => _saving = false);

    if (pp.error != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${pp.error}'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Project' : 'New Project'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Section(
              title: 'Project Info',
              children: [
                _field(
                  controller: _name,
                  label: 'Project Name *',
                  icon: Icons.construction,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                _field(
                  controller: _client,
                  label: 'Client / Owner',
                  icon: Icons.person_outline,
                ),
                _field(
                  controller: _location,
                  label: 'Location / Site',
                  icon: Icons.location_on_outlined,
                ),
                _field(
                  controller: _notes,
                  label: 'Notes (comma-separated)',
                  icon: Icons.note_outlined,
                  maxLines: 2,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Settings',
              children: [
                _dropdown(
                  label: 'Currency',
                  icon: Icons.attach_money,
                  value: _currency,
                  items: _currencies,
                  onChanged: (v) => setState(() => _currency = v!),
                ),
                const SizedBox(height: 12),
                _dropdown(
                  label: 'Unit System',
                  icon: Icons.straighten,
                  value: _units,
                  items: _unitSystems,
                  onChanged: (v) => setState(() => _units = v!),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Text(isEdit ? 'Save Changes' : 'Create Project',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

// â”€â”€â”€ Section Wrapper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1565C0))),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
