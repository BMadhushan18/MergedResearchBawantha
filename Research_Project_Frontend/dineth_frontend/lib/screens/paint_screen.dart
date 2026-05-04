import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/config.dart';
import '../core/endpoints.dart';

class PaintScreen extends StatefulWidget {
  const PaintScreen({super.key});

  @override
  State<PaintScreen> createState() => _PaintScreenState();
}

class _PaintScreenState extends State<PaintScreen> {
  final api = ApiClient(kDinethApiBase);

  final _formKey = GlobalKey<FormState>();

  final wallSizeCtrl = TextEditingController(text: '300');
  final pricePerSqftCtrl = TextEditingController(text: '85');

  String location = 'indoor';
  String surface = 'plaster';
  String finish = 'matte';
  int coats = 2;
  String moisture = 'low';
  String paintType = 'emulsion';

  bool loading = false;
  Map<String, dynamic>? result;
  String? error;

  final locations = const ['indoor', 'outdoor', 'wood', 'floor'];
  final surfaces = const ['plaster', 'concrete', 'wood', 'metal'];
  final finishes = const ['matte', 'satin', 'gloss'];
  final moistures = const ['low', 'medium', 'high'];
  final paintTypes = const ['emulsion', 'enamel', 'antifungal', 'weatherproof'];

  @override
  void dispose() {
    wallSizeCtrl.dispose();
    pricePerSqftCtrl.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
      result = null;
    });

    try {
      final body = {
        "wall_size_sqft": double.parse(wallSizeCtrl.text.trim()),
        "price_per_sqft_lkr": double.parse(pricePerSqftCtrl.text.trim()),
        "location": location,
        "surface_material": surface,
        "finish_type": finish,
        "coats_needed": coats,
        "moisture_level": moisture,
        "paint_type": paintType,
      };

      final res = await api.post(Endpoints.paintPredict, body);
      setState(() => result = res);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem<T>(value: e, child: Text(e.toString())))
              .toList(),
          onChanged: onChanged,
          decoration: const InputDecoration(),
        ),
      ],
    );
  }

  Widget _chip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _smartTip() {
    if (location == "outdoor" && moisture == "high") {
      return "Outdoor with high moisture: consider weatherproof paint and allow extra drying time between coats.";
    }
    if (paintType == "antifungal" || moisture == "high") {
      return "High moisture area: use antifungal paint and ensure good ventilation while drying.";
    }
    if (location == "wood" && paintType != "enamel") {
      return "Wood surfaces usually last longer with enamel or a proper primer plus top coat.";
    }
    if (finish == "gloss") {
      return "Gloss finish shows surface imperfections more. Make sure the surface is smooth before painting.";
    }
    return "Clean the surface and use a suitable primer for better adhesion and durability.";
  }

  Widget buildResultCard() {
    if (result == null) return const SizedBox.shrink();

    final brand = (result!["paint_brand"] ?? "").toString();
    final grade = (result!["paint_grade"] ?? "").toString();

    final ppsNum = double.tryParse((result!["used_price_per_sqft_lkr"] ?? "").toString());
    final usedPps = ppsNum != null ? ppsNum.toStringAsFixed(2) : (result!["used_price_per_sqft_lkr"] ?? "").toString();

    final wall = double.tryParse(wallSizeCtrl.text.trim()) ?? 0;
    final inputPps = double.tryParse(pricePerSqftCtrl.text.trim()) ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.primaryContainer,
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: const Icon(Icons.check_circle_outline),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Recommendation",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: Text(
                  grade,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            "Recommended Brand",
            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            brand,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip("Wall: ${wall.toStringAsFixed(0)} sqft", Icons.square_foot),
              _chip("Input PPS: ${inputPps.toStringAsFixed(2)}", Icons.edit_note),
              _chip("Used PPS: $usedPps", Icons.calculate_outlined),
              _chip("Coats: $coats", Icons.layers_outlined),
              _chip("Moisture: $moisture", Icons.water_drop_outlined),
              _chip("Finish: $finish", Icons.auto_awesome_outlined),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Theme.of(context).colorScheme.surface.withOpacity(0.75),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_smartTip())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paint Recommendation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: wallSizeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Wall Size (sqft)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: pricePerSqftCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price per sqft (LKR)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              _dropdown(
                label: 'Location',
                value: location,
                items: locations,
                onChanged: (v) => setState(() => location = v ?? location),
              ),
              const SizedBox(height: 12),

              _dropdown(
                label: 'Surface Material',
                value: surface,
                items: surfaces,
                onChanged: (v) => setState(() => surface = v ?? surface),
              ),
              const SizedBox(height: 12),

              _dropdown(
                label: 'Finish Type',
                value: finish,
                items: finishes,
                onChanged: (v) => setState(() => finish = v ?? finish),
              ),
              const SizedBox(height: 12),

              _dropdown(
                label: 'Moisture Level',
                value: moisture,
                items: moistures,
                onChanged: (v) => setState(() => moisture = v ?? moisture),
              ),
              const SizedBox(height: 12),

              _dropdown(
                label: 'Paint Type',
                value: paintType,
                items: paintTypes,
                onChanged: (v) => setState(() => paintType = v ?? paintType),
              ),
              const SizedBox(height: 12),

              _dropdown<int>(
                label: 'Coats Needed',
                value: coats,
                items: const [1, 2, 3],
                onChanged: (v) => setState(() => coats = v ?? coats),
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: loading
                      ? null
                      : () {
                          if (_formKey.currentState?.validate() != true) return;
                          submit();
                        },
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Get Recommendation'),
                ),
              ),

              const SizedBox(height: 16),

              if (error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),

              buildResultCard(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}