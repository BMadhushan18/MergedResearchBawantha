// Dashboard screen adapted to the new prediction schema.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/dashboard_models.dart';
import '../models/prediction_response.dart';
import '../services/api_service.dart';
import '../services/hive_service.dart';
import '../utils/constants.dart';
import '../widgets/prediction_card.dart';
import '../widgets/donut_chart.dart';
import '../widgets/summary_card.dart';
import '../widgets/totals_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/module_header.dart';
import '../../../core/widgets/custom_button.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService apiService;
  final HiveService hiveService;

  const DashboardScreen({
    super.key,
    required this.apiService,
    required this.hiveService,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _projectIdController = TextEditingController(text: 'P-1001');

  DashboardSummary? _summary;
  List<MultiTaskPredictionResponse> _history = const [];
  bool _loading = false;
  String? _error;
  List<ProjectCatalogItem> _availableProjects = [];
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _loadAvailableProjects();
  }

  Future<void> _loadAvailableProjects() async {
    try {
      final baseUrl = widget.hiveService.getBaseUrl() ?? AppConstants.defaultBaseUrl;
      final results = await Future.wait([
        widget.apiService.getProjectsCatalog(baseUrl: baseUrl),
        widget.apiService.getAllDashboardHistory(baseUrl: baseUrl, limit: 1000),
      ]);

      final allProjects = results[0] as List<ProjectCatalogItem>;
      final allHistory = results[1] as List<DashboardHistoryItem>;
      
      final projectsWithPredictions = allHistory.map((h) => h.projectId).toSet();
      final projects = allProjects.where((p) => projectsWithPredictions.contains(p.projectId)).toList();
      
      final latestProjectId = allHistory.isNotEmpty ? allHistory.first.projectId : null;

      if (!mounted) {
        return;
      }

      setState(() {
        _availableProjects = projects;
        if (projects.isNotEmpty) {
          final hasLatest = latestProjectId != null &&
              projects.any((p) => p.projectId == latestProjectId);
          _selectedProjectId = hasLatest ? latestProjectId : projects.first.projectId;
          _projectIdController.text = _selectedProjectId!;
        } else {
          _selectedProjectId = null;
          _projectIdController.text = '';
        }
      });

      if (_selectedProjectId != null) {
        await _load();
      }
    } catch (_) {
      // Manual project ID input remains available.
    }
  }

  Future<void> _load() async {
    final projectId = _selectedProjectId ?? _projectIdController.text.trim();
    if (projectId.isEmpty) {
      setState(() => _error = 'Select a project');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final baseUrl = widget.hiveService.getBaseUrl() ?? AppConstants.defaultBaseUrl;

    try {
      final summary = await widget.apiService.getDashboardSummary(
        baseUrl: baseUrl,
        projectId: projectId,
      );

      final history = await widget.apiService.getDashboardHistory(
        baseUrl: baseUrl,
        projectId: projectId,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _summary = summary;
        _history = history;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final NumberFormat money = NumberFormat('#,##0', 'en_US');

    final latest = _history.isNotEmpty ? _history.first : null;
    final totalVehicleCost = latest?.projectTotals.totalVehicleCostRs ?? 0;
    final totalMachineryCost = latest?.projectTotals.totalMachineryCostRs ?? 0;
    final totalLabourCost = latest?.projectTotals.totalLabourCostRs ?? 0;
    final totalGang = latest?.projectTotals.totalGangHeadcountPeak ?? 0;
    final totalFuelPerDay = latest?.projectTotals.averageFuelPerDayLitres ?? 0;
    final vehicleCount = latest?.tasks.isNotEmpty == true ? latest!.tasks.first.vehicle.vehicleCount : 0;
    final machineryCount = latest?.tasks.isNotEmpty == true ? latest!.tasks.first.machinery.machineryCount : 0;

    return RefreshIndicator(
      color: AppColors.flameOrange,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.s24),
        shrinkWrap: false,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_availableProjects.isEmpty && !_loading)
            Container(
              margin: const EdgeInsets.only(bottom: AppSizes.s12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.statusProcessingBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.statusProcessingText),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No prediction data available. Run a prediction to see statistics.',
                      style: GoogleFonts.inter(color: AppColors.statusProcessingText, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          _projectPicker(),
          const SizedBox(height: AppSizes.s16),
          CustomButton(
            label: _loading ? 'LOADING ANALYTICS...' : 'LOAD DASHBOARD',
            icon: Icons.analytics,
            onPressed: _loading ? null : _load,
            type: CustomButtonType.primary,
            width: double.infinity,
            height: 48,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.sizeOf(context).width;
              final crossAxisCount = screenWidth > 600 ? 4 : (screenWidth > 400 ? 2 : 1);
              final spacing = 8.0;
              final width = (constraints.maxWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;

              Widget buildCard(String title, String value, IconData icon, Color color) {
                return SizedBox(
                  width: width,
                  child: SummaryCard(
                    title: title,
                    value: value,
                    icon: icon,
                    accentColor: color,
                  ),
                );
              }

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  buildCard('Vehicles', 'Rs. ${money.format(totalVehicleCost)}', Icons.local_shipping, AppColors.flameOrange),
                  buildCard('Labour', '$totalGang', Icons.groups, AppColors.forgeBlackActual),
                  buildCard('Machinery', 'Rs. ${money.format(totalMachineryCost)}', Icons.precision_manufacturing, const Color(0xFF00897B)),
                  buildCard('Fuel', '${totalFuelPerDay.toStringAsFixed(1)} L/day', Icons.local_gas_station, const Color(0xFFF57F17)),
                ],
              );
            },
          ),
          const SizedBox(height: AppSizes.s24),
          TotalsChart(
            summary: DashboardSummary(
              projectId: _selectedProjectId ?? _projectIdController.text.trim(),
              totalVehicleCost: totalVehicleCost,
              totalMachineryCost: totalMachineryCost,
              totalLabourCost: totalLabourCost,
              totalProjectCost: latest?.projectTotals.grandTotalCostRs ?? 0,
              averageConfidenceScore: _summary?.averageConfidenceScore ?? 0,
              totalGangHeadcount: totalGang,
              vehicleTypes: _summary?.vehicleTypes ?? const [],
              machineryTypes: _summary?.machineryTypes ?? const [],
            ),
            vehicleCount: totalVehicleCost,
            machineryCount: totalMachineryCost,
            gangCount: totalLabourCost,
          ),
          DonutChart(
            summary: DashboardSummary(
              projectId: _selectedProjectId ?? _projectIdController.text.trim(),
              totalVehicleCost: totalVehicleCost,
              totalMachineryCost: totalMachineryCost,
              totalLabourCost: totalLabourCost,
              totalProjectCost: latest?.projectTotals.grandTotalCostRs ?? 0,
              averageConfidenceScore: _summary?.averageConfidenceScore ?? 0,
              totalGangHeadcount: totalGang,
              vehicleTypes: _summary?.vehicleTypes ?? const [],
              machineryTypes: _summary?.machineryTypes ?? const [],
            ),
            vehicleCount: vehicleCount,
            machineryCount: machineryCount,
            gangCount: totalGang,
          ),
          const SizedBox(height: AppSizes.s24),
          if (_summary != null) ...[
            Text(
              'Project Total Cost: Rs. ${money.format(_summary!.totalProjectCost)}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            _infoLine('Average Confidence', '${(_summary!.averageConfidenceScore * 100).toStringAsFixed(1)}%'),
            _infoLine('Vehicle Types', _summary!.vehicleTypes.join(', ')),
            _infoLine('Machinery Types', _summary!.machineryTypes.join(', ')),
          ],
          const SizedBox(height: AppSizes.s32),
          Text('PREDICTION HISTORY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.forgeBlackActual, letterSpacing: 1.5)),
          const SizedBox(height: AppSizes.s12),
          if (_history.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSizes.s24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                border: Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: Text('No historical prediction data available.', style: GoogleFonts.inter(color: AppColors.textTertiary)),
            )
          else
            ..._history.map((item) => _historyCard(item, money)),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  Widget _projectPicker() {
    final decoration = InputDecoration(
      labelText: 'Selected Project',
      labelStyle: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 13),
      prefixIcon: const Icon(Icons.folder_open, color: AppColors.forgeBlackActual, size: 18),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.flameOrange, width: 1.5)),
    );

    if (_availableProjects.isNotEmpty) {
      return DropdownButtonFormField<String>(
        isExpanded: true,
        value: _selectedProjectId,
        decoration: decoration,
        items: _availableProjects
            .map(
              (project) => DropdownMenuItem(
                value: project.projectId,
                child: Text(
                  project.projectName.isNotEmpty ? project.projectName : 'Unnamed Project',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.forgeBlackActual),
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedProjectId = value;
            _projectIdController.text = value ?? '';
          });
        },
      );
    }

    return TextField(
      controller: _projectIdController,
      decoration: decoration.copyWith(labelText: 'Project ID (Manual)'),
    );
  }

  Widget _historyCard(MultiTaskPredictionResponse item, NumberFormat money) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(item.projectName),
        subtitle: Text('${item.projectId} • ${item.predictedAt}'),
        childrenPadding: const EdgeInsets.all(12),
        children: [
          _line('Tasks Detected', '${item.tasksDetected}'),
          _line('Grand Total', 'Rs. ${money.format(item.projectTotals.grandTotalCostRs)}'),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: item.tasks.length,
            itemBuilder: (context, index) {
              return TaskResultCard(
                task: item.tasks[index],
                sequence: item.tasks[index].taskSequence,
                initiallyExpanded: false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _line(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(child: Text(key, style: GoogleFonts.inter(color: const Color(0xFF616161)), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
