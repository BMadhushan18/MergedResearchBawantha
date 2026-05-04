import 'package:flutter/material.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import 'package:boq_frontend/features/it22172532/services/mongo_api_service.dart';
import 'estimation_result_screen.dart';

class TimeEstimateScreen extends StatefulWidget {
  const TimeEstimateScreen({super.key});

  @override
  State<TimeEstimateScreen> createState() => _TimeEstimateScreenState();
}

class _TimeEstimateScreenState extends State<TimeEstimateScreen> {
  // Form key controls validation state for all input widgets in this screen.
  final _formKey = GlobalKey<FormState>();
  // Shared API client used to call backend prediction endpoints.
  final MongoApiService _api = MongoApiService();

  // Main numeric input for total building area used by the duration model.
  final TextEditingController _areaController = TextEditingController();

  // Numeric features used by the model.
  int _floorCount = 1;
  int _laborCount = 5;

  // Categorical features used by the model.
  String _selectedFoundation = 'Concrete';
  String _selectedWall = 'Brick';
  String _selectedRoofing = 'Concrete Tiles';
  String _selectedFlooring = 'Tiles';

  // Disables submit button and shows spinner while waiting for backend response.
  bool _isLoading = false;

  // Dropdown options should stay aligned with categories used while model training.
  final List<String> _foundations = ['Rubble', 'Concrete', 'Strip', 'Pile', 'Raft'];
  final List<String> _walls = ['Concrete Block', 'Brick'];
  final List<String> _roofingTypes = ['Asbestos Sheet', 'Concrete Tiles', 'Clay Tiles', 'Metal Sheets'];
  final List<String> _flooringTypes = ['Cement Rendering', 'Tiles', 'Titanium', 'Hardwood'];

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  // Convert days -> "X months Y weeks Z days"
  String _formatDurationFromDays(int totalDays) {
    // Convert raw predicted days into a user-friendly month/week/day representation.
    final months = totalDays ~/ 30;
    final remainingAfterMonths = totalDays % 30;
    final weeks = remainingAfterMonths ~/ 7;
    final days = remainingAfterMonths % 7;

    final parts = <String>[];
    if (months > 0) parts.add('$months month${months == 1 ? '' : 's'}');
    if (weeks > 0) parts.add('$weeks week${weeks == 1 ? '' : 's'}');
    if (days > 0 || parts.isEmpty) parts.add('$days day${days == 1 ? '' : 's'}');

    return parts.join(' ');
  }

  Future<void> _predictDuration() async {
    // Stop early if any form field fails validation.
    if (!_formKey.currentState!.validate()) return;

    final area = double.parse(_areaController.text.trim());

    setState(() => _isLoading = true);

    try {
      await _api.loadToken(); // ensure jwt token loaded

      // Payload keys must match backend model feature names exactly.
      final payload = <String, dynamic>{
        "Total Building Area (sq ft)": area,
        "Num_of_Floors": _floorCount,
        "Foundation_Type": _selectedFoundation,
        "Wall_Material": _selectedWall,
        "Roofing_Type": _selectedRoofing,
        "Flooring_Type": _selectedFlooring,
        "labor_count": _laborCount,
      };

      final res = await _api.predictDuration(payload);

  // Backend may return int or num; normalize to integer days for UI and next screen.
      final raw = res["duration_days"];
      final durationDays = (raw is int) ? raw : (raw as num).round();

  // Build a readable duration label shown in the result screen.
      final durationText = _formatDurationFromDays(durationDays);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EstimationResultScreen(
            durationDays: durationDays,
            durationText: durationText,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

// if prediction fails, show error message in red color
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
      // Use shared app theme colors so this screen matches the rest of the module.
      // page background color
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // Time Estimation Topic
        title: const Text('Time Estimation Form'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------------- General numeric inputs ----------------
                    _buildSectionTitle('General Specifications'),
                    _buildTextField(
                      _areaController,
                      'Building Area (Sqft)',
                      Icons.crop_square,
                      TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    _buildCounterField(
                      'Number of Floors',
                      _floorCount,
                      (val) => setState(() => _floorCount = val),
                      Icons.layers,
                    ),

                    const SizedBox(height: 24),
                    // ---------------- Categorical material selections ----------------
                    _buildSectionTitle('Material Selection'),

                    _buildDropdown(
                      'Foundation Type',
                      _selectedFoundation,
                      _foundations,
                      (val) => setState(() => _selectedFoundation = val!),
                      Icons.account_balance,
                    ),

                    _buildDropdown(
                      'Wall Material',
                      _selectedWall,
                      _walls,
                      (val) => setState(() => _selectedWall = val!),
                      Icons.construction,
                    ),

                    _buildDropdown(
                      'Roofing Type',
                      _selectedRoofing,
                      _roofingTypes,
                      (val) => setState(() => _selectedRoofing = val!),
                      Icons.home,
                    ),

                    _buildDropdown(
                      'Flooring Type',
                      _selectedFlooring,
                      _flooringTypes,
                      (val) => setState(() => _selectedFlooring = val!),
                      Icons.view_module,
                    ),

                    const SizedBox(height: 24),
                    // ---------------- Labor resource input ----------------
                    _buildSectionTitle('Labor Resource'),

                    _buildCounterField(
                      'Labor Count',
                      _laborCount,
                      (val) => setState(() => _laborCount = val),
                      Icons.groups,
                    ),

                    const SizedBox(height: 40),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calculate Project Duration',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Enter the building details below to estimate the time required for completion.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, TextInputType type) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (v) {
        // Common validation rule: required + valid positive number.
        if (v == null || v.trim().isEmpty) return 'Please enter $label';
        final n = double.tryParse(v.trim());
        if (n == null) return 'Please enter a valid number';
        if (n <= 0) return '$label must be greater than 0';
        return null;
      },
    );
  }

  Widget _buildCounterField(String label, int value, Function(int) onChanged, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Subtle neutral border keeps counters readable against white cards.
        border: Border.all(color: Colors.grey.shade400),
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
            onPressed: () => value > 1 ? onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          ),
          Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        // Prevent duplicate requests while an active prediction is in progress.
        onPressed: _isLoading ? null : _predictDuration,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text(
                'Calculate Duration',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
      ),
    );
  }
}