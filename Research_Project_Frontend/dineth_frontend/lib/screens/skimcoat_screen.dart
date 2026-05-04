import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/config.dart';
import '../core/endpoints.dart';

class SkimcoatScreen extends StatefulWidget {
  const SkimcoatScreen({super.key});

  @override
  State<SkimcoatScreen> createState() => _SkimcoatScreenState();
}

class _SkimcoatScreenState extends State<SkimcoatScreen> {
  // Update IP if your PC IP changes
  final api = ApiClient(kDinethApiBase);

  final wallSizeCtrl = TextEditingController(text: "500");
  final budgetCtrl = TextEditingController(text: "450000");

  String location = "outdoor";
  String surfaceMaterial = "concrete";
  String moistureLevel = "high";
  String substrateCondition = "old";
  int coatsNeeded = 3;
  String finishLevel = "premium-smooth";

  bool loading = false;
  Map<String, dynamic>? result;
  String? error;

  final locations = const ["indoor", "outdoor"];
  final surfaces = const ["plaster", "gypsum-board", "concrete", "cement-plaster"];
  final moistures = const ["low", "medium", "high"];
  final conditions = const ["new", "old", "cracked"];
  final finishes = const ["basic", "smooth", "premium-smooth"];

  @override
  void dispose() {
    wallSizeCtrl.dispose();
    budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> predict() async {
    setState(() {
      loading = true;
      result = null;
      error = null;
    });

    try {
      final body = {
        "wall_size_sqft": double.parse(wallSizeCtrl.text.trim()),
        "budget_lkr": double.parse(budgetCtrl.text.trim()),
        "location": location,
        "surface_material": surfaceMaterial,
        "moisture_level": moistureLevel,
        "substrate_condition": substrateCondition,
        "coats_needed": coatsNeeded,
        "finish_level": finishLevel,
      };

      final res = await api.post(Endpoints.skimcoatPredict, body);

      setState(() {
        result = res;
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Widget dropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
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

  Widget buildResultCard() {
    if (result == null) return const SizedBox.shrink();

    final brand = (result!["brand"] ?? "").toString();
    final usedPpsNum = double.tryParse((result!["used_price_per_sqft_lkr"] ?? "").toString());
    final usedPps = usedPpsNum != null ? usedPpsNum.toStringAsFixed(2) : (result!["used_price_per_sqft_lkr"] ?? "").toString();

    final wall = double.tryParse(wallSizeCtrl.text.trim()) ?? 0;
    final budget = double.tryParse(budgetCtrl.text.trim()) ?? 0;

    String tip = "For best results, clean the surface and remove dust before applying skimcoat.";
    if (moistureLevel == "high" && location == "outdoor") {
      tip = "High moisture outdoor area: apply a suitable primer and allow extra drying time between coats.";
    } else if (moistureLevel == "high") {
      tip = "High moisture area: ensure good ventilation and allow extra drying time.";
    } else if (location == "outdoor") {
      tip = "Outdoor surface: avoid applying during rain and direct strong sunlight.";
    } else if (substrateCondition == "cracked") {
      tip = "Cracked surface: repair cracks first, then apply skimcoat for a smooth finish.";
    }

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
              _chip("Budget: LKR ${budget.toStringAsFixed(0)}", Icons.payments_outlined),
              _chip("PPS: $usedPps", Icons.calculate_outlined),
              _chip("Coats: $coatsNeeded", Icons.layers_outlined),
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
                Expanded(child: Text(tip)),
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
      appBar: AppBar(title: const Text("Skimcoat Prediction")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: wallSizeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Wall Size (sqft)"),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: budgetCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Budget (LKR)"),
              ),
              const SizedBox(height: 12),

              dropdown(
                label: "Location",
                value: location,
                items: locations,
                onChanged: (v) => setState(() => location = v ?? location),
              ),
              const SizedBox(height: 12),

              dropdown(
                label: "Surface Material",
                value: surfaceMaterial,
                items: surfaces,
                onChanged: (v) => setState(() => surfaceMaterial = v ?? surfaceMaterial),
              ),
              const SizedBox(height: 12),

              dropdown(
                label: "Moisture Level",
                value: moistureLevel,
                items: moistures,
                onChanged: (v) => setState(() => moistureLevel = v ?? moistureLevel),
              ),
              const SizedBox(height: 12),

              dropdown(
                label: "Substrate Condition",
                value: substrateCondition,
                items: conditions,
                onChanged: (v) => setState(() => substrateCondition = v ?? substrateCondition),
              ),
              const SizedBox(height: 12),

              dropdown(
                label: "Coats Needed",
                value: coatsNeeded.toString(),
                items: const ["1", "2", "3"],
                onChanged: (v) => setState(() => coatsNeeded = int.parse(v ?? "2")),
              ),
              const SizedBox(height: 12),

              dropdown(
                label: "Finish Level",
                value: finishLevel,
                items: finishes,
                onChanged: (v) => setState(() => finishLevel = v ?? finishLevel),
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: loading ? null : predict,
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Predict"),
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