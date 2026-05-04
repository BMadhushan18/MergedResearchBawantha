import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/api_service.dart';
import '../services/hive_service.dart';
import '../utils/constants.dart';

class LogisticsManagementScreen extends StatefulWidget {
  final ApiService apiService;
  final HiveService hiveService;

  const LogisticsManagementScreen({
    super.key,
    required this.apiService,
    required this.hiveService,
  });

  @override
  State<LogisticsManagementScreen> createState() => _LogisticsManagementScreenState();
}

class _LogisticsManagementScreenState extends State<LogisticsManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _statusTimer;
  Map<String, dynamic>? _status;
  List<dynamic> _history = [];
  bool _isLoading = false;

  // Controllers for Cost Updates
  final _fuelPriceController = TextEditingController(text: "330.0");
  String _selectedFuelType = "Auto Diesel";
  final List<String> _fuelTypes = [
    "Petrol 92 Octane", "Petrol 95 Octane", "Auto Diesel", "Super Diesel", "Kerosene"
  ];

  final Map<String, TextEditingController> _labourControllers = {};
  
  final List<String> _roles = [
    "Mason", "Carpenter", "Bar Bender", "Plasterer", "Tiler", 
    "Roofer", "Painter", "Mixer Operator", "Vibrator Operator",
    "Semi-skilled Labourer", "General Labourer", "Cleaning Labourer", "Foreman", "Survey Assistant"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    for (var role in _roles) {
      _labourControllers[role] = TextEditingController(text: "2500");
    }
    _fetchInitialData();
    _startPolling();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _tabController.dispose();
    _fuelPriceController.dispose();
    for (var c in _labourControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _startPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchStatus());
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchStatus(), _fetchHistory()]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchStatus() async {
    try {
      final baseUrl = widget.hiveService.getBaseUrl() ?? AppConstants.defaultBaseUrl;
      final response = await widget.apiService.get('/api/v1/admin/retrain/status', baseUrl: baseUrl);
      if (mounted) {
        setState(() {
          _status = jsonDecode(response.body);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchHistory() async {
    try {
      final baseUrl = widget.hiveService.getBaseUrl() ?? AppConstants.defaultBaseUrl;
      final response = await widget.apiService.get('/api/v1/admin/retrain/history', baseUrl: baseUrl);
      if (mounted) {
        setState(() {
          _history = jsonDecode(response.body);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveFuelPrice() async {
    try {
      final baseUrl = widget.hiveService.getBaseUrl() ?? AppConstants.defaultBaseUrl;
      final type = Uri.encodeComponent(_selectedFuelType);
      await widget.apiService.post('/api/v1/admin/cost-params/fuel?fuel_type=$type&value=${_fuelPriceController.text}', baseUrl: baseUrl);
      _toast("$_selectedFuelType price updated and retrain queued");
    } catch (e) { _toast("Error: $e", isError: true); }
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : AppColors.flameOrange,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('LOGISTICS HUB', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: AppColors.forgeBlackActual,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.flameOrange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'COSTS'),
            Tab(text: 'RECORDS'),
            Tab(text: 'MODELS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCostsTab(),
          _buildRecordsTab(),
          _buildModelsTab(),
        ],
      ),
    );
  }

  Widget _buildCostsTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionHeader("FUEL & OIL PRICES"),
        _buildCostCard(
          title: "Select Fuel Type & Update Price",
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedFuelType,
                decoration: _inputDeco(),
                items: _fuelTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.inter(fontSize: 14)))).toList(),
                onChanged: (v) => setState(() => _selectedFuelType = v!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: _fuelPriceController, keyboardType: TextInputType.number, decoration: _inputDeco().copyWith(prefixText: "Rs. "))),
                  const SizedBox(width: 12),
                  CustomButton(label: "SAVE", type: CustomButtonType.primary, onPressed: _saveFuelPrice, width: 80),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _sectionHeader("LABOUR DAILY RATES"),
        _buildLabourTable(),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildLabourTable() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: _roles.map((role) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(role, style: GoogleFonts.inter(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              SizedBox(
                width: 85,
                child: TextField(
                  controller: _labourControllers[role],
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(prefixText: "Rs. ", border: InputBorder.none, isDense: true),
                  textAlign: TextAlign.end,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.check, color: AppColors.flameOrange, size: 18), 
                onPressed: () => _toast("$role rate saved")
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildRecordsTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionHeader("ADD NEW ASSETS"),
        _buildAddCard(Icons.local_shipping, "NEW VEHICLE", "Register transport assets for training.", () => _showAddDialog("Vehicle")),
        const SizedBox(height: 12),
        _buildAddCard(Icons.construction, "NEW MACHINERY", "Add heavy equipment keywords.", () => _showAddDialog("Machinery")),
        const SizedBox(height: 12),
        _buildAddCard(Icons.inventory_2, "NEW BOQ MATERIAL", "Expand NLP vocabulary.", () => _showAddDialog("Material")),
      ],
    );
  }

  void _showAddDialog(String type) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Add New $type", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: _inputDeco().copyWith(hintText: "Enter $type Name / Keyword"),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text("CANCEL", style: TextStyle(color: AppColors.neutral500, fontWeight: FontWeight.bold))
          ),
          const SizedBox(width: 8),
          CustomButton(
            label: "ADD RECORD",
            type: CustomButtonType.primary,
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                final baseUrl = widget.hiveService.getBaseUrl() ?? AppConstants.defaultBaseUrl;
                final endpoint = type == "Vehicle" ? "/api/v1/admin/records/vehicle" : (type == "Machinery" ? "/api/v1/admin/records/machinery" : "/api/v1/admin/records/material");
                await widget.apiService.post(endpoint, baseUrl: baseUrl, body: {"name": nameController.text.trim()});
                if (mounted) Navigator.pop(context);
                _toast("$type record added successfully");
              } catch (e) { _toast("Error: $e", isError: true); }
            },
            width: 110,
            height: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildAddCard(IconData icon, String title, String sub, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: AppColors.flameOrange.withOpacity(0.1), child: Icon(icon, color: AppColors.flameOrange, size: 20)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(sub, style: GoogleFonts.inter(fontSize: 12, color: AppColors.neutral500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 8),
            const Icon(Icons.add_circle_outline, color: AppColors.flameOrange, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildModelsTab() {
    final isRunning = _status?['status'] == 'running';
    final progress = (_status?['progress'] ?? 0) / 100.0;
    
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_status?['status'] == 'idle' && (_status?['pending_changes'] ?? 0) > 0)
          _banner("COST UPDATES PENDING RETRAINING"),
        
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.forgeBlackActual, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LIVE MODEL STATUS', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 20),
              Text(_status?['current_step'] ?? 'System Idle', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              if (isRunning) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(value: progress, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(AppColors.flameOrange)),
              ],
              const SizedBox(height: 20),
              _warningBox("Vehicle model currently using heuristic fallback (Model > 2GB)"),
            ],
          ),
        ),
        const SizedBox(height: 24),
        CustomButton(label: "TRIGGER FULL RETRAIN", type: CustomButtonType.primary, onPressed: isRunning ? null : _triggerRetrain, width: double.infinity),
        const SizedBox(height: 32),
        Text('TRAINING LOGS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        ..._history.map((h) => _historyItem(h)),
      ],
    );
  }

  Future<void> _triggerRetrain() async {
    final baseUrl = widget.hiveService.getBaseUrl() ?? AppConstants.defaultBaseUrl;
    await widget.apiService.post('/api/v1/admin/retrain/trigger', baseUrl: baseUrl);
    _toast("Retrain triggered");
  }

  Widget _sectionHeader(String text) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)));

  Widget _buildCostCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.neutral600)),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  InputDecoration _inputDeco() => InputDecoration(
    filled: true, fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.flameOrange)),
  );

  Widget _banner(String txt) => Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.flameOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.info_outline, color: AppColors.flameOrange, size: 18), const SizedBox(width: 8), Text(txt, style: GoogleFonts.inter(color: AppColors.flameOrange, fontWeight: FontWeight.bold, fontSize: 11))]));

  Widget _warningBox(String txt) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16), const SizedBox(width: 8), Expanded(child: Text(txt, style: const TextStyle(color: Colors.white70, fontSize: 11)))]));

  Widget _historyItem(Map<String, dynamic> h) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
    child: Row(children: [
      Icon(h['status'] == 'success' ? Icons.check_circle : Icons.error, color: h['status'] == 'success' ? Colors.green : Colors.red, size: 16),
      const SizedBox(width: 12),
      Expanded(child: Text("Auto-retrain completed", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))),
      Text(DateFormat('MM/dd HH:mm').format(DateTime.parse(h['created_at'])), style: TextStyle(color: AppColors.neutral500, fontSize: 10)),
    ]),
  );
}
