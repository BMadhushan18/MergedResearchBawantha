import 'package:flutter/material.dart';

import 'package:boq_frontend/features/it22172532/services/wood_api_client.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';
final String _kDinethApiBase = AppConstants.baseUrl;


const _kSkimcoatEndpoint = '/skimcoat/predict';

class SkimcoatRecommendationScreen extends StatefulWidget {
  const SkimcoatRecommendationScreen({super.key});

  @override
  State<SkimcoatRecommendationScreen> createState() =>
      _SkimcoatRecommendationScreenState();
}

class _SkimcoatRecommendationScreenState
    extends State<SkimcoatRecommendationScreen> {
  final _api = WoodApiClient(_kDinethApiBase);


  final _wallSizeCtrl = TextEditingController(text: '500');
  final _budgetCtrl = TextEditingController(text: '450000');

  String _location = 'outdoor';
  String _surface = 'concrete';
  String _moisture = 'high';
  String _condition = 'old';
  String _finish = 'premium-smooth';
  int _coats = 3;

  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  static const _locations = ['indoor', 'outdoor'];
  static const _surfaces = [
    'plaster',
    'gypsum-board',
    'concrete',
    'cement-plaster'
  ];
  static const _moistures = ['low', 'medium', 'high'];
  static const _conditions = ['new', 'old', 'cracked'];
  static const _finishes = ['basic', 'smooth', 'premium-smooth'];

  @override
  void dispose() {
    _wallSizeCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _predict() async {
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    try {
      final res = await _api.post(_kSkimcoatEndpoint, {
        'wall_size_sqft': double.parse(_wallSizeCtrl.text.trim()),
        'budget_lkr': double.parse(_budgetCtrl.text.trim()),
        'location': _location,
        'surface_material': _surface,
        'moisture_level': _moisture,
        'substrate_condition': _condition,
        'coats_needed': _coats,
        'finish_level': _finish,
      });
      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          decoration: const InputDecoration(isDense: true),
          items: items
              .map((e) =>
                  DropdownMenuItem<String>(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  String _tip() {
    if (_moisture == 'high' && _location == 'outdoor') {
      return 'High moisture outdoor: apply primer and allow extra drying between coats.';
    }
    if (_moisture == 'high') {
      return 'High moisture: ensure good ventilation and extra drying time.';
    }
    if (_location == 'outdoor') {
      return 'Outdoor: avoid application during rain and direct strong sunlight.';
    }
    if (_condition == 'cracked') {
      return 'Cracked surface: repair cracks first, then apply skimcoat.';
    }
    return 'Clean the surface and remove dust before applying skimcoat.';
  }

  Widget _buildResult() {
    final res = _result;
    if (res == null) return const SizedBox.shrink();
    final brand = res['brand']?.toString() ?? '';
    final wall = double.tryParse(_wallSizeCtrl.text) ?? 0;
    final budget = double.tryParse(_budgetCtrl.text) ?? 0;
    final pps = res['used_price_per_sqft_lkr'];
    final ppsStr = pps != null
        ? (double.tryParse(pps.toString())?.toStringAsFixed(2) ?? pps.toString())
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00695C).withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF00695C).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.check_circle_rounded,
                color: Color(0xFF00695C), size: 20),
            SizedBox(width: 8),
            Text('Recommendation',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          Text('Recommended Brand',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(brand,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('Wall: ${wall.toStringAsFixed(0)} sqft',
                Icons.square_foot),
            _chip(
                'Budget: LKR ${budget.toStringAsFixed(0)}',
                Icons.payments_outlined),
            if (ppsStr.isNotEmpty)
              _chip('PPS: $ppsStr', Icons.calculate_outlined),
            _chip('Coats: $_coats', Icons.layers_outlined),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 16, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_tip(),
                        style: const TextStyle(fontSize: 12))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, IconData icon) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.grey.shade100,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 5),
            Text(text,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skimcoat Recommendation'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _wallSizeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Wall Size (sqft)', isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _budgetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Budget (LKR)', isDense: true),
            ),
            const SizedBox(height: 12),
            _dropdown(
                label: 'Location',
                value: _location,
                items: _locations,
                onChanged: (v) =>
                    setState(() => _location = v ?? _location)),
            const SizedBox(height: 12),
            _dropdown(
                label: 'Surface Material',
                value: _surface,
                items: _surfaces,
                onChanged: (v) =>
                    setState(() => _surface = v ?? _surface)),
            const SizedBox(height: 12),
            _dropdown(
                label: 'Moisture Level',
                value: _moisture,
                items: _moistures,
                onChanged: (v) =>
                    setState(() => _moisture = v ?? _moisture)),
            const SizedBox(height: 12),
            _dropdown(
                label: 'Substrate Condition',
                value: _condition,
                items: _conditions,
                onChanged: (v) =>
                    setState(() => _condition = v ?? _condition)),
            const SizedBox(height: 12),
            _dropdown(
                label: 'Finish Level',
                value: _finish,
                items: _finishes,
                onChanged: (v) =>
                    setState(() => _finish = v ?? _finish)),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Coats Needed',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  value: _coats,
                  decoration:
                      const InputDecoration(isDense: true),
                  items: const [1, 2, 3]
                      .map((e) => DropdownMenuItem<int>(
                          value: e,
                          child: Text(e.toString())))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _coats = v ?? _coats),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _predict,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00695C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Get Recommendation'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_error!,
                    style: TextStyle(
                        color: Colors.red.shade700, fontSize: 13)),
              ),
            _buildResult(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
