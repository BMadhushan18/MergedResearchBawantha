import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../services/mongo_api_service.dart';
import 'phase_result.dart';

class FoundationDurationScreen extends StatefulWidget {
  final int initialLabors;

  const FoundationDurationScreen({
    super.key,
    required this.initialLabors,
  });

  @override
  State<FoundationDurationScreen> createState() => _FoundationDurationScreenState();
}

class _FoundationDurationScreenState extends State<FoundationDurationScreen> {
  final _formKey = GlobalKey<FormState>();
  final MongoApiService _api = MongoApiService();

  bool _isLoading = false;

  // Form fields
  String _foundationType = 'Concrete';
  String _soilType = 'Normal';
  final TextEditingController _volumeController = TextEditingController();
  int _laborCount = 5;

  // Example dropdown options (edit to your dataset categories)
  final List<String> _foundationTypes = ['Concrete', 'Rubble', 'Strip', 'Pile', 'Raft'];
  final List<String> _soilTypes = ['Normal', 'Sandy', 'Clay', 'Rocky', 'Wet'];

  @override
  void initState() {
    super.initState();
    _laborCount = widget.initialLabors;
    _api.loadToken(); // optional (post() also ensures token)
  }

  @override
  void dispose() {
    _volumeController.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;

    final volume = double.parse(_volumeController.text.trim());

    setState(() => _isLoading = true);


//  data columns

    try {
      final payload = <String, dynamic>{
        "foundation_type": _foundationType,
        "soil_condition": _soilType,
        "total_volume_m3": volume,
        "labor_count": _laborCount,
     };

      final res = await _api.predictFoundationDuration(payload);

      final raw = res["duration_days"];
      final durationDays = (raw is int) ? raw : (raw as num).round();

      if (!mounted) return;

      Navigator.pop(
        context,
        PhaseResult(
          durationDays: durationDays < 1 ? 1 : durationDays,
          laborCount: _laborCount,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Prediction failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Foundation Duration'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 18),

              _dropdown(
                label: 'Foundation Type',
                value: _foundationType,
                items: _foundationTypes,
                icon: Icons.account_balance,
                onChanged: (v) => setState(() => _foundationType = v!),
              ),

              _dropdown(
                label: 'Soil Type',
                value: _soilType,
                items: _soilTypes,
                icon: Icons.landscape,
                onChanged: (v) => setState(() => _soilType = v!),
              ),

              _textField(
                controller: _volumeController,
                label: 'Volume (m³)',
                icon: Icons.straighten,
                hint: 'e.g. 106.5',
              ),

              const SizedBox(height: 16),
              _counterField(
                label: 'Labor Count',
                value: _laborCount,
                onChanged: (v) => setState(() => _laborCount = v),
                icon: Icons.groups,
                min: 1,
                max: 50,
              ),

              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _calculate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Calculate',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Foundation Phase',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Enter foundation details to estimate phase duration.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Please enter $label';
        final n = double.tryParse(v.trim());
        if (n == null) return 'Please enter a valid number';
        if (n <= 0) return '$label must be greater than 0';
        return null;
      },
    );
  }

  Widget _counterField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required IconData icon,
    int min = 1,
    int max = 999,
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
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          ),
          Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
          ),
        ],
      ),
    );
  }
}