import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../services/mongo_api_service.dart';
import 'phase_result.dart';

class PlasteringDurationScreen extends StatefulWidget {
  final int initialLabors;

  const PlasteringDurationScreen({
    super.key,
    this.initialLabors = 5,
  });

  @override
  State<PlasteringDurationScreen> createState() => _PlasteringDurationScreenState();
}

class _PlasteringDurationScreenState extends State<PlasteringDurationScreen> {
  final _formKey = GlobalKey<FormState>();
  final MongoApiService _api = MongoApiService();

  String _material = 'Cement Sand';
  String _location = 'Internal';

  final TextEditingController _wallAreaController = TextEditingController();

  int _floors = 1;
  int _laborCount = 5;
  bool _isLoading = false;

  final List<String> _materials = ['Cement Sand', 'Gypsum'];
  final List<String> _locations = ['Internal', 'External', 'Both'];

  @override
  void initState() {
    super.initState();
    _laborCount = widget.initialLabors;
    _api.loadToken();
  }

  @override
  void dispose() {
    _wallAreaController.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;

    final wallArea = double.parse(_wallAreaController.text.trim());

    setState(() => _isLoading = true);

    try {
      final payload = <String, dynamic>{
        'wall_area_m2': wallArea,
        'material': _material,
        'location': _location,
        'floors': _floors,
        'labor_count': _laborCount,
      };

      final res = await _api.predictPlasteringDuration(payload);
      final raw = res['duration_days'];
      final days = (raw is int) ? raw : (raw as num).round();

      if (!mounted) return;

      Navigator.pop(
        context,
        PhaseResult(
          durationDays: days < 1 ? 1 : days,
          laborCount: _laborCount,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prediction failed: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Plastering'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [

              _dropdownField(
                label: 'Plastering Material',
                value: _material,
                items: _materials,
                icon: Icons.layers,
                onChanged: (v) => setState(() => _material = v!),
              ),

              const SizedBox(height: 16),

              _numberField(
                controller: _wallAreaController,
                label: 'Wall Area (m²)',
                icon: Icons.square_foot,
                hint: 'Example: 250',
              ),

              const SizedBox(height: 16),

              _dropdownField(
                label: 'Plaster Location',
                value: _location,
                items: _locations,
                icon: Icons.location_on,
                onChanged: (v) => setState(() => _location = v!),
              ),

              const SizedBox(height: 16),

              _counterField(
                label: 'Floors',
                value: _floors,
                icon: Icons.layers_outlined,
                onChanged: (v) => setState(() => _floors = v),
              ),

              const SizedBox(height: 16),

              _counterField(
                label: 'Labor Count',
                value: _laborCount,
                icon: Icons.groups,
                onChanged: (v) => setState(() => _laborCount = v),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _calculate,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.calculate),
                  label: Text(
                    _isLoading ? 'Calculating...' : 'Calculate',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Widgets ----------------

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Enter $label';
        final n = double.tryParse(v.trim());
        if (n == null) return 'Enter valid number';
        if (n <= 0) return '$label must be greater than 0';
        return null;
      },
    );
  }

  Widget _counterField({
    required String label,
    required int value,
    required IconData icon,
    required Function(int) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () {
              if (value > 1) onChanged(value - 1);
            },
          ),
          Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}