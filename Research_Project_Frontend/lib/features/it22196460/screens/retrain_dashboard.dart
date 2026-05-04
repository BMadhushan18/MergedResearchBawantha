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

class RetrainDashboard extends StatefulWidget {
  final ApiService apiService;
  final HiveService hiveService;

  const RetrainDashboard({
    super.key,
    required this.apiService,
    required this.hiveService,
  });

  @override
  State<RetrainDashboard> createState() => _RetrainDashboardState();
}

class _RetrainDashboardState extends State<RetrainDashboard> {
  Timer? _statusTimer;
  Map<String, dynamic>? _status;
  List<dynamic> _history = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _startPolling();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
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
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
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

  Future<void> _triggerRetrain() async {
    try {
      final baseUrl = widget.hiveService.getBaseUrl() ?? AppConstants.defaultBaseUrl;
      await widget.apiService.post('/api/v1/admin/retrain/trigger', baseUrl: baseUrl);
      _fetchStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Retraining triggered successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trigger failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _status?['status'] == 'running';
    final progress = (_status?['progress'] ?? 0) / 100.0;
    final pendingCount = _status?['pending_changes'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('ML RETRAINING HUB', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: AppColors.forgeBlackActual,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchInitialData,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.s24),
          children: [
            if (pendingCount > 0) _buildPendingBanner(pendingCount),
            _buildStatusCard(isRunning, progress),
            const SizedBox(height: 24),
            _buildActionCard(isRunning),
            const SizedBox(height: 32),
            Text('RETRAINING HISTORY', 
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.forgeBlackActual, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            ..._history.map((run) => _buildHistoryItem(run)),
            if (_history.isEmpty && !_isLoading)
              Center(child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text('No history found', style: TextStyle(color: AppColors.neutral500)),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingBanner(int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.flameOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.flameOrange, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.flameOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count cost parameter updates pending retraining.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.flameOrange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isRunning, double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.forgeBlackActual,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CURRENT STATUS', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              _statusBadge(_status?['status'] ?? 'idle'),
            ],
          ),
          const SizedBox(height: 20),
          Text(_status?['current_step'] ?? 'System Idle', 
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if (isRunning) ...[
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.flameOrange),
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
            const SizedBox(height: 12),
            Text('${(progress * 100).toInt()}% Complete', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
          ],
          if (!isRunning && _status?['last_retrain_at'] != null)
             Padding(
               padding: const EdgeInsets.only(top: 8),
               child: Text('Last retrain: ${DateFormat('dd MMM, HH:mm').format(DateTime.parse(_status!['last_retrain_at']))}', 
                   style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
             ),
        ],
      ),
    );
  }

  Widget _buildActionCard(bool isRunning) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MANAGEMENT ACTIONS', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: 'RETRAIN ALL MODELS',
                  icon: Icons.refresh_rounded,
                  type: CustomButtonType.primary,
                  onPressed: isRunning ? null : _triggerRetrain,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> run) {
    final date = DateTime.parse(run['created_at']);
    final isSuccess = run['status'] == 'success';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded, 
               color: isSuccess ? Colors.green : Colors.redAccent, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Triggered by ${run['triggered_by'].toUpperCase()}', 
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(DateFormat('dd MMM yyyy, HH:mm').format(date), 
                    style: TextStyle(color: AppColors.neutral500, fontSize: 11)),
              ],
            ),
          ),
          if (isSuccess && run['duration_seconds'] != null)
            Text('${run['duration_seconds'].toInt()}s', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'running': color = Colors.blue; break;
      case 'queued': color = Colors.orange; break;
      case 'completed': color = Colors.green; break;
      case 'failed': color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}
