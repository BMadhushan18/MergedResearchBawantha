import 'package:flutter/material.dart';

import 'package:boq_frontend/features/it22172532/services/wood_api_client.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';
final String _kDinethApiBase = AppConstants.baseUrl;


const _kPaintEndpoint = '/paint/predict';

class PaintRecommendationScreen extends StatefulWidget {
  const PaintRecommendationScreen({super.key});

  @override
  State<PaintRecommendationScreen> createState() =>
      _PaintRecommendationScreenState();
}

class _PaintRecommendationScreenState
    extends State<PaintRecommendationScreen> {
  final _api = WoodApiClient(_kDinethApiBase);

  final _formKey = GlobalKey<FormState>();

  final _wallSizeCtrl = TextEditingController(text: '300');
  final _priceCtrl = TextEditingController(text: '85');

  String _location = 'indoor';
  String _surface = 'plaster';
  String _finish = 'matte';
  String _moisture = 'low';
  String _paintType = 'emulsion';
  int _coats = 2;

  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  static const _locations = ['indoor', 'outdoor', 'wood', 'floor'];
  static const _surfaces = ['plaster', 'concrete', 'wood', 'metal'];
  static const _finishes = ['matte', 'satin', 'gloss'];
  static const _moistures = ['low', 'medium', 'high'];
  static const _paintTypes = [
    'emulsion',
    'enamel',
    'antifungal',
    'weatherproof'
  ];

  @override
  void dispose() {
    _wallSizeCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final res = await _api.post(_kPaintEndpoint, {
        'wall_size_sqft': double.parse(_wallSizeCtrl.text.trim()),
        'price_per_sqft_lkr': double.parse(_priceCtrl.text.trim()),
        'location': _location,
        'surface_material': _surface,
        'finish_type': _finish,
        'coats_needed': _coats,
        'moisture_level': _moisture,
        'paint_type': _paintType,
      });
      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          value: value,
          decoration: const InputDecoration(isDense: true),
          items: items
              .map((e) =>
                  DropdownMenuItem<T>(value: e, child: Text(e.toString())))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  String _tip() {
    if (_location == 'outdoor' && _moisture == 'high') {
      return 'Outdoor + high moisture: use weatherproof paint and allow extra drying time.';
    }
    if (_paintType == 'antifungal' || _moisture == 'high') {
      return 'High moisture area: use antifungal paint and ensure good ventilation.';
    }
    if (_location == 'wood' && _paintType != 'enamel') {
      return 'Wood surfaces last longer with enamel or a primer + top coat.';
    }
    return 'Clean the surface and use a primer for better adhesion.';
  }

  Widget _buildResult() {
    final res = _result;
    if (res == null) return const SizedBox.shrink();
    final brand = res['paint_brand']?.toString() ?? '';
    final grade = res['paint_grade']?.toString() ?? '';
    final wall = double.tryParse(_wallSizeCtrl.text) ?? 0;
    final pps = res['used_price_per_sqft_lkr'];
    final ppsStr = pps != null
        ? (double.tryParse(pps.toString())?.toStringAsFixed(2) ?? pps.toString())
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Recommendation',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const Spacer(),
            if (grade.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(grade,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ),
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
            if (ppsStr.isNotEmpty)
              _chip('PPS: $ppsStr', Icons.calculate_outlined),
            _chip('Coats: $_coats', Icons.layers_outlined),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 16, color: Colors.amber),
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
        title: const Text('Paint Recommendation'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _wallSizeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Wall Size (sqft)', isDense: true),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Price per sqft (LKR)', isDense: true),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                  label: 'Finish Type',
                  value: _finish,
                  items: _finishes,
                  onChanged: (v) =>
                      setState(() => _finish = v ?? _finish)),
              const SizedBox(height: 12),
              _dropdown(
                  label: 'Moisture Level',
                  value: _moisture,
                  items: _moistures,
                  onChanged: (v) =>
                      setState(() => _moisture = v ?? _moisture)),
              const SizedBox(height: 12),
              _dropdown(
                  label: 'Paint Type',
                  value: _paintType,
                  items: _paintTypes,
                  onChanged: (v) =>
                      setState(() => _paintType = v ?? _paintType)),
              const SizedBox(height: 12),
              _dropdown<int>(
                  label: 'Coats Needed',
                  value: _coats,
                  items: const [1, 2, 3],
                  onChanged: (v) =>
                      setState(() => _coats = v ?? _coats)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
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
      ),
    );
  }
}
