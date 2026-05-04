import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:boq_frontend/features/it22172532/providers/project_provider.dart';
import 'package:boq_frontend/features/it22172532/models/project/worker_model.dart';

class WorkersTab extends StatelessWidget {
  const WorkersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProjectProvider>();
    final items = pp.workers;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAdd(context),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add_outlined),
      ),
      body: items.isEmpty
          ? _Empty(onAdd: () => _showAdd(context))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) => _WorkerTile(worker: items[i]),
            ),
    );
  }

  void _showAdd(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => const _AddWorkerSheet(),
      );
}

class _WorkerTile extends StatelessWidget {
  final WorkerModel worker;
  const _WorkerTile({required this.worker});

  Color get _tradeColor {
    switch (worker.tradeId.toLowerCase()) {
      case 'lab-mason':
        return Colors.orange;
      case 'lab-carp':
        return Colors.brown;
      case 'lab-steel':
        return Colors.blueGrey;
      case 'lab-paint':
        return Colors.purple;
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _tradeColor.withAlpha(30),
          child: Text(
            (worker.name?.isNotEmpty ?? false) ? worker.name![0].toUpperCase() : '?',
            style: TextStyle(
                color: _tradeColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(worker.name ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(worker.tradeId),
        trailing: worker.dailyRateOverride != null
            ? Text('${worker.dailyRateOverride!.toStringAsFixed(0)}/day',
                style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w600,
                    fontSize: 12))
            : null,
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
            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('No workers yet',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Worker'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      );
}

class _AddWorkerSheet extends StatefulWidget {
  const _AddWorkerSheet();
  @override
  State<_AddWorkerSheet> createState() => _AddWorkerSheetState();
}

class _AddWorkerSheetState extends State<_AddWorkerSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _rate = TextEditingController();
  final _phone = TextEditingController();
  String _trade = 'Mason';
  String _empType = 'Daily';
  bool _saving = false;

  final _trades = [
    'Mason', 'Carpenter', 'Steel Fixer', 'Painter', 'Helper', 'Other'
  ];
  final _empTypes = ['Daily', 'Monthly', 'Contract'];

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _phone.dispose();
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
            const Text('Add Worker',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _tf(_name, 'Full Name *',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null),
            _dropdown('Trade', _trades, _trade,
                (v) => setState(() => _trade = v!)),
            const SizedBox(height: 10),
            _dropdown('Employment Type', _empTypes, _empType,
                (v) => setState(() => _empType = v!)),
            const SizedBox(height: 10),
            _tf(_rate, 'Daily Rate (${context.read<ProjectProvider>().currentProject?.currency ?? "LKR"})',
                keyboardType: TextInputType.number),
            _tf(_phone, 'Phone Number'),
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
                    : const Text('Add Worker'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tf(TextEditingController c, String label,
      {String? Function(String?)? validator,
      TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        validator: validator,
        keyboardType: keyboardType,
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

  Widget _dropdown(String label, List<String> items, String value,
      ValueChanged<String?> onChange) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: onChange,
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final pp = context.read<ProjectProvider>();
    await pp.addWorker(WorkerModel(
      workerId: const Uuid().v4(),
      name: _name.text.trim(),
      tradeId: _trade,
      dailyRateOverride: double.tryParse(_rate.text.trim()),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
    ));
    setState(() => _saving = false);
    if (context.mounted) Navigator.pop(context);
  }
}
