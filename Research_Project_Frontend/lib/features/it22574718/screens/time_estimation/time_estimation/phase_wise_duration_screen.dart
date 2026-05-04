import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../providers/mongo_project_provider.dart';
import 'foundation_duration_screen.dart';
import 'structural_wall_duration_screen.dart';
import 'roof_duration_screen.dart';
import 'doors_windows_duration_screen.dart';
import 'plastering_duration_screen.dart';
import 'flooring_duration_screen.dart';
import 'painting_finishing_duration_screen.dart';
import 'phase_result.dart';
// import '../main_shell.dart';

// backend client (file path is lib/service/mongo_api_service.dart)
import '../../services/mongo_api_service.dart';

// Additional imports for bottom nav
// import '../home_page.dart';
// import '../view_3d_screen.dart';
// import '../project_search_screen.dart';

class PhaseWiseDurationScreen extends StatefulWidget {
  /// project id (pid) needed to save/load phase durations per project
  final String pid;

  const PhaseWiseDurationScreen({
    super.key,
    required this.pid,
  });

  @override
  State<PhaseWiseDurationScreen> createState() => _PhaseWiseDurationScreenState();
}

class _PhaseWiseDurationScreenState extends State<PhaseWiseDurationScreen> {
  //  API instance
  final MongoApiService _api = MongoApiService();

  //  Per-item saving state (disable only that Save button)
  final Set<int> _saving = <int>{};
  final Set<String> _lockedPhaseIds = <String>{};

  //  Stable phaseId list for backend upsert (do not change ids once you start saving)
  final List<_PhaseMeta> _phaseMeta = const [
    _PhaseMeta(id: 'foundation', name: 'Foundation'),
    _PhaseMeta(id: 'structural_wall', name: 'Structural and Wall'),
    _PhaseMeta(id: 'roofing', name: 'Roofing'),
    _PhaseMeta(id: 'doors_windows', name: 'Doors and Windows Fixture'),
    _PhaseMeta(id: 'plastering', name: 'Plastering'),
    _PhaseMeta(id: 'flooring', name: 'Flooring'),
    _PhaseMeta(id: 'painting_finishing', name: 'Painting and Finishing'),
  ];

  late final List<_PhaseItem> _phases =
      _phaseMeta.map((m) => _PhaseItem(name: m.name)).toList();

  int get _totalDurationDays {
    return _phases.fold<int>(0, (sum, phase) => sum + phase.durationDays);
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await context.read<MongoProjectProvider>().ensureCurrentProject(widget.pid);
      await _api.loadToken(); // ensure token loaded
    } catch (_) {
      // If token missing or backend unreachable, continue with best-effort UI loading.
    }

    await _loadSavedPhaseDurations();
    await _loadPhaseLocks();
  }

  Future<void> _loadPhaseLocks() async {
    try {
      final locks = await Future.wait(
        _phaseMeta.map((meta) async {
          try {
            final recent = await _api.getRecentPhaseDailyLogs(
              widget.pid,
              meta.id,
              limit: 1,
            );
            return MapEntry(meta.id, recent.isNotEmpty);
          } catch (_) {
            return MapEntry(meta.id, false);
          }
        }),
      );

      if (!mounted) return;
      setState(() {
        _lockedPhaseIds
          ..clear()
          ..addAll(locks.where((e) => e.value).map((e) => e.key));
      });
    } catch (_) {
      // keep unlocked state on failure
    }
  }

  Future<void> _openCamera() async {
    HapticFeedback.mediumImpact();
    try {
      final picker = ImagePicker();
      await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camera permission required.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _loadSavedPhaseDurations() async {
    try {
      final list = await _api.getPhaseDurations(widget.pid);

      // Build map: phaseId -> saved document
      final mapByPhaseId = <String, Map<String, dynamic>>{};
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final phaseId = (item['phaseId'] ?? '').toString();
          if (phaseId.isNotEmpty) mapByPhaseId[phaseId] = item;
        } else if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final phaseId = (m['phaseId'] ?? '').toString();
          if (phaseId.isNotEmpty) mapByPhaseId[phaseId] = m;
        }
      }

      bool changed = false;

      for (int i = 0; i < _phaseMeta.length; i++) {
        final meta = _phaseMeta[i];
        final saved = mapByPhaseId[meta.id];
        if (saved == null) continue;

        final duration = _toInt(saved['durationDays']);
        final labors = _toInt(saved['laborCount']);

        if (duration > 0 && labors > 0) {
          _phases[i] = _phases[i].copyWith(
            durationDays: duration,
            laborCount: labors,
            isCalculated: true,
          );
          changed = true;
        }
      }

      if (changed && mounted) setState(() {});
    } catch (_) {
      // silent fail (optional snack if you want)
    }
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      appBar: AppBar(
        title: const Text('Phase Wise Duration'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildEstimatedTotalDurationCard(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), // increased bottom padding for nav bar
              itemCount: _phases.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final p = _phases[index];
                final saving = _saving.contains(index);
                final isLocked = _lockedPhaseIds.contains(_phaseMeta[index].id);

                return _buildPhaseCard(
                  phase: p,
                  index: index,
                  saving: saving,
                  isLocked: isLocked,
                  onTapCalculateOrEdit: () => _openPhaseForm(index),
                  onTapSave: () => _savePhase(index),
                );
              },
            ),
          ),
        ],
      ),
  
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phase Wise Duration',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Calculate duration for main construction phase.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimatedTotalDurationCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.schedule_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Duration',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _totalDurationDays == 0
                        ? 'Not calculated yet'
                        : '$_totalDurationDays day${_totalDurationDays == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
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

  Widget _buildPhaseCard({
    required _PhaseItem phase,
    required int index,
    required bool saving,
    required bool isLocked,
    required VoidCallback onTapCalculateOrEdit,
    required VoidCallback onTapSave,
  }) {
    final isCalculated = phase.isCalculated;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${index + 1}. ${phase.name}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(isCalculated: isCalculated, isLocked: isLocked),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoPill(
                  icon: Icons.schedule_rounded,
                  label: 'Duration',
                  value: '${phase.durationDays} days',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoPill(
                  icon: Icons.groups_rounded,
                  label: 'Labors',
                  value: '${phase.laborCount}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (!isCalculated)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: isLocked ? null : onTapCalculateOrEdit,
                icon: Icon(isLocked ? Icons.lock_rounded : Icons.calculate_rounded),
                label: Text(
                  isLocked ? 'Locked' : 'Calculate',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: isLocked ? null : onTapCalculateOrEdit,
                      icon: Icon(isLocked ? Icons.lock_rounded : Icons.edit_rounded),
                      label: Text(
                        isLocked ? 'Locked' : 'Calculate',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: (saving || isLocked) ? null : onTapSave,
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        saving ? 'Saving...' : 'Save',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Save -> backend (/phase-durations/save)
  Future<void> _savePhase(int index) async {
    if (_lockedPhaseIds.contains(_phaseMeta[index].id)) {
      _snack('This phase is locked because daily logging has started.', AppColors.warning);
      return;
    }

    final phase = _phases[index];

    if (!phase.isCalculated) {
      _snack('Please calculate before saving', AppColors.warning);
      return;
    }

    final meta = _phaseMeta[index];

    setState(() => _saving.add(index));

    try {
      await _api.loadToken();

    final Map<String, dynamic> payload = {
      "pid": widget.pid,
      "phaseId": meta.id,
      "phaseName": meta.name,
      "durationDays": phase.durationDays,
      "laborCount": phase.laborCount,
    };

    await _api.savePhaseDurationPayload(payload);

      _snack('${meta.name} saved successfully!', AppColors.success);
    } catch (e) {
      _snack('Save failed: $e', AppColors.warning);
    } finally {
      if (mounted) setState(() => _saving.remove(index));
    }
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _showSaveReminderDialog(String phaseName) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Estimation Calculated',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$phaseName estimation is ready.\nIf you want to track progress, please tap Save.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _applyCalculatedResult({
    required int index,
    required _PhaseItem phase,
    required PhaseResult result,
  }) async {
    setState(() {
      _phases[index] = phase.copyWith(
        durationDays: result.durationDays,
        laborCount: result.laborCount,
        isCalculated: true,
      );
    });

    await _showSaveReminderDialog(_phaseMeta[index].name);
  }

  /// Wired screens:
  /// 0 -> FoundationDurationScreen
  /// 1 -> StructuralWallDurationScreen
  /// 2 -> RoofDurationScreen
  /// 3 -> DoorsWindowsDurationScreen
  /// Others -> Coming soon
  Future<void> _openPhaseForm(int index) async {
    if (_lockedPhaseIds.contains(_phaseMeta[index].id)) {
      _snack('This phase is locked because daily logging has started.', AppColors.warning);
      return;
    }

    final phase = _phases[index];
    final initialLabors = phase.laborCount == 0 ? 5 : phase.laborCount;

  //--------------FoundationDurationScreen----------------

    if (index == 0) {
      final result = await Navigator.push<PhaseResult>(
        context,
        MaterialPageRoute(
          builder: (_) => FoundationDurationScreen(initialLabors: initialLabors),
        ),
      );
      if (result == null) return;

      await _applyCalculatedResult(index: index, phase: phase, result: result);
      return;
    }


//--------------StructuralWallDurationScreen----------------
    if (index == 1) {
      final result = await Navigator.push<PhaseResult>(
        context,
        MaterialPageRoute(
          builder: (_) => StructuralWallDurationScreen(initialLabors: initialLabors),
        ),
      );
      if (result == null) return;

      await _applyCalculatedResult(index: index, phase: phase, result: result);
      return;
    }

  //--------------RoofDurationScreen-------------  

    if (index == 2) {
      final result = await Navigator.push<PhaseResult>(
        context,
        MaterialPageRoute(
          builder: (_) => RoofDurationScreen(initialLabors: initialLabors),
        ),
      );
      if (result == null) return;

      await _applyCalculatedResult(index: index, phase: phase, result: result);
      return;
    }

  //--------------DoorsWindowsDurationScreen----------------  

    if (index == 3) {
      final result = await Navigator.push<PhaseResult>(
        context,
        MaterialPageRoute(
          builder: (_) => DoorsWindowsDurationScreen(initialLabors: initialLabors),
        ),
      );
      if (result == null) return;

      await _applyCalculatedResult(index: index, phase: phase, result: result);
      return;
    }

  //--------------PlasteringDurationScreen----------------

    if (index == 4) {
      final result = await Navigator.push<PhaseResult>(
        context,
        MaterialPageRoute(
          builder: (_) => PlasteringDurationScreen(initialLabors: initialLabors),
        ),
      );
      if (result == null) return;

      await _applyCalculatedResult(index: index, phase: phase, result: result);
      return;
    }

  //--------------FlooringDurationScreen----------------

    if (index == 5) {
      final result = await Navigator.push<PhaseResult>(
        context,
        MaterialPageRoute(
          builder: (_) => FlooringDurationScreen(initialLabors: initialLabors),
        ),
      );
      if (result == null) return;

      await _applyCalculatedResult(index: index, phase: phase, result: result);
      return;
    }


  //--------------PaintingFinishingDurationScreen----------------


    if (index == 6) {
      final result = await Navigator.push<PhaseResult>(
        context,
        MaterialPageRoute(
          builder: (_) => PaintingFinishingDurationScreen(initialLabors: initialLabors),
        ),
      );
      if (result == null) return;

      await _applyCalculatedResult(index: index, phase: phase, result: result);
      return;
    }

    

    _snack('This phase form is not estimated yet', AppColors.warning);
  }
}

///  phase meta (phaseId + phaseName)
class _PhaseMeta {
  final String id;
  final String name;
  const _PhaseMeta({required this.id, required this.name});
}

/// Model
class _PhaseItem {
  final String name;
  final int durationDays;
  final int laborCount;
  final bool isCalculated;

  const _PhaseItem({
    required this.name,
    this.durationDays = 0,
    this.laborCount = 0,
    this.isCalculated = false,
  });

  _PhaseItem copyWith({
    String? name,
    int? durationDays,
    int? laborCount,
    bool? isCalculated,
  }) {
    return _PhaseItem(
      name: name ?? this.name,
      durationDays: durationDays ?? this.durationDays,
      laborCount: laborCount ?? this.laborCount,
      isCalculated: isCalculated ?? this.isCalculated,
    );
  }
}

/// UI components
class _StatusChip extends StatelessWidget {
  final bool isCalculated;
  final bool isLocked;

  const _StatusChip({required this.isCalculated, this.isLocked = false});

  @override
  Widget build(BuildContext context) {
    final bg = isLocked
        ? AppColors.error.withOpacity(0.12)
        : isCalculated
            ? AppColors.success.withOpacity(0.12)
            : AppColors.warning.withOpacity(0.12);
    final fg = isLocked
        ? AppColors.error
        : isCalculated
            ? AppColors.success
            : AppColors.warning;
    final text = isLocked ? 'Locked' : (isCalculated ? 'Calculated' : 'Pending');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isLocked
                ? Icons.lock_rounded
                : isCalculated
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_bottom_rounded,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Bottom Nav Bar ────────────────────────────────────────────────────
class _BottomNavBar extends StatelessWidget {
  final int currentPageIndex;
  final ValueChanged<int> onItemTap;

  const _BottomNavBar({
    required this.currentPageIndex,
    required this.onItemTap,
  });

  // bar position → page index (camera is action so -1)
  bool _isSelected(int barPos) {
    if (barPos == 2) return false; // camera never "selected"
    final pi = barPos < 2 ? barPos : barPos - 1;
    return pi == currentPageIndex;
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.view_in_ar_rounded, label: '3D View'),
      _NavItem(icon: Icons.camera_alt_rounded, label: 'Camera', isCenter: true),
      _NavItem(icon: Icons.search_rounded, label: 'Projects'),
      _NavItem(icon: Icons.bar_chart_rounded, label: 'Progress'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final selected = _isSelected(i);

              if (item.isCenter) {
                // ── Raised camera button ──────────────────────────────────
                return GestureDetector(
                  onTap: () => onItemTap(i),
                  child: Transform.translate(
                    offset: const Offset(0, -18),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryLight
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                );
              }

              // ── Regular nav item ─────────────────────────────────────────
              return GestureDetector(
                onTap: () => onItemTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          item.icon,
                          key: ValueKey(selected),
                          size: 24,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textHint,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final bool isCenter;
  const _NavItem(
      {required this.icon, required this.label, this.isCenter = false});
}