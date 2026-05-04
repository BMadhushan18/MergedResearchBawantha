import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/config.dart';
import '../core/endpoints.dart';

class WoodPriceScreen extends StatefulWidget {
  const WoodPriceScreen({super.key});

  @override
  State<WoodPriceScreen> createState() => _WoodPriceScreenState();
}

class _WoodPriceScreenState extends State<WoodPriceScreen> {
  final api = ApiClient(kDinethApiBase);

  final _formKey = GlobalKey<FormState>();

  final sizeCuftCtrl = TextEditingController(text: "10");

  String woodSpecies = "teak";
  String woodGrade = "A";
  String location = "indoor";
  String buildingType = "house";

  String moistureLevel = "low";
  String termiteRisk = "medium";
  String treatmentRequired = "none";
  String seasoningLevel = "air-dried";
  String recommendedFinish = "varnish";

  bool loading = false;
  Map<String, dynamic>? result;
  String? error;

  // Keep these in sync with your backend schema choices
  final locations = const ["indoor", "outdoor", "semi"];
  final moistures = const ["low", "medium", "high"];
  final termiteRisks = const ["medium", "high"];
  final treatments = const ["none", "seal", "antitermite", "antitermite+seal"];
  final seasoningLevels = const ["green", "air-dried", "kiln-dried"];
  final finishes = const ["sealant", "varnish", "paint", "oil"];

  // You can customize these to Sri Lankan common woods if you want
  final speciesList = const [
    "teak",
    "mahogany",
    "jak",
    "nadun",
    "pine",
  ];

  final gradeList = const ["A", "B", "C"];

  final buildingTypes = const ["house", "apartment", "shop", "warehouse"];

  @override
  void dispose() {
    sizeCuftCtrl.dispose();
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
        "size_cuft": double.parse(sizeCuftCtrl.text.trim()),
        "wood_species": woodSpecies,
        "wood_grade": woodGrade,
        "location": location,
        "building_type": buildingType,
        "moisture_level": moistureLevel,
        "termite_risk": termiteRisk,
        "treatment_required": treatmentRequired,
        "seasoning_level": seasoningLevel,
        "recommended_finish": recommendedFinish,
      };

      final res = await api.post(Endpoints.woodPredict, body);
      setState(() => result = res);
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

  String _smartTip() {
    if (location == "outdoor" && moistureLevel == "high") {
      return "Outdoor high moisture: prioritize antitermite + sealing and allow proper seasoning before installation.";
    }
    if (termiteRisk == "high") {
      return "High termite risk: antitermite treatment is recommended for long-term durability.";
    }
    if (seasoningLevel == "green") {
      return "Green wood may warp or crack. Air-dried or kiln-dried is safer for most projects.";
    }
    return "Use proper seasoning and a suitable finish to increase durability and reduce maintenance.";
  }

  Widget buildResultCard() {
    if (result == null) return const SizedBox.shrink();

    final price = (result!["predicted_price_per_cuft_lkr"] ?? "").toString();
    final size = double.tryParse(sizeCuftCtrl.text.trim()) ?? 0;
    final totalEst = (double.tryParse(price) ?? 0) * size;

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
                child: const Icon(Icons.attach_money),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Estimated Price",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            "Price per cubic foot (LKR)",
            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),

          Text(
            price,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 10),

          Text(
            "Approx total for ${size.toStringAsFixed(1)} cuft: LKR ${totalEst.toStringAsFixed(2)}",
            style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip("Species: $woodSpecies", Icons.forest_outlined),
              _chip("Grade: $woodGrade", Icons.verified_outlined),
              _chip("Loc: $location", Icons.place_outlined),
              _chip("Moisture: $moistureLevel", Icons.water_drop_outlined),
              _chip("Termite: $termiteRisk", Icons.bug_report_outlined),
              _chip("Treat: $treatmentRequired", Icons.shield_outlined),
              _chip("Season: $seasoningLevel", Icons.wb_sunny_outlined),
              _chip("Finish: $recommendedFinish", Icons.brush_outlined),
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
      appBar: AppBar(title: const Text("Wood Price Estimator")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: sizeCuftCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Required wood volume (cuft)"),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 12),

              dropdown(
                label: "Wood Species",
                value: woodSpecies,
                items: speciesList,
                onChanged: (v) => setState(() => woodSpecies = v ?? woodSpecies),
              ),
              const SizedBox(height: 12),

              dropdown(
                label: "Wood Grade",
                value: woodGrade,
                items: gradeList,
                onChanged: (v) => setState(() => woodGrade = v ?? woodGrade),
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
                label: "Building Type",
                value: buildingType,
                items: buildingTypes,
                onChanged: (v) => setState(() => buildingType = v ?? buildingType),
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
                label: "Termite Risk",
                value: termiteRisk,
                items: termiteRisks,
                onChanged: (v) => setState(() => termiteRisk = v ?? termiteRisk),
              ),
              const SizedBox(height: 12),

              dropdown(
                label: "Treatment Required",
                value: treatmentRequired,
                items: treatments,
                onChanged: (v) => setState(() => treatmentRequired = v ?? treatmentRequired),
              ),
              const SizedBox(height: 12),

              dropdown(
                label: "Seasoning Level",
                value: seasoningLevel,
                items: seasoningLevels,
                onChanged: (v) => setState(() => seasoningLevel = v ?? seasoningLevel),
              ),
              const SizedBox(height: 12),

              dropdown(
                label: "Recommended Finish",
                value: recommendedFinish,
                items: finishes,
                onChanged: (v) => setState(() => recommendedFinish = v ?? recommendedFinish),
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
                          predict();
                        },
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Estimate Price"),
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