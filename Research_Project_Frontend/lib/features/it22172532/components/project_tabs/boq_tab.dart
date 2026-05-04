import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:boq_frontend/features/it22172532/models/project/boq_model.dart';
import 'package:boq_frontend/features/it22172532/models/project/project_model.dart';
import 'package:boq_frontend/features/it22172532/providers/project_provider.dart';
import 'package:boq_frontend/features/it22172532/services/mongo_api_service.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';

enum _BoqStage {
  fullReport,
  foundation,
  structuralFrame,
  walling,
  flooring,
  general,
}

class BOQTab extends StatefulWidget {
  const BOQTab({super.key});

  @override
  State<BOQTab> createState() => _BOQTabState();
}

class _BOQTabState extends State<BOQTab> {
  final MongoApiService _api = MongoApiService();

  _BoqStage _selectedStage = _BoqStage.fullReport;
  List<Map<String, dynamic>> _boqSections = [];
  List<Map<String, dynamic>> _materialsLibrary = [];
  Map<String, dynamic>? _metrics;
  bool _loading = false;
  bool _exportingPdf = false;
  String? _error;
  final Map<String, String> _brandOverrides = {};
  final Map<String, String> _sizeOverrides = {};

  // Tracks the measurements version we last loaded.
  // When the Overview tab saves an edit it bumps ProjectProvider.measurementsVersion;
  // build() detects the change and triggers an automatic BOQ refetch.
  int _lastMeasurementsVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchReportData());
  }

  Future<void> _fetchReportData() async {
    final pid = context.read<ProjectProvider>().currentProject?.projectId;
    if (pid == null || pid.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _api.loadToken();
      final result = await _api.getBoqReport(pid);
      if (_materialsLibrary.isEmpty) {
        final materials = await _api.getAllMaterials();
        _materialsLibrary = materials
            .whereType<Map<String, dynamic>>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      if (!mounted) return;
      final sections = (result['sections'] as List<dynamic>?) ?? [];
      setState(() {
        _boqSections = sections.cast<Map<String, dynamic>>();
        _metrics = result['metrics'] as Map<String, dynamic>?;
        final hasData = result['hasData'] as bool? ?? _boqSections.isNotEmpty;
        if (!hasData) {
          _error = (result['message'] as String?) ??
              'No extracted measurement data found yet. '
              'Saved BOQ items can still be shown below.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProjectProvider>();
    final project = pp.currentProject;
    final currency = project?.currency ?? 'LKR';

    // â”€â”€ Auto-refetch when Overview tab saves a measurement edit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final ver = pp.measurementsVersion;
    if (ver != _lastMeasurementsVersion && !_loading) {
      _lastMeasurementsVersion = ver;
      if (ver > 0) {
        // Defer to avoid calling setState during build.
        WidgetsBinding.instance
            .addPostFrameCallback((_) { if (mounted) _fetchReportData(); });
      }
    }
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    final sections = _buildVisibleSections(
      project: project,
      savedItems: pp.boqItems,
    );
    final totalRows = sections.fold<int>(0, (sum, section) => sum + section.rows.length);
    final grandTotal =
        sections.fold<double>(0, (sum, section) => sum + section.sectionTotal);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2EA),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'fab_pdf',
            onPressed: _exportingPdf ? null : _downloadBoqPdf,
            backgroundColor: const Color(0xFF212121),
            foregroundColor: Colors.white,
            tooltip: 'Download BOQ PDF',
            child: _exportingPdf
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_rounded, size: 26),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'fab_add',
            onPressed: () => _showAdd(context),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            tooltip: 'Add BOQ Item',
            child: const Icon(Icons.add, size: 28),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchReportData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          children: [
            _buildStageSelector(),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _InfoBanner(
                  message: _error!,
                  background: const Color(0xFFFFF3E0),
                  foreground: const Color(0xFFB26A00),
                ),
              ),
            if (_metrics != null) ...[_buildMetricsCard(_metrics!), const SizedBox(height: 14)],
            if (sections.isEmpty)
              _Empty(onAdd: () => _showAdd(context))
            else
              _ReportCard(
                project: project,
                selectedStage: _selectedStage,
                sections: sections,
                totalRows: totalRows,
                grandTotal: grandTotal,
                currency: currency,
                onBrandTap: _editBrandForRow,
                onSizeTap: _editSizeForRow,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BOQ Report Stage',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3F3524),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _BoqStage.values.map((stage) {
                final selected = _selectedStage == stage;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    label: Text(stage.label),
                    onSelected: (_) => setState(() => _selectedStage = stage),
                    selectedColor: AppColors.primary,
                    backgroundColor: const Color(0xFFF1ECE1),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF5B513F),
                    ),
                    side: BorderSide(
                      color: selected ? AppColors.primary : const Color(0xFFD8CDB7),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // â”€ Metrics summary card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildMetricsCard(Map<String, dynamic> m) {
    final items = <_MetricItem>[
      _MetricItem('Walls', '${m['wallCount'] ?? 0}', 'No.'),
      _MetricItem('Wall Length', '${m['totalWallLength'] ?? 0} m', ''),
      _MetricItem('Wall Area', '${m['totalWallArea'] ?? 0} m\u00b2', ''),
      _MetricItem('Columns', '${m['columnCount'] ?? 0}', 'No.'),
      _MetricItem('Col. Volume', '${m['totalColVolume'] ?? 0} m\u00b3', ''),
      _MetricItem('Floor Area', '${m['floorArea'] ?? 0} m\u00b2', ''),
    ].where((i) {
      final v = i.value;
      return v != '0' && v != '0 m' && v != '0 m\u00b2' && v != '0 m\u00b3';
    }).toList();

    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Extracted Measurements',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: items.map((i) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(i.label,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50))),
                    Text(i.value,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1B5E20))),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<_ReportSection> _buildVisibleSections({
    required ProjectModel? project,
    required List<BOQItem> savedItems,
  }) {
    final sections = <String, List<_ReportRow>>{};
    final accents = <String, Color>{};

    for (final sd in _boqSections) {
      final rawSection = sd['section'] as String? ?? '';
      final sectionName = _normalizeSectionTitle(rawSection);
      if (!_stageMatchesSection(_selectedStage, sectionName)) continue;

      final rowsData = (sd['rows'] as List<dynamic>?) ?? [];
      final rows = rowsData.whereType<Map<String, dynamic>>().map((rowData) {
        final materialName = (rowData['materialName'] as String?)?.trim() ?? '';
        final rowKey = '$sectionName|${materialName.toLowerCase()}';
        final availableBrands = _brandsForMaterial(materialName);
        final availableSizes = _sizesForMaterial(materialName);
        final backendBrand = (rowData['brand'] as String?)?.trim() ?? '';
        final backendSize = (rowData['size'] as String?)?.trim() ?? '';
        return _ReportRow(
          rowKey: rowKey,
          sectionTitle: sectionName,
          boqItemId: null,
          materialName: materialName,
          unit: (rowData['unit'] as String?) ?? '',
          quantity: ((rowData['quantity'] as num?)?.toDouble()) ?? 0,
          size: _effectiveSize(
            rowKey: rowKey,
            fallback: backendSize,
            availableSizes: availableSizes,
          ),
          brand: _effectiveBrand(
            rowKey: rowKey,
            fallback: backendBrand,
            availableBrands: availableBrands,
          ),
          availableBrands: availableBrands,
          availableSizes: availableSizes,
          unitPrice: ((rowData['unitPrice'] as num?)?.toDouble()) ?? 0,
          totalMaterialCost:
              ((rowData['totalMaterialCost'] as num?)?.toDouble()) ?? 0,
        );
      }).where((row) => row.quantity > 0.001).toList();

      if (rows.isEmpty) continue;
      sections.putIfAbsent(sectionName, () => []).addAll(rows);
      accents[sectionName] = _sectionAccent(sectionName);
    }

    for (final item in savedItems) {
      final sectionName = _normalizeSectionTitle(_sectionNameForItem(item));
      if (!_stageMatchesSection(_selectedStage, sectionName)) continue;

      final availableBrands = _brandsForMaterial(item.description);
      final availableSizes = _sizesForMaterial(item.description);
      final savedUp = (item.unitRate != null && (item.unitRate ?? 0) > 0)
          ? item.unitRate!
          : _unitPriceForMaterial(item.description);
      final savedCost = (item.qty ?? 0) * savedUp;
      final row = _ReportRow(
        rowKey: item.boqItemId,
        sectionTitle: sectionName,
        boqItemId: item.boqItemId,
        materialName: item.description,
        unit: item.unit,
        quantity: item.qty ?? 0,
        size: _effectiveSize(
          rowKey: item.boqItemId,
          fallback: item.sizeId,
          availableSizes: availableSizes,
        ),
        brand: _effectiveBrand(
          rowKey: item.boqItemId,
          fallback: item.brandId,
          availableBrands: availableBrands,
        ),
        availableBrands: availableBrands,
        availableSizes: availableSizes,
        unitRate: item.unitRate,
        unitPrice: savedUp,
        totalMaterialCost: savedCost,
      );
      if (row.quantity <= 0) continue;
      sections.putIfAbsent(sectionName, () => []).add(row);
      accents[sectionName] = _sectionAccent(sectionName);
    }

    final ordered = sections.entries.toList()
      ..sort((a, b) => _sectionSortWeight(a.key).compareTo(_sectionSortWeight(b.key)));

    return ordered
        .map((entry) => _ReportSection(
              title: entry.key,
              accent: accents[entry.key] ?? AppColors.primary,
              rows: entry.value,
            ))
        .where((section) => section.rows.isNotEmpty)
        .toList();
  }

  bool _stageMatchesSection(_BoqStage stage, String sectionName) {
    if (stage == _BoqStage.fullReport) return true;
    final n = sectionName.toLowerCase();
    switch (stage) {
      case _BoqStage.fullReport:
        return true;
      case _BoqStage.foundation:
        return n.contains('foundation') || n.contains('substructure');
      case _BoqStage.structuralFrame:
        return n.contains('structural') || n.contains('frame');
      case _BoqStage.walling:
        return n.contains('walling') || n.contains('wall') || n.contains('masonry');
      case _BoqStage.flooring:
        return n.contains('flooring') || n.contains('floor');
      case _BoqStage.general:
        return n.contains('general');
    }
  }

  Color _sectionAccent(String sectionName) {
    final n = sectionName.toLowerCase();
    if (n.contains('foundation'))                  return const Color(0xFF6D4C41);
    if (n.contains('structural') || n.contains('frame')) return const Color(0xFF1565C0);
    if (n.contains('walling') || n.contains('wall'))    return const Color(0xFF2E7D32);
    if (n.contains('flooring'))                    return const Color(0xFF8D6E63);
    return AppColors.primary;
  }

  bool _matchesStageBOQItem(BOQItem item, _BoqStage stage) {
    if (stage == _BoqStage.fullReport) return true;
    final h = '${item.section} ${item.subsection} ${item.description}'.toLowerCase();
    switch (stage) {
      case _BoqStage.fullReport:
        return true;
      case _BoqStage.foundation:
        return h.contains('foundation') || h.contains('footing');
      case _BoqStage.structuralFrame:
        return h.contains('structural') || h.contains('column') || h.contains('beam');
      case _BoqStage.walling:
        return h.contains('wall') || h.contains('masonry');
      case _BoqStage.flooring:
        return h.contains('floor') || h.contains('tile');
      case _BoqStage.general:
        return h.contains('general');
    }
  }

  Future<void> _editBrandForRow(_ReportRow row) async {
    if (row.availableBrands.isEmpty) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _BrandPickerDialog(brands: row.availableBrands, current: row.brand),
    );
    if (picked == null || picked == row.brand) return;

    if (row.boqItemId != null) {
      await _updateSavedBoqItem(row.boqItemId!, brandId: picked);
      return;
    }

    if (!mounted) return;
    setState(() => _brandOverrides[row.rowKey] = picked);
  }

  Future<void> _editSizeForRow(_ReportRow row) async {
    if (row.availableSizes.isEmpty) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SizePickerSheet(sizes: row.availableSizes, current: row.size),
    );
    if (picked == null || picked == row.size) return;

    if (row.boqItemId != null) {
      await _updateSavedBoqItem(row.boqItemId!, sizeId: picked);
      return;
    }

    if (!mounted) return;
    setState(() => _sizeOverrides[row.rowKey] = picked);
  }

  Future<void> _updateSavedBoqItem(
    String boqItemId, {
    String? brandId,
    String? sizeId,
  }) async {
    final pp = context.read<ProjectProvider>();
    final existing = pp.boqItems.where((item) => item.boqItemId == boqItemId).cast<BOQItem?>().firstWhere(
          (item) => item != null,
          orElse: () => null,
        );
    if (existing == null) return;

    try {
      await pp.updateBOQItem(
        BOQItem(
          boqItemId: existing.boqItemId,
          floor: existing.floor,
          section: existing.section,
          subsection: existing.subsection,
          description: existing.description,
          unit: existing.unit,
          qty: existing.qty,
          wastagePercent: existing.wastagePercent,
          unitRate: existing.unitRate,
          amount: existing.amount,
          materialId: existing.materialId,
          brandId: brandId ?? existing.brandId,
          sizeId: sizeId ?? existing.sizeId,
          notes: existing.notes,
          createdAt: existing.createdAt,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update BOQ item: $e')),
      );
    }
  }

  Future<void> _downloadBoqPdf() async {
    final pp = context.read<ProjectProvider>();
    final project = pp.currentProject;
    final sections = _buildVisibleSections(project: project, savedItems: pp.boqItems);
    final currency = project?.currency ?? 'LKR';

    if (sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No BOQ data available to export.')),
      );
      return;
    }

    setState(() => _exportingPdf = true);
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateLabel = DateFormat('dd MMM yyyy').format(now);
      final fileStage = _selectedStage.fileLabel;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(18),
          build: (_) => [
            pw.Center(
              child: pw.Text(
                'Bill of Quantity (BOQ)',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Project: ${project?.projectName ?? 'Current Project'}',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Stage: ${_selectedStage.label}',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Date: $dateLabel', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.7),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.65),
                1: const pw.FlexColumnWidth(2.25),
                2: const pw.FlexColumnWidth(0.7),
                3: const pw.FlexColumnWidth(0.85),
                4: const pw.FlexColumnWidth(0.95),
                5: const pw.FlexColumnWidth(1.0),
                6: const pw.FlexColumnWidth(1.05),
                7: const pw.FlexColumnWidth(1.6),
              },
              children: _buildPdfTableRows(sections, currency),
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName = 'BOQ_${fileStage}_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';
      final file = await _savePdfToDownloads(fileName, pdfBytes);

      if (!mounted) return;

      // Auto-open in the device PDF viewer
      await OpenFile.open(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('BOQ PDF saved: $fileName'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export BOQ PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<File> _savePdfToDownloads(String fileName, List<int> bytes) async {
    Directory? dir;

    if (Platform.isAndroid) {
      // Prefer the public Downloads folder on Android
      try {
        final downloads = Directory('/storage/emulated/0/Download');
        if (await downloads.exists()) {
          dir = downloads;
        }
      } catch (_) {}
    }

    if (Platform.isIOS) {
      dir = await getApplicationDocumentsDirectory();
    }

    // Fallback: app-level external storage, then app documents
    if (dir == null) {
      try {
        dir = await getExternalStorageDirectory();
      } catch (_) {}
    }
    dir ??= await getApplicationDocumentsDirectory();

    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  List<pw.TableRow> _buildPdfTableRows(List<_ReportSection> sections, String currency) {
    final rows = <pw.TableRow>[
      _pdfHeaderRow(currency),
    ];

    for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
      final section = sections[sectionIndex];
      rows.add(_pdfSectionRow(section.title));
      for (var rowIndex = 0; rowIndex < section.rows.length; rowIndex++) {
        final row = section.rows[rowIndex];
        final amount = (row.unitRate ?? 0) > 0 ? row.quantity * (row.unitRate ?? 0) : null;
        rows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: rowIndex.isEven ? PdfColors.white : PdfColor.fromHex('F5F5F5'),
            ),
            children: [
              _pdfCell('${sectionIndex + 1}.${rowIndex + 1}', align: pw.TextAlign.center),
              _pdfCell(row.materialName),
              _pdfCell(row.unit, align: pw.TextAlign.center),
              _pdfCell(_formatQuantity(row.quantity), align: pw.TextAlign.right),
              _pdfCell(_formatMoney(row.unitRate), align: pw.TextAlign.right),
              _pdfCell(_formatMoney(amount), align: pw.TextAlign.right),
              _pdfCell(section.title, align: pw.TextAlign.center),
              _pdfCell(_pdfRemarks(row)),
            ],
          ),
        );
      }
    }

    return rows;
  }

  pw.TableRow _pdfHeaderRow(String currency) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        _pdfCell('No.', bold: true, align: pw.TextAlign.center),
        _pdfCell('Content', bold: true, align: pw.TextAlign.center),
        _pdfCell('Unit', bold: true, align: pw.TextAlign.center),
        _pdfCell('Qty', bold: true, align: pw.TextAlign.center),
        _pdfCell('Rate ($currency)', bold: true, align: pw.TextAlign.center),
        _pdfCell('Amount ($currency)', bold: true, align: pw.TextAlign.center),
        _pdfCell('Work range', bold: true, align: pw.TextAlign.center),
        _pdfCell('Remarks', bold: true, align: pw.TextAlign.center),
      ],
    );
  }

  pw.TableRow _pdfSectionRow(String title) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _pdfCell('', bold: true),
        _pdfCell(title, bold: true),
        _pdfCell(''),
        _pdfCell(''),
        _pdfCell(''),
        _pdfCell(''),
        _pdfCell(''),
        _pdfCell(''),
      ],
    );
  }

  pw.Widget _pdfCell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _pdfRemarks(_ReportRow row) {
    final parts = <String>[];
    if (row.brand.isNotEmpty && row.brand != 'â€”') {
      parts.add('Brand: ${row.brand}');
    }
    if (row.size.isNotEmpty && row.size != 'â€”') {
      parts.add('Size: ${row.size}');
    }
    return parts.isEmpty ? '' : parts.join(' | ');
  }

  String _formatMoney(double? value) {
    if (value == null || value <= 0) return '';
    return NumberFormat('#,##0.00').format(value);
  }

  String _formatQuantity(double quantity) {
    final rounded = quantity.toStringAsFixed(2);
    if (rounded.endsWith('00')) return quantity.toStringAsFixed(0);
    if (rounded.endsWith('0')) return quantity.toStringAsFixed(1);
    return rounded;
  }

  double _unitPriceForMaterial(String name) {
    final baseName =
        name.split('â€“').first.split('â€”').first.trim().toLowerCase();
    for (final m in _materialsLibrary) {
      if ((m['name'] as String? ?? '').toLowerCase().trim() == baseName) {
        return ((m['unitPrice'] as num?)?.toDouble()) ?? 0;
      }
    }
    return 0;
  }

  String _sectionNameForItem(BOQItem item) {
    final source = '${item.section} ${item.subsection} ${item.description}'.toLowerCase();
    if (source.contains('foundation') || source.contains('footing')) return 'Foundation';
    if (source.contains('structural') || source.contains('column') || source.contains('beam')) {
      return 'Structural Frame';
    }
    if (source.contains('wall') || source.contains('masonry')) return 'Walling';
    if (source.contains('floor') || source.contains('tile')) return 'Flooring';
    if (item.section.trim().isNotEmpty) return item.section.trim();
    return 'General';
  }

  String _normalizeSectionTitle(String sectionName) {
    final name = sectionName.trim();
    final lower = name.toLowerCase();
    if (lower.contains('foundation') || lower.contains('substructure')) return 'Foundation';
    if (lower.contains('structural') || lower.contains('frame')) return 'Structural Frame';
    if (lower.contains('walling') || lower.contains('wall') || lower.contains('masonry')) {
      return 'Walling';
    }
    if (lower.contains('flooring') || lower.contains('floor')) return 'Flooring';
    if (lower.contains('general')) return 'General';
    return name.isEmpty ? 'General' : name;
  }

  int _sectionSortWeight(String title) {
    switch (_normalizeSectionTitle(title)) {
      case 'Foundation':
        return 0;
      case 'Structural Frame':
        return 1;
      case 'Walling':
        return 2;
      case 'Flooring':
        return 3;
      case 'General':
        return 4;
      default:
        return 10;
    }
  }

  List<String> _brandsForMaterial(String materialName) {
    final record = _findMaterialRecord(materialName);
    return (record?['brands'] as List<dynamic>?)
            ?.map((value) => '$value'.trim())
            .where((value) => value.isNotEmpty)
            .toList() ??
        const [];
  }

  List<String> _sizesForMaterial(String materialName) {
    final record = _findMaterialRecord(materialName);
    return (record?['sizes'] as List<dynamic>?)
            ?.map((value) => '$value'.trim())
            .where((value) => value.isNotEmpty)
            .toList() ??
        const [];
  }

  Map<String, dynamic>? _findMaterialRecord(String materialName) {
    if (_materialsLibrary.isEmpty) return null;
    final needle = materialName.trim().toLowerCase();
    for (final item in _materialsLibrary) {
      final name = ('${item['name'] ?? ''}').trim().toLowerCase();
      if (name == needle || name.contains(needle) || needle.contains(name)) {
        return item;
      }
    }
    return null;
  }

  String _effectiveBrand({
    required String rowKey,
    required String? fallback,
    required List<String> availableBrands,
  }) {
    final override = _brandOverrides[rowKey];
    if (override != null && override.isNotEmpty) return override;
    final trimmed = fallback?.trim() ?? '';
    if (trimmed.isNotEmpty && trimmed != 'â€”') return trimmed;
    if (availableBrands.isNotEmpty) return availableBrands.first;
    return 'â€”';
  }

  String _effectiveSize({
    required String rowKey,
    required String? fallback,
    required List<String> availableSizes,
  }) {
    final override = _sizeOverrides[rowKey];
    if (override != null && override.isNotEmpty) return override;
    final trimmed = fallback?.trim() ?? '';
    if (trimmed.isNotEmpty && trimmed != 'â€”') return trimmed;
    if (availableSizes.isNotEmpty) return availableSizes.first;
    return 'â€”';
  }

  void _showAdd(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AddBOQSheet(initialStage: _selectedStage.addItemStageLabel),
      );
}

class _ReportCard extends StatelessWidget {
  final ProjectModel? project;
  final _BoqStage selectedStage;
  final List<_ReportSection> sections;
  final int totalRows;
  final double grandTotal;
  final String currency;
  final Future<void> Function(_ReportRow row) onBrandTap;
  final Future<void> Function(_ReportRow row) onSizeTap;

  const _ReportCard({
    required this.project,
    required this.selectedStage,
    required this.sections,
    required this.totalRows,
    required this.grandTotal,
    required this.currency,
    required this.onBrandTap,
    required this.onSizeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5F0),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD6C39A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildProjectInfo(),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0D6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Construction Bill of Quantities (BOQ) table',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedStage.label,
                    style: const TextStyle(
                      color: Color(0xFF6A5C45),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SummaryBadge(label: 'Sections', value: '${sections.length}'),
                _SummaryBadge(label: 'Rows', value: '$totalRows'),
                _SummaryBadge(label: 'Currency', value: currency),
                if (grandTotal > 0)
                  _SummaryBadge(
                    label: 'Total Cost',
                    value: 'LKR ${NumberFormat('#,##0').format(grandTotal)}',
                  ),
              ],
            ),
            const SizedBox(height: 18),
            ...sections.map((section) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _SectionTable(
                    section: section,
                    onBrandTap: onBrandTap,
                    onSizeTap: onSizeTap,
                  ),
                )),
            if (grandTotal > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'GRAND TOTAL MATERIAL COST',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13),
                    ),
                    Text(
                      'LKR ${NumberFormat('#,##0').format(grandTotal)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD6C39A)),
              ),
              child: const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONSTRUCT CORP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3B2F1D),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Construction reporting dashboard',
                  style: TextStyle(fontSize: 11, color: Color(0xFF7A6F60)),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Chicago, IL 60631', style: TextStyle(fontSize: 11)),
            Text('info@construct.com', style: TextStyle(fontSize: 11)),
            Text('construct.com', style: TextStyle(fontSize: 11)),
            Text('222 555 7777', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  Widget _buildProjectInfo() {
    final now = DateTime.now();
    final dateText = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0D6C3)),
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine('Project Name', project?.projectName ?? 'Current Project'),
                const SizedBox(height: 8),
                _InfoLine('Address', project?.location ?? 'Project location not added'),
                const SizedBox(height: 8),
                _InfoLine('Number', project?.projectId ?? 'N/A'),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _InfoLine('Date', dateText, alignEnd: true),
                const SizedBox(height: 8),
                _InfoLine('Stage', selectedStage.shortLabel, alignEnd: true),
                const SizedBox(height: 8),
                _InfoLine('Client', project?.client ?? 'General', alignEnd: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTable extends StatelessWidget {
  final _ReportSection section;
  final Future<void> Function(_ReportRow row) onBrandTap;
  final Future<void> Function(_ReportRow row) onSizeTap;

  const _SectionTable({
    required this.section,
    required this.onBrandTap,
    required this.onSizeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: section.accent.withOpacity(0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: section.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: section.accent,
                    ),
                  ),
                ),
                Text(
                  '${section.rows.length} materials',
                  style: const TextStyle(
                    color: Color(0xFF7C7264),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: FixedColumnWidth(38),
                  1: FixedColumnWidth(210),
                  2: FixedColumnWidth(58),
                  3: FixedColumnWidth(82),
                  4: FixedColumnWidth(145),
                  5: FixedColumnWidth(120),
                  6: FixedColumnWidth(115),
                  7: FixedColumnWidth(135),
                },
                border: TableBorder.all(color: const Color(0xFFE5DFD3), width: 1),
                children: [
                  const TableRow(
                    decoration: BoxDecoration(color: Color(0xFF4A4A4A)),
                    children: [
                      _HeaderCell('No.'),
                      _HeaderCell('Material Name'),
                      _HeaderCell('Unit'),
                      _HeaderCell('Quantity'),
                      _HeaderCell('Size / Spec'),
                      _HeaderCell('Brand'),
                      _HeaderCell('Unit Price (LKR)'),
                      _HeaderCell('Total Cost (LKR)'),
                    ],
                  ),
                  ...section.rows.asMap().entries.map((entry) {
                    final row = entry.value;
                    return TableRow(
                      decoration: BoxDecoration(
                        color: entry.key.isEven ? Colors.white : const Color(0xFFFAF8F4),
                      ),
                      children: [
                        _DataCell('${entry.key + 1}', center: true),
                        _DataCell(row.materialName),
                        _DataCell(row.unit, center: true),
                        _DataCell(_formatQuantity(row.quantity), alignEnd: true),
                        _TapInfoCell(
                          row.size,
                          assetPath: null,
                          isBrand: false,
                          onTap: row.availableSizes.isNotEmpty ? () => onSizeTap(row) : null,
                        ),
                        _TapInfoCell(
                          row.brand,
                          assetPath: _resolveBrandAsset(row.brand),
                          isBrand: true,
                          onTap: row.availableBrands.isNotEmpty ? () => onBrandTap(row) : null,
                        ),
                        _DataCell(
                          row.unitPrice > 0
                              ? NumberFormat('#,##0').format(row.unitPrice)
                              : 'â€”',
                          alignEnd: true,
                        ),
                        _DataCell(
                          row.totalMaterialCost > 0
                              ? NumberFormat('#,##0').format(row.totalMaterialCost)
                              : 'â€”',
                          alignEnd: true,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: section.accent.withOpacity(0.09),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Section Total:',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: section.accent,
                        fontSize: 13),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    section.sectionTotal > 0
                        ? 'LKR ${NumberFormat('#,##0').format(section.sectionTotal)}'
                        : 'â€”',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: section.accent,
                        fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatQuantity(double quantity) {
    final rounded = quantity.toStringAsFixed(2);
    if (rounded.endsWith('00')) {
      return quantity.toStringAsFixed(0);
    }
    if (rounded.endsWith('0')) {
      return quantity.toStringAsFixed(1);
    }
    return rounded;
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;

  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final bool center;
  final bool alignEnd;

  const _DataCell(
    this.text, {
    this.center = false,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    TextAlign textAlign = TextAlign.left;
    if (center) {
      textAlign = TextAlign.center;
    } else if (alignEnd) {
      textAlign = TextAlign.right;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        textAlign: textAlign,
        style: const TextStyle(
          color: Color(0xFF333333),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _InfoLine(this.label, this.value, {this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF655B4B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF2E2A24),
          ),
        ),
      ],
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0D6C3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF7A6F60),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2E2A24),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;
  final Color background;
  final Color foreground;

  const _InfoBanner({
    required this.message,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onAdd;

  const _Empty({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text(
            'No BOQ report data available yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5B513F),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Extract plan measurements first, or add manual BOQ items as a temporary fallback.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF7A6F60)),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add BOQ Item'),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Image asset resolvers
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

String? _resolveBrandAsset(String brandName) {
  final n = brandName.toLowerCase();
  if (n.contains('causeway'))            return 'AppImages/brands/causewayPaints.png';
  if (n.contains('dulux'))               return 'AppImages/brands/duluxPaints.png';
  if (n.contains('lanwa'))               return 'AppImages/brands/lanwaCement.png';
  if (n.contains('robbialac'))           return 'AppImages/brands/robbialacPaints.png';
  if (n.contains('sanstha') || n.contains('insee')) return 'AppImages/brands/sansthaCement.png';
  if (n.contains('taian'))               return 'AppImages/brands/taianSteels.png';
  return null;
}

String? _resolveMaterialAsset(String matName) {
  final n = matName.toLowerCase();
  if (n.contains('cement'))              return 'AppImages/materials/cement.png';
  if (n.contains('aggregate'))           return 'AppImages/materials/aggregates.png';
  if (n.contains('sand'))                return 'AppImages/materials/sand.png';
  if (n.contains('clay brick') || (n.contains('brick') && !n.contains('block')))
                                         return 'AppImages/materials/brick.png';
  if (n.contains('hollow') || n.contains('block'))
                                         return 'AppImages/materials/cementBlock.png';
  if (n.contains('rebar') || n.contains('lintel steel'))
                                         return 'AppImages/materials/steels.png';
  if (n.contains('binding wire'))        return 'AppImages/materials/bindingWire.png';
  if (n.contains('nail'))                return 'AppImages/materials/nails.png';
  if (n.contains('tile'))                return 'AppImages/materials/tile.png';
  if (n.contains('paint') && !n.contains('putty') && !n.contains('puty'))
                                         return 'AppImages/materials/wallPaint.png';
  if (n.contains('putty') || n.contains('puty'))
                                         return 'AppImages/materials/puty.png';
  if (n.contains('primer') || n.contains('skim') || n.contains('filler'))
                                         return 'AppImages/materials/fillerPaints.png';
  return null;
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Tappable info cell for brand / size columns in the BOQ table
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TapInfoCell extends StatelessWidget {
  final String text;
  final String? assetPath;
  final bool isBrand;
  final VoidCallback? onTap;

  const _TapInfoCell(this.text, {this.assetPath, this.isBrand = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isEmpty = text.isEmpty || text == 'â€”' || text == '-';
    if (isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Text('â€”', textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFBDB49C), fontSize: 12)),
      );
    }
    return InkWell(
      onTap: onTap ?? () => _showInfo(context),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (assetPath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Image.asset(assetPath!, width: 16, height: 16, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: isBrand ? const Color(0xFF1565C0) : const Color(0xFF2E7D32),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: isBrand
                          ? const Color(0xFF1565C0)
                          : const Color(0xFF2E7D32))),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 56, vertical: 80),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (assetPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(assetPath!, width: 90, height: 90, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                          isBrand ? Icons.storefront_outlined : Icons.straighten,
                          size: 56, color: const Color(0xFFD0C4AD))),
                )
              else
                Icon(isBrand ? Icons.storefront_outlined : Icons.straighten,
                    size: 56, color: const Color(0xFFD0C4AD)),
              const SizedBox(height: 14),
              Text(isBrand ? 'Brand' : 'Size / Spec',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9E8E75), fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2E2416))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Add BOQ Item bottom sheet â€” fetches real materials from MongoDB
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AddBOQSheet extends StatefulWidget {
  final String initialStage;

  const _AddBOQSheet({required this.initialStage});

  @override
  State<_AddBOQSheet> createState() => _AddBOQSheetState();
}

class _AddBOQSheetState extends State<_AddBOQSheet> {
  final _api = MongoApiService();
  final _qty = TextEditingController();
  final _rate = TextEditingController();

  List<Map<String, dynamic>> _allMaterials = [];
  bool _loadingMaterials = true;

  late String _selectedStage;
  Map<String, dynamic>? _selectedMaterial;
  String? _selectedBrand;
  String? _selectedSize;
  String _selectedUnit = 'No.';
  bool _saving = false;

  static const _stages = [
    'Foundation', 'Structural Frame', 'Walling', 'Flooring', 'General',
  ];
  static const _units = ['No.', 'm', 'mÂ²', 'mÂ³', 'kg', 'bag', 'L', 'ton'];

  @override
  void initState() {
    super.initState();
    _selectedStage = widget.initialStage;
    _loadMaterials();
  }

  @override
  void dispose() {
    _qty.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    try {
      await _api.loadToken();
      final list = await _api.getAllMaterials();
      if (!mounted) return;
      setState(() {
        _allMaterials = list.cast<Map<String, dynamic>>();
        _loadingMaterials = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMaterials = false);
    }
  }

  Future<void> _pickMaterial() async {
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MaterialPickerDialog(materials: _allMaterials),
    );
    if (picked == null) return;
    final brands = (picked['brands'] as List<dynamic>?)?.cast<String>() ?? [];
    final sizes  = (picked['sizes']  as List<dynamic>?)?.cast<String>() ?? [];
    setState(() {
      _selectedMaterial = picked;
      _selectedBrand = brands.isNotEmpty ? brands.first : null;
      _selectedSize  = sizes.isNotEmpty  ? sizes.first  : null;
      final unit = picked['unit'] as String?;
      if (unit != null && unit.isNotEmpty) _selectedUnit = unit;
    });
  }

  Future<void> _pickBrand() async {
    final brands = (_selectedMaterial?['brands'] as List<dynamic>?)?.cast<String>() ?? [];
    if (brands.isEmpty) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _BrandPickerDialog(brands: brands, current: _selectedBrand),
    );
    if (picked != null) setState(() => _selectedBrand = picked);
  }

  Future<void> _pickSize() async {
    final sizes = (_selectedMaterial?['sizes'] as List<dynamic>?)?.cast<String>() ?? [];
    if (sizes.isEmpty) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SizePickerSheet(sizes: sizes, current: _selectedSize),
    );
    if (picked != null) setState(() => _selectedSize = picked);
  }

  Future<void> _save() async {
    if (_selectedMaterial == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a material first')));
      return;
    }
    final qtyText = _qty.text.trim();
    if (qtyText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a quantity')));
      return;
    }
    setState(() => _saving = true);
    final pp = context.read<ProjectProvider>();
    final matName = _selectedMaterial!['name'] as String? ?? '';
    await pp.addBOQItem(BOQItem(
      boqItemId: const Uuid().v4(),
      description: matName,
      unit: _selectedUnit,
      qty: double.tryParse(qtyText) ?? 1,
      unitRate: double.tryParse(_rate.text.trim()) ?? 0,
      section: _selectedStage,
      brandId: _selectedBrand,
      sizeId: _selectedSize,
    ));
    setState(() => _saving = false);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final matName = _selectedMaterial?['name'] as String? ?? '';
    final brands  = (_selectedMaterial?['brands'] as List<dynamic>?)?.cast<String>() ?? [];
    final sizes   = (_selectedMaterial?['sizes']  as List<dynamic>?)?.cast<String>() ?? [];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF9F5EE),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFD1C5AD),
                  borderRadius: BorderRadius.circular(4)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_box_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Add BOQ Item',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2E2416))),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Color(0xFF9E8E75)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE8DCC8)),

            // Content
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(
                    20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 32),
                children: [
                  // â”€â”€ Stage â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  const _SectionLabel('Construction Stage'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _stages.map((s) {
                      final sel = _selectedStage == s;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedStage = s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: sel
                                    ? AppColors.primary
                                    : const Color(0xFFD8CDB7)),
                            boxShadow: sel
                                ? [
                                    BoxShadow(
                                        color: AppColors.primary.withOpacity(0.28),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3))
                                  ]
                                : [],
                          ),
                          child: Text(s,
                              style: TextStyle(
                                  color: sel
                                      ? Colors.white
                                      : const Color(0xFF5B513F),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),

                  // â”€â”€ Material â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  const _SectionLabel('Material'),
                  const SizedBox(height: 8),
                  _loadingMaterials
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ))
                      : GestureDetector(
                          onTap: _pickMaterial,
                          child: _PickerTile(
                            image: matName.isNotEmpty
                                ? _resolveMaterialAsset(matName)
                                : null,
                            label: matName.isNotEmpty
                                ? matName
                                : 'Tap to select material',
                            subtitle: _selectedMaterial != null
                                ? (_selectedMaterial!['category'] as String? ?? '')
                                : 'Choose from materials library',
                            isPlaceholder: matName.isEmpty,
                            accent: AppColors.primary,
                          ),
                        ),
                  const SizedBox(height: 16),

                  // â”€â”€ Brand â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (brands.isNotEmpty) ...[
                    const _SectionLabel('Brand'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickBrand,
                      child: _PickerTile(
                        image: _selectedBrand != null
                            ? _resolveBrandAsset(_selectedBrand!)
                            : null,
                        label: _selectedBrand ?? 'Tap to select brand',
                        subtitle: _selectedBrand == null
                            ? 'Optional â€” choose a preferred brand'
                            : 'Tap to change',
                        isPlaceholder: _selectedBrand == null,
                        accent: const Color(0xFF1565C0),
                        isBrand: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // â”€â”€ Size â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (sizes.isNotEmpty) ...[
                    const _SectionLabel('Size / Specification'),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: sizes.map((sz) {
                          final sel = _selectedSize == sz;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedSize = sz),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? const Color(0xFF2E7D32)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: sel
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFD0C9BA)),
                                  boxShadow: sel
                                      ? [
                                          const BoxShadow(
                                              color: Color(0x332E7D32),
                                              blurRadius: 6,
                                              offset: Offset(0, 2))
                                        ]
                                      : [],
                                ),
                                child: Text(sz,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: sel
                                            ? Colors.white
                                            : const Color(0xFF3D3426))),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // â”€â”€ Unit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  const _SectionLabel('Unit'),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _units.map((u) {
                        final sel = _selectedUnit == u;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedUnit = u),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel
                                    ? const Color(0xFF6D4C41)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: sel
                                        ? const Color(0xFF6D4C41)
                                        : const Color(0xFFD0C9BA)),
                              ),
                              child: Text(u,
                                  style: TextStyle(
                                      color: sel
                                          ? Colors.white
                                          : const Color(0xFF5B513F),
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // â”€â”€ Quantity + Rate â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Row(
                    children: [
                      Expanded(
                          child: _FormField(
                              label: 'Quantity *',
                              controller: _qty,
                              keyboardType: TextInputType.number,
                              icon: Icons.format_list_numbered)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _FormField(
                              label: 'Unit Rate (LKR)',
                              controller: _rate,
                              keyboardType: TextInputType.number,
                              icon: Icons.attach_money)),
                    ],
                  ),
                  const SizedBox(height: 26),

                  // â”€â”€ Save â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline),
                      label: Text(_saving ? 'Addingâ€¦' : 'Add to BOQ',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Material picker dialog â€” grid grouped by category
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MaterialPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> materials;
  const _MaterialPickerDialog({required this.materials});

  @override
  State<_MaterialPickerDialog> createState() => _MaterialPickerDialogState();
}

class _MaterialPickerDialogState extends State<_MaterialPickerDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.materials.where((m) {
      final name = (m['name'] as String? ?? '').toLowerCase();
      final cat  = (m['category'] as String? ?? '').toLowerCase();
      final q    = _search.toLowerCase();
      return q.isEmpty || name.contains(q) || cat.contains(q);
    }).toList();

    // Group by category
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final m in filtered) {
      final cat = m['category'] as String? ?? 'General';
      grouped.putIfAbsent(cat, () => []).add(m);
    }

    return Dialog(
      insetPadding: const EdgeInsets.fromLTRB(10, 36, 10, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Coloured header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF5D4037),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.category_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Select Material',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search materialsâ€¦',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD8CDB7)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF6F2EA),
                ),
              ),
            ),
            // Grid content
            Expanded(
              child: grouped.isEmpty
                  ? const Center(
                      child: Text('No materials found',
                          style: TextStyle(color: Color(0xFFAA9D85))))
                  : ListView(
                      padding:
                          const EdgeInsets.fromLTRB(14, 0, 14, 16),
                      children: grouped.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(entry.key,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF8B7355),
                                      letterSpacing: 0.8)),
                            ),
                            GridView.count(
                              crossAxisCount: 3,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.82,
                              children: entry.value.map((mat) {
                                final name = mat['name'] as String? ?? '';
                                final imgPath = _resolveMaterialAsset(name);
                                return GestureDetector(
                                  onTap: () => Navigator.pop(context, mat),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: const Color(0xFFE5DDD0)),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Color(0x14000000),
                                            blurRadius: 6,
                                            offset: Offset(0, 2))
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        imgPath != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Image.asset(imgPath,
                                                    width: 52,
                                                    height: 52,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) =>
                                                        const Icon(
                                                            Icons.inventory_2_outlined,
                                                            size: 40,
                                                            color: Color(0xFFBDB49C))),
                                              )
                                            : const Icon(
                                                Icons.inventory_2_outlined,
                                                size: 40,
                                                color: Color(0xFFBDB49C)),
                                        const SizedBox(height: 6),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          child: Text(name,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF2E2416))),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Brand picker dialog
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BrandPickerDialog extends StatelessWidget {
  final List<String> brands;
  final String? current;
  const _BrandPickerDialog({required this.brands, this.current});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.branding_watermark_rounded,
                      color: Color(0xFF1565C0), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Select Brand',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2E2416))),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
              children: brands.map((brand) {
                final imgPath = _resolveBrandAsset(brand);
                final isCurrent = brand == current;
                return GestureDetector(
                  onTap: () => Navigator.pop(context, brand),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFFE3F2FD)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isCurrent
                              ? const Color(0xFF1565C0)
                              : const Color(0xFFE0D4C2),
                          width: isCurrent ? 2 : 1),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 6,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        imgPath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(imgPath,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.storefront_outlined,
                                        size: 36,
                                        color: Color(0xFFBDB49C))),
                              )
                            : const Icon(Icons.storefront_outlined,
                                size: 36, color: Color(0xFFBDB49C)),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(brand,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isCurrent
                                      ? const Color(0xFF1565C0)
                                      : const Color(0xFF2E2416))),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(height: 4),
                          const Icon(Icons.check_circle,
                              color: Color(0xFF1565C0), size: 14),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Size picker bottom sheet
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SizePickerSheet extends StatelessWidget {
  final List<String> sizes;
  final String? current;
  const _SizePickerSheet({required this.sizes, this.current});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: const Color(0xFFD1C5AD),
                borderRadius: BorderRadius.circular(4)),
          ),
          const Text('Select Size / Specification',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E2416))),
          const SizedBox(height: 14),
          ...sizes.map((sz) {
            final isCurrent = sz == current;
            return ListTile(
              onTap: () => Navigator.pop(context, sz),
              dense: true,
              leading: Icon(
                isCurrent
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color:
                    isCurrent ? AppColors.primary : const Color(0xFFBDB49C),
              ),
              title: Text(sz,
                  style: TextStyle(
                      fontWeight: isCurrent
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isCurrent
                          ? AppColors.primary
                          : const Color(0xFF3D3426))),
              tileColor: isCurrent
                  ? AppColors.primary.withOpacity(0.06)
                  : null,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            );
          }),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Shared helper widgets for the Add sheet
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8B7355),
            letterSpacing: 0.5));
  }
}

/// A tappable tile showing an image / icon + label + subtitle (used for material and brand selectors).
class _PickerTile extends StatelessWidget {
  final String? image;
  final String label;
  final String subtitle;
  final bool isPlaceholder;
  final Color accent;
  final bool isBrand;

  const _PickerTile({
    required this.image,
    required this.label,
    required this.subtitle,
    required this.isPlaceholder,
    required this.accent,
    this.isBrand = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isPlaceholder
                ? const Color(0xFFD8CDB7)
                : accent.withOpacity(0.5),
            width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isPlaceholder
                  ? const Color(0xFFF1ECE1)
                  : accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isPlaceholder
                      ? const Color(0xFFE0D8C6)
                      : accent.withOpacity(0.25)),
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(image!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                            isBrand
                                ? Icons.storefront_outlined
                                : Icons.inventory_2_outlined,
                            size: 28,
                            color: accent.withOpacity(0.5))),
                  )
                : Icon(
                    isBrand
                        ? Icons.storefront_outlined
                        : Icons.inventory_2_rounded,
                    size: 28,
                    color: isPlaceholder
                        ? const Color(0xFFBDB49C)
                        : accent.withOpacity(0.7)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isPlaceholder
                            ? const Color(0xFFAA9D85)
                            : const Color(0xFF2E2416))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: isPlaceholder
                            ? const Color(0xFFBBAF97)
                            : const Color(0xFF7A6F60))),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              color: isPlaceholder ? const Color(0xFFBDB49C) : accent),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final IconData icon;

  const _FormField({
    required this.label,
    required this.controller,
    this.keyboardType,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8CDB7)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFAA9D85)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: label,
                labelStyle:
                    const TextStyle(fontSize: 12, color: Color(0xFF9E8E75)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on _BoqStage {
  String get label {
    switch (this) {
      case _BoqStage.fullReport:
        return 'Full report';
      case _BoqStage.foundation:
        return 'Foundation';
      case _BoqStage.structuralFrame:
        return 'Structural Frame';
      case _BoqStage.walling:
        return 'Walling';
      case _BoqStage.flooring:
        return 'Flooring';
      case _BoqStage.general:
        return 'General';
    }
  }

  String get shortLabel {
    switch (this) {
      case _BoqStage.fullReport:
        return 'Full';
      case _BoqStage.foundation:
        return 'Foundation';
      case _BoqStage.structuralFrame:
        return 'Frame';
      case _BoqStage.walling:
        return 'Walling';
      case _BoqStage.flooring:
        return 'Flooring';
      case _BoqStage.general:
        return 'General';
    }
  }

  String get addItemStageLabel {
    switch (this) {
      case _BoqStage.foundation:
        return 'Foundation';
      case _BoqStage.structuralFrame:
        return 'Structural Frame';
      case _BoqStage.walling:
        return 'Walling';
      case _BoqStage.flooring:
        return 'Flooring';
      case _BoqStage.general:
        return 'General';
      case _BoqStage.fullReport:
        return 'Foundation';
    }
  }

  String get fileLabel {
    switch (this) {
      case _BoqStage.fullReport:
        return 'full_report';
      case _BoqStage.foundation:
        return 'foundation';
      case _BoqStage.structuralFrame:
        return 'structural_frame';
      case _BoqStage.walling:
        return 'walling';
      case _BoqStage.flooring:
        return 'flooring';
      case _BoqStage.general:
        return 'general';
    }
  }
}

class _ReportSection {
  final String title;
  final Color accent;
  final List<_ReportRow> rows;

  const _ReportSection({
    required this.title,
    required this.accent,
    required this.rows,
  });

  _ReportSection copyWith({List<_ReportRow>? rows}) {
    return _ReportSection(
      title: title,
      accent: accent,
      rows: rows ?? this.rows,
    );
  }

  double get sectionTotal =>
      rows.fold(0.0, (sum, row) => sum + row.totalMaterialCost);
}

class _ReportRow {
  final String rowKey;
  final String sectionTitle;
  final String? boqItemId;
  final String materialName;
  final String unit;
  final double quantity;
  final String size;
  final String brand;
  final List<String> availableBrands;
  final List<String> availableSizes;
  final double? unitRate;
  final double unitPrice;
  final double totalMaterialCost;

  const _ReportRow({
    required this.rowKey,
    required this.sectionTitle,
    required this.boqItemId,
    required this.materialName,
    required this.unit,
    required this.quantity,
    required this.size,
    required this.brand,
    this.availableBrands = const [],
    this.availableSizes = const [],
    this.unitRate,
    this.unitPrice = 0,
    this.totalMaterialCost = 0,
  });
}

class _MetricItem {
  final String label;
  final String value;
  final String unit;
  const _MetricItem(this.label, this.value, this.unit);
}