import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../services/mongo_api_service.dart';
import 'phase_result.dart';

class RoofDurationScreen extends StatefulWidget {
  final int initialLabors;

  const RoofDurationScreen({
    super.key,
    this.initialLabors = 5,
  });

  @override
  State<RoofDurationScreen> createState() => _RoofDurationScreenState();
}

class _RoofDurationScreenState extends State<RoofDurationScreen> {
  final _formKey = GlobalKey<FormState>();
  final MongoApiService _api = MongoApiService();

  final TextEditingController _roofAreaCtrl = TextEditingController();
  final TextEditingController _roofHeightCtrl = TextEditingController();

  String _roofType = 'Gable';
  String _coveringType = 'Concrete Tiles';
  int _laborCount = 5;
  bool _isLoading = false;

  final List<String> _roofTypes = const ['Gable', 'Flat', 'Lean-to', 'Hip'];
  final List<String> _coveringTypes = const [
    'Concrete Tiles',
    'Clay Tiles',
    'RC Slab',
    'Asbestos Sheets',
    'Metal Sheets',
  ];

  @override
  void initState() {
    super.initState();
    _laborCount = widget.initialLabors < 1 ? 1 : widget.initialLabors;
    _api.loadToken();
  }

  @override
  void dispose() {
    _roofAreaCtrl.dispose();
    _roofHeightCtrl.dispose();
    super.dispose();
  }

  Future<void> _onCalculate() async {
    if (!_formKey.currentState!.validate()) return;

    final area = double.parse(_roofAreaCtrl.text.trim());
    final height = double.parse(_roofHeightCtrl.text.trim());

    setState(() => _isLoading = true);

    try {
      final payload = <String, dynamic>{
        'roof_area_m2': area,
        'roof_height_m': height,
        'roof_type': _roofType,
        'roof_covering': _coveringType,
        'labor_count': _laborCount,
      };

      final res = await _api.predictRoofDuration(payload);
      final raw = res['duration_days'];
      final days = (raw is int) ? raw : (raw as num).round();

      if (!mounted) return;

      Navigator.pop(
        context,
        PhaseResult(durationDays: days < 1 ? 1 : days, laborCount: _laborCount),
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

  // ----------------------------- UI -----------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Roofing'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 18),

              _buildNumberField(
                controller: _roofAreaCtrl,
                label: 'Roof Area (m²)',
                icon: Icons.crop_square_rounded,
                hint: 'e.g. 160',
              ),
              const SizedBox(height: 14),

              _buildNumberField(
                controller: _roofHeightCtrl,
                label: 'Roof Height (m)',
                icon: Icons.height_rounded,
                hint: 'e.g. 2.5',
              ),
              const SizedBox(height: 14),

              _buildDropdown(
                label: 'Roof Type',
                value: _roofType,
                items: _roofTypes,
                icon: Icons.home_work_rounded,
                onChanged: (v) => setState(() => _roofType = v!),
              ),
              const SizedBox(height: 14),

              _buildDropdown(
                label: 'Roof Covering Type',
                value: _coveringType,
                items: _coveringTypes,
                icon: Icons.roofing_rounded,
                onChanged: (v) => setState(() => _coveringType = v!),
              ),
              const SizedBox(height: 14),

              _buildCounterField(
                label: 'Labor Count',
                value: _laborCount,
                icon: Icons.groups_rounded,
                onChanged: (v) => setState(() => _laborCount = v),
              ),

              const SizedBox(height: 26),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _onCalculate,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.calculate_rounded),
                  label: Text(
                    _isLoading ? 'Calculating...' : 'Calculate',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.roofing_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Fill roofing details and calculate estimated duration (days).',
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
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
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildNumberField({
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
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Please enter $label';
        final n = double.tryParse(v.trim());
        if (n == null) return 'Enter a valid number';
        if (n <= 0) return '$label must be greater than 0';
        return null;
      },
    );
  }

  Widget _buildCounterField({
    required String label,
    required int value,
    required IconData icon,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => value > 1 ? onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
          ),
          Text(
            '$value',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_circle_outline, color: AppColors.success),
          ),
        ],
      ),
    );
  }
}


