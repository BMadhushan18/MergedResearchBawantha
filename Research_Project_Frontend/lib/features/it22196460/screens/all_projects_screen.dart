import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/dashboard_models.dart';
import '../services/api_service.dart';
import '../services/hive_service.dart';
import '../utils/constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Data helpers
// ──────────────────────────────────────────────────────────────────────────────

class _ProjectStats {
  final String projectId;
  final String projectName;
  final int predictionCount;
  final int totalVehicles;
  final int totalLabor;
  final int totalMachinery;
  final double totalFuelLiters;
  final double totalCostLkr;
  final double avgConfidence;
  final DateTime lastPrediction;

  const _ProjectStats({
    required this.projectId,
    required this.projectName,
    required this.predictionCount,
    required this.totalVehicles,
    required this.totalLabor,
    required this.totalMachinery,
    required this.totalFuelLiters,
    required this.totalCostLkr,
    required this.avgConfidence,
    required this.lastPrediction,
  });
}

_ProjectStats _computeStats(
  String projectId, String projectName, List<DashboardHistoryItem> items) {
  int vehicles = 0, labor = 0, machinery = 0;
  double fuel = 0, cost = 0, confSum = 0;
  DateTime last = DateTime(2000);

  for (final item in items) {
    final p = item.predictions;
    final tasks = p['tasks'] as List<dynamic>? ?? const [];
    for (final t in tasks) {
      final task = t as Map;
      final vMap = task['vehicle'] as Map? ?? {};
      vehicles += ((vMap['vehicle_count'] ?? 0) as num).toInt();

      final lMap = task['labour'] as Map? ?? {};
      labor += ((lMap['total_gang'] ?? 0) as num).toInt();

      final mMap = task['machinery'] as Map? ?? {};
      machinery += ((mMap['machinery_count'] ?? 0) as num).toInt();

      final fuelMap = task['fuel'] as Map? ?? {};
      fuel += ((fuelMap['total_fuel_per_day_litres'] ?? 0) as num).toDouble();

      final summaryMap = task['cost_summary'] as Map? ?? {};
      cost += ((summaryMap['task_total_cost_rs'] ?? 0) as num).toDouble();
    }
    confSum += ((p['confidence_score'] ?? 0) as num).toDouble();

    if (item.timestamp.isAfter(last)) last = item.timestamp;
  }

  return _ProjectStats(
    projectId: projectId,
    projectName: projectName,
    predictionCount: items.length,
    totalVehicles: vehicles,
    totalLabor: labor,
    totalMachinery: machinery,
    totalFuelLiters: fuel,
    totalCostLkr: cost,
    avgConfidence:
        items.isEmpty ? 0 : confSum / items.length,
    lastPrediction: last,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Screen
// ──────────────────────────────────────────────────────────────────────────────

class AllProjectsScreen extends StatefulWidget {
  final ApiService apiService;
  final HiveService hiveService;

  const AllProjectsScreen({
    super.key,
    required this.apiService,
    required this.hiveService,
  });

  @override
  State<AllProjectsScreen> createState() => _AllProjectsScreenState();
}

class _AllProjectsScreenState extends State<AllProjectsScreen>
    with TickerProviderStateMixin {
  static const _orange = AppColors.flameOrange;
  static const _navy = AppColors.forgeBlackActual;
  static const _teal = Color(0xFF00695C);
  static const _indigo = Color(0xFF283593);

  bool _loading = false;
  String? _error;
  List<DashboardHistoryItem> _allRecords = [];
  List<String> _projectIds = [];
  List<_ProjectStats> _stats = [];
  Map<String, String> _projectNamesById = const {};

  // Filter / sort
  String _sortBy = 'predictions';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final baseUrl =
        widget.hiveService.getBaseUrl() ?? AppConstants.defaultBaseUrl;
    try {
      final results = await Future.wait([
        widget.apiService.getProjectsCatalog(baseUrl: baseUrl),
        widget.apiService.getAllDashboardHistory(baseUrl: baseUrl, limit: 1000),
      ]);
      final projects = results[0] as List<ProjectCatalogItem>;
      final allRecords = results[1] as List<DashboardHistoryItem>;
      final projectIds = projects.map((p) => p.projectId).toList();
      final projectNamesById = {
        for (final p in projects)
          p.projectId: (p.projectName.isNotEmpty ? p.projectName : p.projectId),
      };

      // Group records by project
      final grouped = <String, List<DashboardHistoryItem>>{};
      for (final id in projectIds) {
        grouped[id] = [];
      }
      for (final item in allRecords) {
        grouped.putIfAbsent(item.projectId, () => []).add(item);
      }

      final stats = grouped.entries
          .map((e) => _computeStats(e.key, projectNamesById[e.key] ?? e.key, e.value))
          .where((s) => s.predictionCount > 0)
          .toList();

      setState(() {
        _projectIds = stats.map((e) => e.projectId).toList();
        _projectNamesById = projectNamesById;
        _allRecords = allRecords;
        _stats = stats;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  List<_ProjectStats> get _filteredSorted {
    var list = _stats.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.projectName.toLowerCase().contains(q) ||
          s.projectId.toLowerCase().contains(q);
    }).toList();

    switch (_sortBy) {
      case 'predictions':
        list.sort((a, b) => b.predictionCount.compareTo(a.predictionCount));
      case 'vehicles':
        list.sort((a, b) => b.totalVehicles.compareTo(a.totalVehicles));
      case 'labor':
        list.sort((a, b) => b.totalLabor.compareTo(a.totalLabor));
      case 'cost':
        list.sort((a, b) => b.totalCostLkr.compareTo(a.totalCostLkr));
      case 'confidence':
        list.sort((a, b) => b.avgConfidence.compareTo(a.avgConfidence));
    }
    return list;
  }

  // ── Aggregate totals ────────────────────────────────────────────────────────
  int get _totalPredictions => _allRecords.length;
  int get _totalVehicles =>
      _stats.fold(0, (s, p) => s + p.totalVehicles);
  int get _totalLabor => _stats.fold(0, (s, p) => s + p.totalLabor);
  int get _totalMachinery =>
      _stats.fold(0, (s, p) => s + p.totalMachinery);
  double get _totalFuel =>
      _stats.fold(0.0, (s, p) => s + p.totalFuelLiters);
  double get _totalCost =>
      _stats.fold(0.0, (s, p) => s + p.totalCostLkr);
  double get _avgConfidence {
    if (_stats.isEmpty) return 0;
    return _stats.fold(0.0, (s, p) => s + p.avgConfidence) / _stats.length;
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
        color: _orange,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            _buildSearchSection(),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _orange)),
              )
            else if (_error != null)
              SliverFillRemaining(child: _buildError())
            else ...[
              SliverToBoxAdapter(child: _buildKpiRow()),
              SliverToBoxAdapter(
                child: _buildTabSection(),
              ),
            ],
          ],
        ),
    );
  }

  // ── Sliver app bar ───────────────────────────────────────────────────────────
  Widget _buildSearchSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s24),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search projects by name...',
              hintStyle: GoogleFonts.inter(color: AppColors.textTertiary),
              prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStatBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style:
                  GoogleFonts.inter(color: Colors.white70, fontSize: 9)),
        ],
      ),
    );
  }

  // ── KPI row ──────────────────────────────────────────────────────────────────
  Widget _buildKpiRow() {
    final fmt = NumberFormat('#,###');
    final kpis = [
      _KpiItem(
          icon: Icons.local_shipping_rounded,
          label: 'Vehicles',
          value: fmt.format(_totalVehicles),
          color: _orange),
      _KpiItem(
          icon: Icons.people_rounded,
          label: 'Labour',
          value: fmt.format(_totalLabor),
          color: _indigo),
      _KpiItem(
          icon: Icons.construction_rounded,
          label: 'Machinery',
          value: fmt.format(_totalMachinery),
          color: _teal),
      _KpiItem(
          icon: Icons.local_gas_station_rounded,
          label: 'Fuel (L)',
          value: fmt.format(_totalFuel.round()),
          color: const Color(0xFFF57C00)),
      _KpiItem(
          icon: Icons.monetization_on_rounded,
          label: 'Cost (LKR)',
          value: _totalCost >= 1e6
              ? '${(_totalCost / 1e6).toStringAsFixed(1)}M'
              : fmt.format(_totalCost.round()),
          color: const Color(0xFF2E7D32)),
      _KpiItem(
          icon: Icons.verified_rounded,
          label: 'Avg Conf.',
          value: '${(_avgConfidence * 100).toStringAsFixed(1)}%',
          color: const Color(0xFF6A1B9A)),
    ];

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Aggregate KPIs', Icons.analytics_outlined, AppColors.forgeBlackActual),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView.count(
                crossAxisCount: constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: constraints.maxWidth > 600 ? 1.5 : 1.3,
                children: kpis.map((kpi) => _buildKpiCard(kpi)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(_KpiItem kpi) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kpi.color.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: kpi.color.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -15,
              bottom: -15,
              child: Icon(
                kpi.icon,
                size: 80,
                color: kpi.color.withOpacity(0.04),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kpi.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(kpi.icon, color: kpi.color, size: 18),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          kpi.value,
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.forgeBlackActual,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Text(
                        kpi.label.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab section ──────────────────────────────────────────────────────────────
  Widget _buildTabSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sort chips
          _sectionLabel('Project Breakdown', Icons.view_list_rounded, _navy),
          const SizedBox(height: 10),
          _buildSortChips(),
          const SizedBox(height: 14),

          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                TabBar(
                  controller: _tabCtrl,
                  indicatorColor: _orange,
                  labelColor: _orange,
                  unselectedLabelColor: const Color(0xFF9E9E9E),
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Cards'),
                    Tab(text: 'Chart'),
                    Tab(text: 'Records'),
                  ],
                ),
                const Divider(height: 1),
                AnimatedBuilder(
                  animation: _tabCtrl,
                  builder: (context, _) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: _tabHeight,
                        maxHeight: _tabHeight + 20,
                      ),
                      child: ClipRect(
                        child: TabBarView(
                          controller: _tabCtrl,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                height: _tabHeight,
                                child: _buildCardsTab(),
                              ),
                            ),
                            SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                height: _tabHeight,
                                child: _buildChartTab(),
                              ),
                            ),
                            SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                height: _tabHeight,
                                child: _buildRecordsTab(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double get _tabHeight {
    final filtered = _filteredSorted;
    switch (_tabCtrl.index) {
      case 0:
        // Use a dynamic height based on item count, but with a larger buffer and max limit
        return filtered.isEmpty ? 140 : (filtered.length * 150.0).clamp(260.0, 2000.0);
      case 1:
        return 400;
      case 2:
        return _allRecords.isEmpty ? 140 : (_allRecords.length * 90.0).clamp(260.0, 1500.0);
      default:
        return 450;
    }
  }

  Widget _buildSortChips() {
    final chips = [
      ('predictions', 'Records'),
      ('vehicles', 'Vehicles'),
      ('labor', 'Labour'),
      ('cost', 'Cost'),
      ('confidence', 'Confidence'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((c) {
          final selected = _sortBy == c.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              label: Text(c.$2,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: selected ? Colors.white : const Color(0xFF555555),
                      fontWeight: FontWeight.w500)),
              selectedColor: _orange,
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              side: BorderSide(
                  color: selected ? _orange : const Color(0xFFDDDDDD)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              onSelected: (_) => setState(() => _sortBy = c.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Cards tab ────────────────────────────────────────────────────────────────
  Widget _buildCardsTab() {
    final list = _filteredSorted;
    if (list.isEmpty) {
      return Center(
          child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('No projects found',
            style: GoogleFonts.inter(color: Color(0xFF9E9E9E))),
      ));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: list.length,
      itemBuilder: (_, i) => _buildProjectCard(list[i], i),
    );
  }

  Widget _buildProjectCard(_ProjectStats s, int index) {
    final dateFmt = DateFormat('dd MMM yyyy');
    final confPct = (s.avgConfidence * 100).toStringAsFixed(1);
    final confColor = s.avgConfidence >= 0.75
        ? _teal
        : s.avgConfidence >= 0.5
            ? _orange
            : Colors.red.shade600;

    final accentColors = [_orange, _indigo, _teal, const Color(0xFF6A1B9A)];
    final accent = accentColors[index % accentColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.business, color: accent, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.projectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Color(0xFF1C1C1E),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('#${index + 1}',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 11)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: confColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          size: 13, color: confColor),
                      const SizedBox(width: 4),
                      Text('$confPct%',
                          style: GoogleFonts.inter(
                              color: confColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('${s.predictionCount} records',
                    style: GoogleFonts.inter(
                        color: Color(0xFF9E9E9E), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _miniStat(Icons.local_shipping_rounded, s.totalVehicles.toString(),
                    'Vehicles', _orange),
                _miniStat(Icons.people_rounded, s.totalLabor.toString(),
                    'Labour', _indigo),
                _miniStat(Icons.construction_rounded,
                    s.totalMachinery.toString(), 'Machinery', _teal),
                _miniStat(
                    Icons.local_gas_station_rounded,
                    '${s.totalFuelLiters.toStringAsFixed(0)}L',
                    'Fuel',
                    const Color(0xFFF57C00)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  'Last: ${s.lastPrediction.year > 2000 ? dateFmt.format(s.lastPrediction) : "—"}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Color(0xFF9E9E9E)),
                ),
                const Spacer(),
                if (s.totalCostLkr > 0)
                  Text(
                    'LKR ${NumberFormat('#,###').format(s.totalCostLkr.round())}',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 9.5, color: Color(0xFF9E9E9E)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ── Chart tab ────────────────────────────────────────────────────────────────
  Widget _buildChartTab() {
    final list = _filteredSorted.take(8).toList(); // max 8 projects for readability
    if (list.isEmpty) {
      return Center(
          child: Text('No data', style: GoogleFonts.inter(color: Color(0xFF9E9E9E))));
    }

    // Grouped bar chart: vehicles/labor/machinery per project
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < list.length; i++) {
      final s = list[i];
      groups.add(BarChartGroupData(
        x: i,
        groupVertically: false,
        barsSpace: 3,
        barRods: [
          BarChartRodData(
              toY: s.totalVehicles.toDouble(),
              color: _orange,
              width: 8,
              borderRadius: BorderRadius.circular(3)),
          BarChartRodData(
              toY: s.totalLabor.toDouble(),
              color: _indigo,
              width: 8,
              borderRadius: BorderRadius.circular(3)),
          BarChartRodData(
              toY: s.totalMachinery.toDouble(),
              color: _teal,
              width: 8,
              borderRadius: BorderRadius.circular(3)),
        ],
      ));
    }

    final maxY = list
        .map((s) => [s.totalVehicles, s.totalLabor, s.totalMachinery]
            .reduce((a, b) => a > b ? a : b)
            .toDouble())
        .reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _legendDot(_orange, 'Vehicles'),
              const SizedBox(width: 16),
              _legendDot(_indigo, 'Labour'),
              const SizedBox(width: 16),
              _legendDot(_teal, 'Machinery'),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY <= 0 ? 10 : maxY * 1.25,
                barGroups: groups,
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.shade100,
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: GoogleFonts.inter(
                            fontSize: 10, color: Color(0xFF9E9E9E)),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= list.length) {
                          return const SizedBox.shrink();
                        }
                        final name = list[i].projectName;
                        final short = name.length > 8 ? name.substring(0, 8) : name;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(short,
                              style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  color: Color(0xFF555555),
                                  fontWeight: FontWeight.w500)),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final labels = ['Vehicles', 'Labour', 'Machinery'];
                      return BarTooltipItem(
                        '${labels[rodIndex]}: ${rod.toY.toInt()}',
                        GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (list.length < _filteredSorted.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Showing top 8 projects. Filter to see others.',
                style:
                    GoogleFonts.inter(fontSize: 10.5, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: Color(0xFF555555))),
      ],
    );
  }

  // ── Records tab ──────────────────────────────────────────────────────────────
  Widget _buildRecordsTab() {
    final records = _allRecords;
    if (records.isEmpty) {
      return Center(
          child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('No records found',
            style: GoogleFonts.inter(color: Color(0xFF9E9E9E))),
      ));
    }
    final dateFmt = DateFormat('dd MMM yy, HH:mm');
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: records.length,
      itemBuilder: (_, i) {
        final item = records[i];
        final p = item.predictions;
        final conf =
            ((p['confidence_score'] ?? 0) as num).toDouble();
        final confStr = '${(conf * 100).toStringAsFixed(0)}%';
        final confColor =
            conf >= 0.75 ? _teal : conf >= 0.5 ? _orange : Colors.red.shade400;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.insert_drive_file_rounded,
                  color: _orange, size: 20),
            ),
            title: Text(
              item.projectName.isNotEmpty
                  ? item.projectName
                  : (_projectNamesById[item.projectId] ?? 'Unnamed Project'),
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF1C1C1E)),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  item.taskDescription.isNotEmpty
                      ? item.taskDescription
                      : 'No description',
                  style: GoogleFonts.inter(
                      fontSize: 11.5, color: Color(0xFF757575)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  dateFmt.format(item.timestamp),
                  style: GoogleFonts.inter(
                      fontSize: 10.5, color: Color(0xFFBBBBBB)),
                ),
              ],
            ),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: confColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(confStr,
                  style: GoogleFonts.inter(
                      color: confColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.red.shade400, size: 52),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: Colors.red.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                  backgroundColor: _orange, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon, Color color) {
    return Row(
      children: [
        Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(text,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: color)),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
class _KpiItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiItem(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
}
