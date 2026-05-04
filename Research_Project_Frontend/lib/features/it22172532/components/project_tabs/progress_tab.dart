import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:boq_frontend/features/it22172532/providers/project_provider.dart';
import 'package:boq_frontend/features/it22172532/models/project/progress_model.dart';

class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key});

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProjectProvider>();
    final updates = pp.progressUpdates;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAdd(context),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: updates.isEmpty
          ? _Empty(onAdd: () => _showAdd(context))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: updates.length,
              itemBuilder: (_, i) => _ProgressTile(update: updates[i]),
            ),
    );
  }

  void _showAdd(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => const _AddProgressSheet(),
      );
}

class _ProgressTile extends StatelessWidget {
  final ProgressUpdate update;
  const _ProgressTile({required this.update});

  @override
  Widget build(BuildContext context) {
    final date = update.date != null
        ? '${update.date!.day}/${update.date!.month}/${update.date!.year}'
        : 'â€”';
    final pct = update.percentComplete ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(update.activity ?? 'Progress Update',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Text(date,
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 12)),
              ],
            ),
            if (update.location != null) ...[
              const SizedBox(height: 4),
              Text(update.location!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: Colors.grey[200],
                      color: pct >= 100
                          ? Colors.green
                          : const Color(0xFF1565C0),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${pct.round()}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            if (update.notes != null) ...[
              const SizedBox(height: 8),
              Text(update.notes!,
                  style:
                      TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onAdd;
  const _Empty({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('No progress updates yet',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Update'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      );
}

class _AddProgressSheet extends StatefulWidget {
  const _AddProgressSheet();
  @override
  State<_AddProgressSheet> createState() => _AddProgressSheetState();
}

class _AddProgressSheetState extends State<_AddProgressSheet> {
  final _form = GlobalKey<FormState>();
  final _activity = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  double _pct = 0;
  bool _saving = false;

  @override
  void dispose() {
    _activity.dispose();
    _location.dispose();
    _notes.dispose();
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
            const Text('Add Progress Update',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _tf(_activity, 'Activity / Work Item *',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null),
            _tf(_location, 'Location / Area'),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Progress: ',
                    style: TextStyle(fontSize: 13)),
                Text('${_pct.round()}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0))),
              ],
            ),
            Slider(
              value: _pct,
              min: 0,
              max: 100,
              divisions: 20,
              label: '${_pct.round()}%',
              activeColor: const Color(0xFF1565C0),
              onChanged: (v) => setState(() => _pct = v),
            ),
            _tf(_notes, 'Notes'),
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
    await pp.addProgressUpdate(ProgressUpdate(
      progressId: const Uuid().v4(),
      date: DateTime.now(),
      activity: _activity.text.trim(),
      location:
          _location.text.trim().isEmpty ? null : _location.text.trim(),
      percentComplete: _pct,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    ));
    setState(() => _saving = false);
    if (context.mounted) Navigator.pop(context);
  }
}
