import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../../providers/mongo_project_provider.dart';
import '../../services/mongo_api_service.dart';
import '../../utils/constants.dart';

class TotalCostEstimateScreen extends StatefulWidget {
  final String? uid;
  final String? pid;
  final String? projectName;
  final String? location;
  final String? userName;
  final String? userEmail;

  const TotalCostEstimateScreen({
    super.key,
    this.uid,
    this.pid,
    this.projectName,
    this.location,
    this.userName,
    this.userEmail,
  });

  @override
  State<TotalCostEstimateScreen> createState() =>
      _TotalCostEstimateScreenState();
}

class _TotalCostEstimateScreenState extends State<TotalCostEstimateScreen> {
  final Set<String> _expandedTitles = <String>{};
  final MongoApiService _api = MongoApiService();

  double? _materialCost;
  bool _materialLoading = false;
  String? _materialError;

  double? _laborCost;
  double? _machineryCost;
  double? _vehicleCost;
  bool _boqPredictionLoading = false;
  String? _boqPredictionError;

  @override
  void initState() {
    super.initState();
    _prefetchCostsForTotal();
  }

  Future<void> _prefetchCostsForTotal() async {
    await Future.wait([
      _fetchMaterialCost(),
      _fetchBoqPredictionCosts(),
    ]);
  }

  void _toggleExpanded(String title) {
    setState(() {
      if (_expandedTitles.contains(title)) {
        _expandedTitles.remove(title);
      } else {
        _expandedTitles.add(title);
      }
    });
  }

  String? _resolveProjectId() {
    if ((widget.pid ?? '').trim().isNotEmpty) return widget.pid!.trim();
    final current = context.read<MongoProjectProvider>().currentProject;
    final fromProvider = current?.projectId ?? '';
    if (fromProvider.trim().isNotEmpty) return fromProvider.trim();
    return null;
  }

  Future<void> _fetchMaterialCost() async {
    final pid = _resolveProjectId();
    if (pid == null) {
      setState(() {
        _materialError = 'Project ID not found.';
      });
      return;
    }

    setState(() {
      _materialLoading = true;
      _materialError = null;
    });

    try {
      final total = await _api.getBoqReportGrandTotal(pid);
      if (!mounted) return;
      setState(() {
        _materialCost = total;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _materialError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _materialLoading = false;
      });
    }
  }

  Future<void> _onMaterialCostTap() async {
    final wasExpanded = _expandedTitles.contains('Material Cost');
    _toggleExpanded('Material Cost');

    // Fetch only when opening details for the first time.
    if (!wasExpanded && _materialCost == null && !_materialLoading) {
      await _fetchMaterialCost();
    }
  }

  Future<void> _fetchBoqPredictionCosts() async {
    final pid = _resolveProjectId();
    if (pid == null) {
      setState(() {
        _boqPredictionError = 'Project ID not found.';
      });
      return;
    }

    setState(() {
      _boqPredictionLoading = true;
      _boqPredictionError = null;
    });

    try {
      final costs = await _api.getBoqPredictionCosts(pid);
      if (!mounted) return;
      setState(() {
        _laborCost = costs['labor_cost_lkr'] ?? 0.0;
        _machineryCost = costs['machinery_cost_lkr'] ?? 0.0;
        _vehicleCost = costs['vehicle_cost_lkr'] ?? 0.0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _boqPredictionError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _boqPredictionLoading = false;
      });
    }
  }

  Future<void> _onCostTileTap(String title) async {
    final wasExpanded = _expandedTitles.contains(title);
    _toggleExpanded(title);

    final hasData =
        _laborCost != null && _machineryCost != null && _vehicleCost != null;

    if (!wasExpanded && !hasData && !_boqPredictionLoading) {
      await _fetchBoqPredictionCosts();
    }
  }

  String _formatCurrency(num value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final integer = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return 'Rs. $integer.${parts[1]}';
  }

  String get _materialDetailsText {
    if (_materialLoading) {
      return 'Loading material cost...';
    }
    if (_materialError != null && _materialError!.isNotEmpty) {
      return '';
    }
    if (_materialCost != null) {
      return 'Material Cost (LKR): ${_formatCurrency(_materialCost!)}';
    }
    return '';
  }

  String _buildCostDetailsText({
    required String label,
    required double? value,
  }) {
    if (_boqPredictionLoading) return 'Loading $label...';
    if (_boqPredictionError != null && _boqPredictionError!.isNotEmpty) {
      return '';
    }
    if (value != null) return '$label: ${_formatCurrency(value)}';
    return '';
  }

  double get _totalCostValue =>
      (_materialCost ?? 0.0) +
      (_laborCost ?? 0.0) +
      (_machineryCost ?? 0.0) +
      (_vehicleCost ?? 0.0);

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<MongoProjectProvider>();
    final currentProject = projectProvider.currentProject;

    final resolvedProjectName =
        widget.projectName ?? currentProject?.projectName ?? 'Unnamed Project';
    final resolvedLocation =
        widget.location ?? currentProject?.location ?? 'Unknown Location';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopSummaryCard(
              projectName: resolvedProjectName,
              location: resolvedLocation,
            ),
            const SizedBox(height: 14),
            _buildTotalCostCard(),
            const SizedBox(height: 16),
            _buildPdfDownloadButton(),
            const SizedBox(height: 16),

            Row(
              children: [
                Text(
                  'Cost Breakdown',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Divider(
                    color: Colors.grey.shade300,
                    thickness: 1,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            _buildBreakdownTile(
              context,
              icon: Icons.inventory_2,
              title: 'Material Cost',
              isExpanded: _expandedTitles.contains('Material Cost'),
              onTap: _onMaterialCostTap,
              detailsText: _materialDetailsText,
            ),
            const SizedBox(height: 10),

            _buildBreakdownTile(
              context,
              icon: Icons.engineering,
              title: 'Labor Cost',
              isExpanded: _expandedTitles.contains('Labor Cost'),
              onTap: () => _onCostTileTap('Labor Cost'),
              detailsText: _buildCostDetailsText(
                label: 'Labor Cost (LKR)',
                value: _laborCost,
              ),
            ),
            const SizedBox(height: 10),

            _buildBreakdownTile(
              context,
              icon: Icons.precision_manufacturing,
              title: 'Machinery Cost',
              isExpanded: _expandedTitles.contains('Machinery Cost'),
              onTap: () => _onCostTileTap('Machinery Cost'),
              detailsText: _buildCostDetailsText(
                label: 'Machinery Cost (LKR)',
                value: _machineryCost,
              ),
            ),
            const SizedBox(height: 10),

            _buildBreakdownTile(
              context,
              icon: Icons.local_shipping,
              title: 'Vehicle Cost',
              isExpanded: _expandedTitles.contains('Vehicle Cost'),
              onTap: () => _onCostTileTap('Vehicle Cost'),
              detailsText: _buildCostDetailsText(
                label: 'Vehicle Cost (LKR)',
                value: _vehicleCost,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfDownloadButton() {
    return Center(
      child: SizedBox(
        width: 280,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _generateAndOpenPdf,
          icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
          label: const Text(
            'Download PDF Report',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSummaryCard({
    required String projectName,
    required String location,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            projectName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCostCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Total Cost',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.white.withOpacity(0.35),
          ),
          const SizedBox(height: 12),
          Text(
            _formatCurrency(_totalCostValue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    String? detailsText,
  }) {
    final safeDetailsText = (detailsText ?? '').trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
              trailing: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isExpanded
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    color: isExpanded ? Colors.white : AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: safeDetailsText.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withOpacity(0.22)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildDetailsContent(safeDetailsText),
                    ),
                  ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsContent(String text) {
    final valueText = text.trim();
    final parts = valueText.split(':');

    if (parts.length >= 2) {
      final label = parts.first.trim();
      final amount = parts.sublist(1).join(':').trim();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ],
      );
    }

    return Text(
      valueText,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ─── PDF EXPORT ────────────────────────────────────────────────────────────

  Future<void> _generateAndOpenPdf() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating PDF report…'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFFFF6B35),
      ),
    );

    try {
      final projectProvider = context.read<MongoProjectProvider>();
      final currentProject = projectProvider.currentProject;
      final resolvedProjectName =
          widget.projectName ?? currentProject?.projectName ?? 'Unnamed Project';
      final resolvedLocation =
          widget.location ?? currentProject?.location ?? 'Unknown Location';
      final resolvedUserName = widget.userName ?? 'N/A';
      final resolvedUserEmail = widget.userEmail ?? 'N/A';

      final now = DateTime.now();
      final dateStr = DateFormat('dd MMMM yyyy').format(now);
      final timeStr = DateFormat('hh:mm a').format(now);

      // PDF colour palette
      final pPrimary = PdfColor.fromHex('#FF6B35');
      final pPrimaryDark = PdfColor.fromHex('#E55100');
      final pLightBg = PdfColor.fromHex('#FFF3E0');
      final pDark = PdfColor.fromHex('#212121');
      final pGrey = PdfColor.fromHex('#757575');
      final pBorder = PdfColor.fromHex('#E0E0E0');
      final pSurface = PdfColor.fromHex('#F8F9FA');

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context ctx) => [
            // ── HEADER ────────────────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(color: pPrimary),
              padding: const pw.EdgeInsets.fromLTRB(40, 36, 40, 30),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'COST ESTIMATION REPORT',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Smart Construction Management System',
                            style: const pw.TextStyle(
                              color: PdfColors.grey300,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: pw.BoxDecoration(
                              color: pPrimaryDark,
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(20)),
                            ),
                            child: pw.Text(
                              'OFFICIAL REPORT',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            dateStr,
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            timeStr,
                            style: const pw.TextStyle(
                              color: PdfColors.grey300,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  pw.Container(
                    height: 1,
                    decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#FF8A5B')),
                  ),
                ],
              ),
            ),

            // ── BODY ──────────────────────────────────────────────────────────
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(40, 28, 40, 36),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Project info section
                  _pdfSectionHeader('PROJECT INFORMATION', pPrimary),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(10)),
                      border: pw.Border.all(color: pBorder),
                    ),
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 18, vertical: 4),
                    child: pw.Column(
                      children: [
                        _pdfDetailRow('Project Name', resolvedProjectName,
                            pDark, pGrey, pBorder),
                        _pdfDetailRow(
                            'Location', resolvedLocation, pDark, pGrey, pBorder),
                        _pdfDetailRow('Prepared For', resolvedUserName, pDark,
                            pGrey, pBorder),
                        _pdfDetailRow(
                            'Email', resolvedUserEmail, pDark, pGrey, pBorder),
                        _pdfDetailRow('Report Date', dateStr, pDark, pGrey,
                            pBorder,
                            isLast: true),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 26),

                  // Total cost section
                  _pdfSectionHeader('TOTAL COST SUMMARY', pPrimary),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    width: double.infinity,
                    decoration: pw.BoxDecoration(
                      color: pPrimary,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(12)),
                    ),
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 28, horizontal: 24),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'TOTAL PROJECT COST',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                            letterSpacing: 2.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Container(
                            width: 60,
                            height: 1,
                            decoration:
                                pw.BoxDecoration(color: PdfColors.white)),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          _formatCurrency(_totalCostValue),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 30,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 26),

                  // Cost breakdown section
                  _pdfSectionHeader('COST BREAKDOWN', pPrimary),
                  pw.SizedBox(height: 10),
                  _pdfCostItem('Material Cost', _materialCost, pPrimary,
                      pLightBg, pDark, pGrey),
                  pw.SizedBox(height: 8),
                  _pdfCostItem(
                      'Labor Cost', _laborCost, pPrimary, pLightBg, pDark, pGrey),
                  pw.SizedBox(height: 8),
                  _pdfCostItem('Machinery Cost', _machineryCost, pPrimary,
                      pLightBg, pDark, pGrey),
                  pw.SizedBox(height: 8),
                  _pdfCostItem('Vehicle Cost', _vehicleCost, pPrimary, pLightBg,
                      pDark, pGrey),

                  // Percentage breakdown table
                  if (_totalCostValue > 0) ...[
                    pw.SizedBox(height: 26),
                    _pdfSectionHeader('PERCENTAGE BREAKDOWN', pPrimary),
                    pw.SizedBox(height: 10),
                    _pdfPercentTable(
                        pPrimary, pSurface, pDark, pGrey, pBorder),
                  ],

                  pw.SizedBox(height: 36),

                  // Footer
                  pw.Container(
                      height: 0.8,
                      decoration:
                          pw.BoxDecoration(color: pBorder)),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Smart Construction Management System',
                        style: pw.TextStyle(
                          color: pGrey,
                          fontSize: 9,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                      pw.Text(
                        '© $dateStr  •  All Rights Reserved',
                        style: pw.TextStyle(color: pGrey, fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/cost_estimation_${now.millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      await OpenFile.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── PDF helper widgets ────────────────────────────────────────────────────

  pw.Widget _pdfSectionHeader(String title, PdfColor primary) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 18,
          decoration: pw.BoxDecoration(
            color: primary,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          title,
          style: pw.TextStyle(
            color: primary,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfDetailRow(
    String label,
    String value,
    PdfColor dark,
    PdfColor grey,
    PdfColor border, {
    bool isLast = false,
  }) {
    return pw.Column(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 9),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 130,
                child: pw.Text(label,
                    style: pw.TextStyle(color: grey, fontSize: 11)),
              ),
              pw.Text('  :  ',
                  style: pw.TextStyle(color: grey, fontSize: 11)),
              pw.Expanded(
                child: pw.Text(
                  value,
                  style: pw.TextStyle(
                    color: dark,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          pw.Container(height: 0.5, decoration: pw.BoxDecoration(color: border)),
      ],
    );
  }

  pw.Widget _pdfCostItem(
    String label,
    double? value,
    PdfColor primary,
    PdfColor lightBg,
    PdfColor dark,
    PdfColor grey,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: primary, width: 0.5),
      ),
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 8,
                height: 8,
                decoration: pw.BoxDecoration(
                  color: primary,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                label,
                style: pw.TextStyle(
                  color: grey,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Text(
            value != null ? _formatCurrency(value) : 'N/A',
            style: pw.TextStyle(
              color: dark,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfPercentTable(
    PdfColor primary,
    PdfColor surface,
    PdfColor dark,
    PdfColor grey,
    PdfColor border,
  ) {
    final items = [
      ('Material Cost', _materialCost),
      ('Labor Cost', _laborCost),
      ('Machinery Cost', _machineryCost),
      ('Vehicle Cost', _vehicleCost),
    ];
    final total = _totalCostValue;

    pw.Widget headerCell(String text) => pw.Padding(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );

    pw.Widget dataCell(String text, {bool bold = false}) => pw.Padding(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              color: bold ? dark : grey,
              fontSize: 10,
              fontWeight:
                  bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: primary),
          children: [
            headerCell('Cost Category'),
            headerCell('Amount (LKR)'),
            headerCell('% of Total'),
          ],
        ),
        ...items.asMap().entries.map((e) {
          final idx = e.key;
          final label = e.value.$1;
          final amount = e.value.$2 ?? 0.0;
          final pct = total > 0
              ? (amount / total * 100).toStringAsFixed(1)
              : '0.0';
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: idx.isEven ? surface : PdfColors.white),
            children: [
              dataCell(label),
              dataCell(_formatCurrency(amount), bold: true),
              dataCell('$pct %'),
            ],
          );
        }),
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFF3E0')),
          children: [
            dataCell('TOTAL', bold: true),
            dataCell(_formatCurrency(total), bold: true),
            dataCell('100 %', bold: true),
          ],
        ),
      ],
    );
  }

}