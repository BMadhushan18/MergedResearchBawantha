import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boq_frontend/features/it22172532/providers/project_provider.dart';
import 'package:boq_frontend/features/it22172532/services/mongo_api_service.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import 'package:boq_frontend/features/it22172532/screens/materials/door_paint_recommendation_screen.dart';
import 'package:boq_frontend/features/it22172532/screens/materials/window_paint_recommendation_screen.dart';

//  Entry point 

class OverviewTab extends StatefulWidget {
  final void Function(int tabIndex,
      {String? roomLabel, Map<String, dynamic>? roomData})? onNavigateToTab;
  const OverviewTab({super.key, this.onNavigateToTab});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  Map<String, dynamic>? _structure;
  Map<String, dynamic>? _wallingData;
  Map<String, dynamic>? _sfData;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchStructure());
  }

  Future<void> _fetchStructure() async {
    final pid = Provider.of<ProjectProvider>(context, listen: false)
        .currentProject
        ?.projectId;
    if (pid == null || pid.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = MongoApiService();
      await api.loadToken();
      final results = await Future.wait([
        api.getBuildingStructure(pid),
        api.getWalling(pid),
        api.getStructuralFrame(pid),
      ]);
      setState(() {
        _structure   = results[0].isEmpty ? null : results[0];
        _wallingData = results[1].isEmpty ? null : results[1];
        _sfData      = results[2].isEmpty ? null : results[2];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProjectProvider>().currentProject;
    if (p == null) return const Center(child: Text('No project selected'));

    return RefreshIndicator(
      onRefresh: _fetchStructure,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(_error!, onRetry: _fetchStructure)
              : _structure == null && _wallingData == null
                  ? _NoDataView(onRetry: _fetchStructure)
                  : _OverviewBody(
                      data: _structure ?? {},
                      wallingData: _wallingData,
                      sfData: _sfData,
                      onNavigateToTab: widget.onNavigateToTab,
                    ),
    );
  }
}

//  Main body 

class _OverviewBody extends StatefulWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic>? wallingData;
  final Map<String, dynamic>? sfData;
  final void Function(int tabIndex,
      {String? roomLabel, Map<String, dynamic>? roomData})? onNavigateToTab;
  const _OverviewBody({
    required this.data,
    this.wallingData,
    this.sfData,
    this.onNavigateToTab,
  });

  @override
  State<_OverviewBody> createState() => _OverviewBodyState();
}

class _OverviewBodyState extends State<_OverviewBody> {
  bool _foundationExpanded = false;
  bool _wallingExpanded = false;
  bool _sfExpanded = false;
  String _selectedFloor = 'Ground Floor';

  Map<String, dynamic>? _map(dynamic v) =>
      v is Map<String, dynamic> ? v : null;

  String _fmt(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    return (s.isEmpty || s == 'null') ? '' : s;
  }

  @override
  Widget build(BuildContext context) {
    final raw = _map(widget.data['data']) ?? widget.data;
    final output = _map(raw['output']);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        //  Plan Info 
        _PlanInfoCard(
          scale: _fmt(output?['scaleText']),
          units: _fmt(output?['units']),
          floorArea: _fmt(output?['floorAreaReported']),
        ),
        const SizedBox(height: 20),

        //  Quick Actions
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.receipt_long_rounded,
                label: 'View BOQ',
                color: const Color(0xFF00897B),
                onTap: () => widget.onNavigateToTab?.call(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.view_in_ar_rounded,
                label: '3D View',
                color: const Color(0xFF5E35B1),
                onTap: () => widget.onNavigateToTab?.call(8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        //  Section heading 
        const Text(
          'Building Components',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 12),

        //  Foundation 
        _ExpandableSection(
          icon: Icons.foundation,
          label: 'Foundation',
          color: const Color(0xFF4E342E),
          isExpanded: _foundationExpanded,
          onToggle: () =>
              setState(() => _foundationExpanded = !_foundationExpanded),
          child: _FoundationContent(raw: raw),
        ),
        const SizedBox(height: 10),

        //  Floor selector 
        _FloorSelector(
          selected: _selectedFloor,
          onChanged: (v) => setState(() => _selectedFloor = v),
        ),
        const SizedBox(height: 10),

        //  Walling 
        _ExpandableSection(
          icon: Icons.crop_square_outlined,
          label: 'Walling',
          color: const Color(0xFF2E7D32),
          isExpanded: _wallingExpanded,
          onToggle: () => setState(() => _wallingExpanded = !_wallingExpanded),
          child: _WallingContent(
            raw: raw,
            floor: _selectedFloor,
            wallingData: widget.wallingData,
          ),
        ),
        const SizedBox(height: 10),

        //  Structural Frame 
        _ExpandableSection(
          icon: Icons.account_tree_outlined,
          label: 'Structural Frame',
          color: const Color(0xFF1565C0),
          isExpanded: _sfExpanded,
          onToggle: () => setState(() => _sfExpanded = !_sfExpanded),
          child: _SFContent(sfData: widget.sfData),
        ),
        const SizedBox(height: 10),

                const SizedBox(height: 24),
      ],
    );
  }
}

//  Plan Info Card 

class _PlanInfoCard extends StatelessWidget {
  final String scale;
  final String units;
  final String floorArea;
  const _PlanInfoCard(
      {required this.scale, required this.units, required this.floorArea});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.map_outlined, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Plan Info',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              _PlanInfoChip(label: 'Scale', value: scale),
              const SizedBox(width: 10),
              _PlanInfoChip(label: 'Units', value: units),
              const SizedBox(width: 10),
              _PlanInfoChip(label: 'Floor Area', value: floorArea),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanInfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _PlanInfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

//  Floor Selector 

class _FloorSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _FloorSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ['Ground Floor', 'First Floor'].map((floor) {
          final isSelected = selected == floor;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(floor),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(40),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  floor,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

//  Expandable Section 

class _ExpandableSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  const _ExpandableSection({
    required this.icon,
    required this.label,
    required this.color,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down,
                        color: color, size: 22),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Container(
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: child,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

//  Foundation Content 

class _FoundationContent extends StatelessWidget {
  final Map<String, dynamic> raw;
  const _FoundationContent({required this.raw});

  Map<String, dynamic>? _map(dynamic v) =>
      v is Map<String, dynamic> ? v : null;

  String _fmt(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    return (s.isEmpty || s == 'null') ? '' : s;
  }

  @override
  Widget build(BuildContext context) {
    final levels = _map(raw['levels']);
    final groundLevel = _map(levels?['groundFloor']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (groundLevel != null) ...[
          _KVRow('Plinth Height', _fmt(groundLevel['plinthHeight'])),
          _KVRow('Clear Height', _fmt(groundLevel['clearHeight'])),
          _KVRow('Slab Thickness', _fmt(groundLevel['slabThickness'])),
        ],
        const _PlaceholderNote(
            'Foundation details will appear here once extracted from the plan.'),
      ],
    );
  }
}

//  Walling Content

class _WallingContent extends StatefulWidget {
  final Map<String, dynamic> raw;
  final String floor;
  final Map<String, dynamic>? wallingData;
  const _WallingContent({
    required this.raw,
    required this.floor,
    this.wallingData,
  });

  @override
  State<_WallingContent> createState() => _WallingContentState();
}

class _WallingContentState extends State<_WallingContent> {
  // wall key -> user-selected width override (optimistic)
  final Map<String, String> _widthOverrides = {};
  // wall keys currently being saved to the backend
  final Set<String> _savingWalls = {};

  static const _brickSizes = [
    {'label': '115 mm  (Half brick — default)', 'value': '0.1150 m'},
    {'label': '230 mm  (Full brick)', 'value': '0.2300 m'},
    {'label': '102 mm  (4")', 'value': '0.1020 m'},
    {'label': '275 mm  (Cavity wall)', 'value': '0.2750 m'},
    {'label': '340 mm  (1.5 brick)', 'value': '0.3400 m'},
  ];

  Map<String, dynamic>? _map(dynamic v) =>
      v is Map<String, dynamic> ? v : null;

  String _fmt(dynamic v) {
    if (v == null) return '—';
    final s = v.toString().trim();
    return (s.isEmpty || s == 'null') ? '—' : s;
  }

  /// Returns the width to display: override > stored > default 115 mm
  String _wallWidth(String key, dynamic raw) {
    if (_widthOverrides.containsKey(key)) return _widthOverrides[key]!;
    final v = _fmt(raw);
    return (v == '—') ? '0.1150 m' : v;
  }

  void _pickBrickWidth(BuildContext ctx, String wallKey, String current) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SizePickerSheet(
        title: 'Select Wall Width  ($wallKey)',
        items: _brickSizes.map((s) => s['label']!).toList(),
        currentValue: current,
        onSelect: (idx) {
          final newVal = _brickSizes[idx]['value']!;
          setState(() => _widthOverrides[wallKey] = newVal);  // optimistic UI
          _saveWallWidth(ctx, wallKey, newVal);                // persist to DB
        },
      ),
    );
  }

  /// Persist the new wall width to the DB via PATCH, then bump the
  /// measurements version so the BOQ tab auto-refreshes.
  Future<void> _saveWallWidth(
      BuildContext ctx, String wallKey, String valueStr) async {
    final pid =
        ctx.read<ProjectProvider>().currentProject?.projectId ?? '';
    if (pid.isEmpty) return;

    final widthM =
        double.tryParse(valueStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

    setState(() => _savingWalls.add(wallKey));
    try {
      final api = MongoApiService();
      await api.loadToken();
      await api.patchWalling(pid, walls: {
        wallKey: {'width': widthM}
      });
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      if (ctx.mounted) {
        ctx.read<ProjectProvider>().markMeasurementsChanged();
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Measurement saved — BOQ will recalculate'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _widthOverrides.remove(wallKey)); // revert optimistic
      // ignore: use_build_context_synchronously
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
              content: Text('Save failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingWalls.remove(wallKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGround = widget.floor == 'Ground Floor';

    final wRaw = widget.wallingData != null
        ? (_map(widget.wallingData!['data']) ?? widget.wallingData!)
        : null;
    final fallbackRaw = _map(widget.raw['data']) ?? widget.raw;

    final wOutput = _map(wRaw?['output']);
    final totalWallsVal = wOutput?['totalWalls'];
    final units = _fmt(wOutput?['units']);

    final groundFloorW = _map(wRaw?['groundFloor']);
    final wallsW = _map(groundFloorW?['walls']);

    final groundFloorFb = _map(fallbackRaw['groundFloor']);
    final wallsFb = _map(groundFloorFb?['walls']);

    final walls = isGround ? (wallsW ?? wallsFb) : null;
    final totalWalls =
        totalWallsVal?.toString() ?? walls?.length.toString() ?? '—';

    final doors = _map(wRaw?['doors']);
    final windows = _map(wRaw?['windows']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FloorBadge(widget.floor),
        if (!isGround) ...[
          const SizedBox(height: 12),
          const _PlaceholderNote(
              'First floor walling data will appear here once extracted.'),
        ],
        if (isGround) ...[
          const SizedBox(height: 12),
          // Summary bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withAlpha(12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2E7D32).withAlpha(40)),
            ),
            child: Row(children: [
              const Icon(Icons.crop_square_outlined,
                  size: 16, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Text(
                'Total Walls: $totalWalls',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E7D32)),
              ),
              if (units.isNotEmpty && units != '—') ...[
                const Spacer(),
                Text('Units: $units',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ]),
          ),
          const SizedBox(height: 16),

          // -- Walls (with tappable Width column) --
          const _SectionLabel('Walls',
              icon: Icons.crop_square_outlined,
              color: Color(0xFF2E7D32)),
          const SizedBox(height: 6),
          if (walls != null && walls.isNotEmpty)
            _buildWallsTable(context, walls)
          else
            const _PlaceholderNote(
                'No wall data found. Analyse a building plan to populate this section.'),
          const SizedBox(height: 16),

          // -- Door Schedule --
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionLabel('Door Schedule',
                  icon: Icons.door_front_door_outlined,
                  color: Color(0xFF5D4037)),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DoorPaintRecommendationScreen(
                      doors: doors,
                    ),
                  ),
                ),
                icon: const Icon(Icons.recommend_outlined, size: 13),
                label: const Text('Recommendation',
                    style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF5D4037),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (doors != null && doors.isNotEmpty)
            _MeasurementTable(
              color: const Color(0xFF5D4037),
              headers: const ['Door', 'Width', 'Height', 'Type', 'Qty'],
              rows: doors.entries.map((e) {
                final d = _map(e.value);
                return [
                  e.key,
                  _fmt(d?['width']),
                  _fmt(d?['height']),
                  _fmt(d?['type']),
                  _fmt(d?['quantity']),
                ];
              }).toList(),
            )
          else
            const _PlaceholderNote('No door schedule found.'),
          const SizedBox(height: 16),

          // -- Window & FW Schedule --
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionLabel('Window & FW Schedule',
                  icon: Icons.window_outlined,
                  color: Color(0xFF00695C)),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WindowPaintRecommendationScreen(
                      windows: windows,
                    ),
                  ),
                ),
                icon: const Icon(Icons.recommend_outlined, size: 13),
                label: const Text('Recommendation',
                    style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00695C),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (windows != null && windows.isNotEmpty)
            _MeasurementTable(
              color: const Color(0xFF00695C),
              headers: const ['Mark', 'Width', 'Height', 'Type', 'Qty'],
              rows: windows.entries.map((e) {
                final w = _map(e.value);
                return [
                  e.key,
                  _fmt(w?['width']),
                  _fmt(w?['height']),
                  _fmt(w?['type']),
                  _fmt(w?['quantity']),
                ];
              }).toList(),
            )
          else
            const _PlaceholderNote('No window / FW schedule found.'),
        ],
      ],
    );
  }

  // Walls table with tappable width cells
  Widget _buildWallsTable(BuildContext ctx, Map<String, dynamic> walls) {
    const color = Color(0xFF2E7D32);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Table(
        border: TableBorder.all(color: color.withAlpha(40), width: 1),
        columnWidths: const {
          0: FlexColumnWidth(1.4),
          1: FlexColumnWidth(1.3),
          2: FlexColumnWidth(1.0),
          3: FlexColumnWidth(1.0),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: color.withAlpha(30)),
            children: ['Wall', 'Width \u270E', 'Length', 'Height']
                .map((h) => _hCell(h, color))
                .toList(),
          ),
          ...walls.entries.toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final e = entry.value;
            final w = e.value is Map<String, dynamic>
                ? e.value as Map<String, dynamic>
                : <String, dynamic>{};
            final widthVal = _wallWidth(e.key, w['width']);
            return TableRow(
              decoration: BoxDecoration(
                  color: idx.isEven ? Colors.white : color.withAlpha(8)),
              children: [
                _dCell(e.key, color),
                // Tappable width cell
                GestureDetector(
                  onTap: _savingWalls.contains(e.key)
                      ? null
                      : () => _pickBrickWidth(ctx, e.key, widthVal),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 7),
                    color: Colors.transparent,
                    child: _savingWalls.contains(e.key)
                        ? const Center(
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation(
                                    Color(0xFF1565C0)),
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  widthVal,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1565C0),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.edit_outlined,
                                  size: 11, color: Color(0xFF1565C0)),
                            ],
                          ),
                  ),
                ),
                _dCell(_fmt(w['length']), color),
                _dCell(_fmt(w['height']), color),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _hCell(String t, Color c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Text(t,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: c),
            textAlign: TextAlign.center),
      );

  Widget _dCell(String t, Color c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Text(t.isEmpty ? '—' : t,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            textAlign: TextAlign.center),
      );
}

// --- Measurement Table ------------------------------------------------------

class _MeasurementTable extends StatelessWidget {
  final Color color;
  final List<String> headers;
  final List<List<String>> rows;

  const _MeasurementTable({
    required this.color,
    required this.headers,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Table(
        border: TableBorder.all(color: color.withAlpha(40), width: 1),
        columnWidths: {
          0: const FlexColumnWidth(1.4),
          for (int i = 1; i < headers.length; i++) i: const FlexColumnWidth(1),
        },
        children: [
          // Header
          TableRow(
            decoration: BoxDecoration(color: color.withAlpha(30)),
            children: headers
                .map((h) => _cell(h, isHeader: true, color: color))
                .toList(),
          ),
          // Data rows
          ...rows.asMap().entries.map((entry) {
            final even = entry.key.isEven;
            return TableRow(
              decoration: BoxDecoration(
                color: even ? Colors.white : color.withAlpha(8),
              ),
              children: entry.value
                  .map((v) => _cell(v.isEmpty ? '—' : v, color: color))
                  .toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool isHeader = false, required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 11 : 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? color : Colors.black87,
        ),
        textAlign: isHeader ? TextAlign.center : TextAlign.center,
      ),
    );
  }
}

//  Structural Frame Content

class _SFContent extends StatefulWidget {
  final Map<String, dynamic>? sfData;
  const _SFContent({this.sfData});

  @override
  State<_SFContent> createState() => _SFContentState();
}

class _SFContentState extends State<_SFContent> {
  // column key -> {width, length} overrides (optimistic)
  final Map<String, String> _widthOverrides = {};
  final Map<String, String> _lengthOverrides = {};
  // "C1_Width" / "C1_Length" — currently being saved to backend
  final Set<String> _savingDims = {};

  // Standard square column sizes (width == length for each)
  static const _columnSizes = [
    {'label': '225 \u00d7 225 mm  (9\u2033 \u00d7 9\u2033 — default)', 'dim': '0.2250 m'},
    {'label': '300 \u00d7 300 mm  (12\u2033 \u00d7 12\u2033)', 'dim': '0.3000 m'},
    {'label': '375 \u00d7 375 mm  (15\u2033 \u00d7 15\u2033)', 'dim': '0.3750 m'},
    {'label': '450 \u00d7 450 mm  (18\u2033 \u00d7 18\u2033)', 'dim': '0.4500 m'},
    {'label': '600 \u00d7 600 mm  (24\u2033 \u00d7 24\u2033)', 'dim': '0.6000 m'},
  ];

  Map<String, dynamic>? _map(dynamic v) =>
      v is Map<String, dynamic> ? v : null;

  String _fmt(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    return (s.isEmpty || s == 'null') ? '' : s;
  }

  String _colDim(Map<String, String> overrides, String key, dynamic raw,
      String defaultVal) {
    if (overrides.containsKey(key)) return overrides[key]!;
    final v = _fmt(raw);
    return v.isEmpty ? defaultVal : v;
  }

  void _pickColumnSize(
      BuildContext ctx, String colKey, String whichDim, String current) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SizePickerSheet(
        title: 'Select Column $whichDim  ($colKey)',
        items: _columnSizes.map((s) => s['label']!).toList(),
        currentValue: current,
        onSelect: (idx) {
          final val = _columnSizes[idx]['dim']!;
          setState(() {
            if (whichDim == 'Width') {
              _widthOverrides[colKey] = val;
            } else {
              _lengthOverrides[colKey] = val;
            }
          });
          _saveColumnDim(ctx, colKey, whichDim, val); // persist to DB
        },
      ),
    );
  }

  /// Persist the updated column dimension to the DB via PATCH, then bump the
  /// measurements version so the BOQ tab auto-refreshes.
  Future<void> _saveColumnDim(
      BuildContext ctx, String colKey, String dim, String valueStr) async {
    final pid =
        ctx.read<ProjectProvider>().currentProject?.projectId ?? '';
    if (pid.isEmpty) return;

    final dimM =
        double.tryParse(valueStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final field = dim == 'Width' ? 'width' : 'length';
    final saveKey = '${colKey}_$dim';

    setState(() => _savingDims.add(saveKey));
    try {
      final api = MongoApiService();
      await api.loadToken();
      await api.patchStructuralFrame(pid, columns: {
        colKey: {field: dimM}
      });
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      if (ctx.mounted) {
        ctx.read<ProjectProvider>().markMeasurementsChanged();
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Measurement saved — BOQ will recalculate'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1565C0),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // ignore: curly_braces_in_flow_control_structures
        if (dim == 'Width') _widthOverrides.remove(colKey);
        else _lengthOverrides.remove(colKey);
      });
      // ignore: use_build_context_synchronously
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
              content: Text('Save failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingDims.remove(saveKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sfData == null) {
      return const _PlaceholderNote(
          'No structural frame data found. Analyse a building plan first.');
    }

    final raw = _map(widget.sfData!['data']) ?? widget.sfData!;
    final output = _map(raw['output']);
    final groundFloor = _map(raw['groundFloor']);
    final columns = _map(groundFloor?['columns']);
    final totalColumns =
        output?['totalColumns']?.toString() ?? columns?.length.toString() ?? '—';
    final units = _fmt(output?['units']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withAlpha(12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1565C0).withAlpha(40)),
          ),
          child: Row(children: [
            const Icon(Icons.account_tree_outlined,
                size: 16, color: Color(0xFF1565C0)),
            const SizedBox(width: 8),
            Text(
              'Total Columns: $totalColumns',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1565C0)),
            ),
            if (units.isNotEmpty) ...[
              const Spacer(),
              Text('Units: $units',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        if (columns != null && columns.isNotEmpty)
          _buildColumnsTable(context, columns)
        else
          const _PlaceholderNote('No column data available.'),
      ],
    );
  }

  Widget _buildColumnsTable(
      BuildContext ctx, Map<String, dynamic> columns) {
    const color = Color(0xFF1565C0);
    const defaultDim = '0.2250 m';
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Table(
        border: TableBorder.all(color: color.withAlpha(40), width: 1),
        columnWidths: const {
          0: FlexColumnWidth(1.4),
          1: FlexColumnWidth(1.3),
          2: FlexColumnWidth(1.3),
          3: FlexColumnWidth(1.0),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: color.withAlpha(30)),
            children: ['Column', 'Width \u270E', 'Length \u270E', 'Height']
                .map((h) => _hCell(h, color))
                .toList(),
          ),
          ...columns.entries.toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final e = entry.value;
            final c = e.value is Map<String, dynamic>
                ? e.value as Map<String, dynamic>
                : <String, dynamic>{};
            final wVal = _colDim(_widthOverrides, e.key, c['width'], defaultDim);
            final lVal = _colDim(_lengthOverrides, e.key, c['length'], defaultDim);
            return TableRow(
              decoration: BoxDecoration(
                  color: idx.isEven ? Colors.white : color.withAlpha(8)),
              children: [
                _dCell(e.key, color),
                // Tappable width
                _tappableCell(
                    wVal,
                    () => _pickColumnSize(ctx, e.key, 'Width', wVal),
                    color,
                    saving: _savingDims.contains('${e.key}_Width')),
                // Tappable length
                _tappableCell(
                    lVal,
                    () => _pickColumnSize(ctx, e.key, 'Length', lVal),
                    color,
                    saving: _savingDims.contains('${e.key}_Length')),
                _dCell(_fmt(c['height']), color),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _tappableCell(String value, VoidCallback onTap, Color color,
          {bool saving = false}) =>
      GestureDetector(
        onTap: saving ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          color: Colors.transparent,
          child: saving
              ? const Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor:
                          AlwaysStoppedAnimation(Color(0xFF1565C0)),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.edit_outlined,
                        size: 11, color: Color(0xFF1565C0)),
                  ],
                ),
        ),
      );

  Widget _hCell(String t, Color c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Text(t,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: c),
            textAlign: TextAlign.center),
      );

  Widget _dCell(String t, Color c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Text(t.isEmpty ? '—' : t,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            textAlign: TextAlign.center),
      );
}//  Section label helper

class _SectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionLabel(this.title, {required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    ]);
  }
}

//  Size Picker Bottom-Sheet

class _SizePickerSheet extends StatelessWidget {
  final String title;
  final List<String> items;
  final String currentValue;
  final void Function(int index) onSelect;
  const _SizePickerSheet({
    required this.title,
    required this.items,
    required this.currentValue,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 8),
            ...items.asMap().entries.map((e) {
              final isSelected = e.value.contains(currentValue) ||
                  currentValue.contains(e.value.split(' ').first);
              return ListTile(
                dense: true,
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: isSelected
                      ? AppColors.primary
                      : Colors.grey.shade400,
                ),
                title: Text(e.value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal)),
                onTap: () {
                  onSelect(e.key);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

//  Sub-widgets 

class _FloorBadge extends StatelessWidget {
  final String floor;
  const _FloorBadge(this.floor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Text(
        floor,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _KVRow extends StatelessWidget {
  final String label;
  final String value;
  const _KVRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderNote extends StatelessWidget {
  final String message;
  const _PlaceholderNote(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style:
                TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      ]),
    );
  }
}

//  Error / No-data views 

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView(this.message, {required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoDataView extends StatelessWidget {
  final VoidCallback onRetry;
  const _NoDataView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.architecture_outlined,
                size: 64, color: Color(0xFF1565C0)),
            const SizedBox(height: 14),
            const Text('No Building Plan Data',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Upload and analyse a building plan first to see\n'
              'Foundation, Structural Frame, Walling and Finishing details.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
