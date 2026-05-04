import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/prediction_response.dart';
import '../services/api_service.dart';
import '../services/hive_service.dart';
import '../utils/constants.dart';
import '../utils/pdf_downloader_stub.dart'
    if (dart.library.io) '../utils/pdf_downloader_io.dart'
    if (dart.library.html) '../utils/pdf_downloader_web.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/prediction_card.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/module_header.dart';
import '../../../core/widgets/custom_button.dart';
import 'package:google_fonts/google_fonts.dart';

class ResultScreen extends StatelessWidget {
  final ApiService apiService;
  final HiveService hiveService;
  final MultiTaskPredictionResponse? prediction;
  final String projectId;
  final String projectName;
  final String fileName;

  const ResultScreen({
    super.key,
    required this.apiService,
    required this.hiveService,
    this.prediction,
    required this.projectId,
    required this.projectName,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    MultiTaskPredictionResponse? resolved = prediction;
    if (resolved == null && routeArgs is Map && routeArgs['prediction'] is MultiTaskPredictionResponse) {
      resolved = routeArgs['prediction'] as MultiTaskPredictionResponse;
    }

    if (resolved == null) {
      return const Scaffold(body: Center(child: Text('Prediction data not available.')));
    }

    final p = resolved;
    final tasks = [...p.tasks]..sort((a, b) => a.taskSequence.compareTo(b.taskSequence));
    final money = NumberFormat('#,##0', 'en_US');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModuleHeader(
              moduleId: 'M04',
              title: 'Prediction Result',
              description: 'AI-generated logistics analysis for ${p.projectName} in ${p.siteLocation}.',
            ),
            const SizedBox(height: AppSizes.s24),
            
            _projectTotalsBar(p, money),
            const SizedBox(height: AppSizes.s24),
            
            Text(
              'TASK BREAKDOWN',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.forgeBlackActual,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: AppSizes.s12),
            ...tasks.asMap().entries.map(
                  (e) => TaskResultCard(
                    task: e.value,
                    sequence: e.value.taskSequence,
                    initiallyExpanded: e.key == 0,
                  ),
                ),
            const SizedBox(height: AppSizes.s24),
            _projectCostSummaryCard(p, money),
            const SizedBox(height: AppSizes.s12),
            _wasteCard(p),
            const SizedBox(height: AppSizes.s32),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppSizes.s24),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: 'DOWNLOAD PDF',
                  icon: Icons.download,
                  type: CustomButtonType.ghost,
                  onPressed: () => _generatePdf(context, p),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  label: 'SAVE TO DASHBOARD',
                  icon: Icons.save,
                  type: CustomButtonType.primary,
                  onPressed: () => _saveToDashboard(context, p),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _projectTotalsBar(MultiTaskPredictionResponse p, NumberFormat money) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _miniCard('Rs. ${money.format(p.projectTotals.grandTotalCostRs)}', 'Grand Total', AppColors.flameOrange),
          const SizedBox(width: 8),
          _miniCard('${p.projectTotals.totalGangHeadcountPeak} persons', 'Peak Gang', AppColors.forgeBlackActual),
          const SizedBox(width: 8),
          _miniCard('${p.projectTotals.averageFuelPerDayLitres.toStringAsFixed(1)} L/day', 'Avg Fuel', const Color(0xFF00897B)),
          const SizedBox(width: 8),
          _miniCard('${p.workingDays}d', 'Per Task', const Color(0xFF6A1B9A)),
        ],
      ),
    );
  }

  Widget _pill({required String text, required Color color, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _miniCard(String value, String label, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _projectCostSummaryCard(MultiTaskPredictionResponse p, NumberFormat money) {
    return Card(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF6A1B9A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Text('Project Cost Summary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _costLine('Vehicle & Machinery', 'Rs. ${money.format(p.projectTotals.totalVehicleCostRs + p.projectTotals.totalMachineryCostRs)}'),
                _costLine('Labour (all tasks)', 'Rs. ${money.format(p.projectTotals.totalLabourCostRs)}'),
                _costLine('BOQ Value (uploaded)', 'Rs. ${money.format(p.projectTotals.boqTotalRs)}'),
                const Divider(),
                _costLine('Grand Total', 'Rs. ${money.format(p.projectTotals.grandTotalCostRs)}', bold: true),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Peak gang: ${p.projectTotals.totalGangHeadcountPeak} persons on ${p.projectTotals.peakTask}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _costLine(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFF616161))),
          ),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 18 : 14)),
        ],
      ),
    );
  }

  Widget _wasteCard(MultiTaskPredictionResponse p) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.eco, color: Color(0xFF2E7D32)),
        title: const Text('Efficiency Recommendations'),
        childrenPadding: const EdgeInsets.all(12),
        children: p.wasteRecommendations.map((rec) {
          final badgeColor = _categoryColor(rec.category);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FBF7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    rec.category,
                    style: const TextStyle(
                      color: Color(0xFF1B5E20),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(rec.recommendation, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Est. saving: ${rec.estimatedSavingPct.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context, MultiTaskPredictionResponse prediction) async {
    final baseUrl = hiveService.getBaseUrl() ?? AppConstants.defaultBaseUrl;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingOverlay(message: 'Generating PDF...'),
    );

    try {
      final bytes = await apiService.generatePdf(
        baseUrl: baseUrl,
        projectId: prediction.projectId,
      );
      await saveOrOpenPdf(bytes, 'procurement_${prediction.projectId}.pdf');
      if (!context.mounted) {
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF successfully generated and saved!')));
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF generation failed: $e')));
    }
  }

  Future<void> _saveToDashboard(BuildContext context, MultiTaskPredictionResponse prediction) async {
    final baseUrl = hiveService.getBaseUrl() ?? AppConstants.defaultBaseUrl;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingOverlay(message: 'Saving to dashboard...'),
    );

    try {
      await apiService.saveDashboardRecord(
        baseUrl: baseUrl,
        prediction: prediction,
      );
      if (!context.mounted) {
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to dashboard')),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Color _confidenceColor(double score) {
    if (score >= 0.85) {
      return const Color(0xFF388E3C);
    }
    if (score >= 0.75) {
      return const Color(0xFFF57F17);
    }
    return const Color(0xFFC62828);
  }

  String _confidenceLabel(double score) {
    if (score >= 0.85) return 'High';
    if (score >= 0.75) return 'Medium';
    return 'Low';
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Vehicle Utilisation':
        return const Color(0xFFFF6B35);
      case 'Machinery Idle Time':
        return const Color(0xFF00897B);
      case 'Labour Allocation':
        return const Color(0xFF3949AB);
      case 'Fuel Efficiency':
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF2E7D32);
    }
  }
}
