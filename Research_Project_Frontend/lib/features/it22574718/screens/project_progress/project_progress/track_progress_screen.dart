import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../providers/mongo_project_provider.dart';
import '../../services/mongo_api_service.dart';
import 'phase_progress_screen.dart';
import '../time_estimation/phase_wise_duration_screen.dart';

class TrackProgressScreen extends StatefulWidget {
  final String? pid;
  final String? projectName;
  final String? location;

  /// Only pass phases that are already estimated from DB.
  final List<TrackedPhaseItem> phases;

  const TrackProgressScreen({
    super.key,
    this.pid,
    this.projectName,
    this.location,
    this.phases = const [],
  });

  @override
  State<TrackProgressScreen> createState() => _TrackProgressScreenState();
}

class _TrackProgressScreenState extends State<TrackProgressScreen> {
  final MongoApiService _api = MongoApiService();
  late List<TrackedPhaseItem> _loadedPhases = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Keep Track Progress list order consistent with Phase Wise flow.
  static const List<String> _phaseDisplayOrder = [
    'foundation',
    'structural_wall',
    'roofing',
    'doors_windows',
    'plastering',
    'flooring',
    'painting_finishing',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.pid != null) {
      _loadPhases();
    } else {
      // Load projects for selection when no specific project is selected
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<MongoProjectProvider>().listenProjects();
      });
    }
  }

  @override
  void didUpdateWidget(covariant TrackProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reload when selected project changes from MainShell/provider.
    if (oldWidget.pid != widget.pid) {
      _errorMessage = null;
      if (widget.pid != null) {
        _loadPhases();
      } else {
        setState(() {
          _loadedPhases = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPhases() async {
    try {
      setState(() => _isLoading = true);
      
      if (!mounted) return;
      
      final provider = context.read<MongoProjectProvider>();
      await provider.refreshPhaseDurations();
      await _api.loadToken();
      final rawPhases = await _api.getPhaseDurations(widget.pid!);
      final orderedRawPhases = rawPhases.whereType<Map<String, dynamic>>().toList()
        ..sort((a, b) {
          final aIdx = _phaseOrderIndex((a['phaseId'] ?? '').toString());
          final bIdx = _phaseOrderIndex((b['phaseId'] ?? '').toString());
          if (aIdx != bIdx) return aIdx.compareTo(bIdx);

          // Secondary stable ordering by createdAt (oldest first).
          final aCreated = (a['createdAt'] ?? '').toString();
          final bCreated = (b['createdAt'] ?? '').toString();
          return aCreated.compareTo(bCreated);
        });
      
      if (!mounted) return;
      
      // Use backend phase_durations values directly for live status/progress.
      _loadedPhases = orderedRawPhases
          .map((phase) {
            final progress = _asDouble(phase['progressPercent']).clamp(0, 100).toDouble();
            final completedMh = _asDouble(phase['completedManHours']);
            final totalMh = _asDouble(phase['totalEstimatedManHours']);
            return TrackedPhaseItem(
              phaseId: (phase['phaseId'] ?? '').toString(),
              phaseName: (phase['phaseName'] ?? 'Phase').toString(),
              durationDays: _asInt(phase['durationDays']),
              laborCount: _asInt(phase['laborCount']),
              progressPercent: progress,
              status: _mapStatus(
                backendStatus: (phase['status'] ?? '').toString(),
                progressPercent: progress,
                completedManHours: completedMh,
                totalEstimatedManHours: totalMh,
              ),
            );
          })
          .where((p) => p.phaseId.isNotEmpty)
          .toList();
      
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load phases: $e';
        });
      }
      debugPrint('Error loading phases: $e');
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0.0;
  }

  int _phaseOrderIndex(String phaseId) {
    final idx = _phaseDisplayOrder.indexOf(phaseId.trim().toLowerCase());
    return idx >= 0 ? idx : 999;
  }

  PhaseTrackStatus _mapStatus({
    required String backendStatus,
    required double progressPercent,
    required double completedManHours,
    required double totalEstimatedManHours,
  }) {
    final status = backendStatus.trim().toLowerCase();

    if (status == 'completed') return PhaseTrackStatus.completed;
    if (status == 'delayed') return PhaseTrackStatus.delayed;
    if (status == 'in progress' || status == 'in_progress') {
      return PhaseTrackStatus.inProgress;
    }
    if (status == 'not started' || status == 'not_started' || status == 'pending') {
      return PhaseTrackStatus.pending;
    }

    // Fallback only when backend status is missing/unknown.
    if (totalEstimatedManHours > 0 && completedManHours > totalEstimatedManHours) {
      return PhaseTrackStatus.delayed;
    }
    if (totalEstimatedManHours > 0 && completedManHours == totalEstimatedManHours) {
      return PhaseTrackStatus.completed;
    }
    if (progressPercent >= 100) return PhaseTrackStatus.completed;
    if (progressPercent > 0) return PhaseTrackStatus.inProgress;
    return PhaseTrackStatus.pending;
  }

  List<TrackedPhaseItem> get _estimatedPhases {
    final phases = widget.phases.isNotEmpty ? widget.phases : _loadedPhases;
    return phases.where((p) => p.durationDays > 0).toList();
  }

  double get _overallProgress {
    final phases = _estimatedPhases;
    if (phases.isEmpty) return 0;

    final total = phases.fold<double>(0, (sum, p) => sum + p.progressPercent);
    return total / phases.length;
  }

  Widget _buildProjectSelectionScreen() {
    final provider = context.watch<MongoProjectProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBody: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Select Project',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : provider.projects.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.business_center_outlined,
                          size: 64,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Projects Found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create a project first to start tracking progress.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => provider.listenProjects(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: provider.projects.length,
                    itemBuilder: (context, index) {
                      final project = provider.projects[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onTap: () {
                            context
                                .read<MongoProjectProvider>()
                                .selectProject(project.projectId);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.business_center_rounded,
                                        color: AppColors.primary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            project.projectName ?? 'Unnamed Project',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'PID: ${project.projectId}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      project.location ?? 'Unknown Location',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        extendBody: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: const Text(
            'Track Progress',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        extendBody: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: const Text(
            'Track Progress',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If no project is selected, show project selection screen
    if (widget.pid == null || widget.projectName == null || widget.location == null) {
      return _buildProjectSelectionScreen();
    }

    final phases = _estimatedPhases;

    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBody: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Track Progress',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          _buildTopHeader(),
          Expanded(
            child: phases.isEmpty
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      _buildProjectCard(),
                      const SizedBox(height: 16),
                      _buildPhasesHeader(),
                      const SizedBox(height: 16),
                      ...List.generate(phases.length, (index) {
                        final phase = phases[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == phases.length - 1 ? 0 : 14,
                          ),
                          child: _buildPhaseCard(phase),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      height: 18,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
      children: [
        _buildProjectCard(),
        const SizedBox(height: 18),
        _buildPhasesHeaderWithButton(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Column(
            children: [
              Icon(
                Icons.construction_rounded,
                size: 46,
                color: AppColors.primary,
              ),
              SizedBox(height: 12),
              Text(
                'No estimated phases yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'This page shows only phases that already have calculated duration.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhasesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Project Phases',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PhaseWiseDurationScreen(pid: widget.pid!),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Add Phase',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhasesHeaderWithButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Project Phases',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PhaseWiseDurationScreen(pid: widget.pid!),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                const Text(
                  '+Add Phase',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectCard() {
    final progress = _overallProgress.clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.projectName!,
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
                  widget.location!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall Progress',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Linear progress first (like phase_progress_screen)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          minHeight: 10,
                          backgroundColor: AppColors.borderLight,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Gradient circular badge (percent + label)
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 10,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${progress.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Overall',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseCard(TrackedPhaseItem phase) {
    final statusColor = _statusColor(phase.status);

    return InkWell(
      onTap: phase.durationDays > 0
          ? () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhaseDailyLogScreen(
                    pid: widget.pid!,
                    phaseId: phase.phaseId,
                    phaseName: phase.phaseName,
                    projectName: widget.projectName!,
                    projectLocation: widget.location ?? '',
                  ),
                ),
              );

              if (mounted) {
                await _loadPhases();
              }
            }
          : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 118,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.28),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          phase.phaseName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _PhaseStatusChip(
                        label: _statusLabel(phase.status),
                        color: statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniInfoTile(
                          icon: Icons.schedule_rounded,
                          title: 'Duration',
                          value: '${phase.durationDays} days',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniInfoTile(
                          icon: Icons.groups_rounded,
                          title: 'Labors',
                          value: '${phase.laborCount}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'Progress',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: (phase.progressPercent.clamp(0, 100)) / 100,
                            minHeight: 10,
                            backgroundColor: AppColors.borderLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.success,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${phase.progressPercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: phase.durationDays > 0
                    ? AppColors.primary.withOpacity(0.10)
                    : AppColors.borderLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                color: phase.durationDays > 0
                    ? AppColors.primary
                    : AppColors.textHint,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(PhaseTrackStatus status) {
    switch (status) {
      case PhaseTrackStatus.completed:
        return AppColors.success;
      case PhaseTrackStatus.delayed:
        return AppColors.error;
      case PhaseTrackStatus.inProgress:
        return AppColors.info;
      case PhaseTrackStatus.pending:
        return AppColors.warning;
    }
  }

  String _statusLabel(PhaseTrackStatus status) {
    switch (status) {
      case PhaseTrackStatus.completed:
        return 'Completed';
      case PhaseTrackStatus.delayed:
        return 'Delayed';
      case PhaseTrackStatus.inProgress:
        return 'In Progress';
      case PhaseTrackStatus.pending:
        return 'Pending';
    }
  }
}

enum PhaseTrackStatus {
  completed,
  delayed,
  inProgress,
  pending,
}

class TrackedPhaseItem {
  final String phaseId;
  final String phaseName;
  final int durationDays;
  final int laborCount;
  final double progressPercent;
  final PhaseTrackStatus status;

  const TrackedPhaseItem({
    required this.phaseId,
    required this.phaseName,
    required this.durationDays,
    required this.laborCount,
    required this.progressPercent,
    required this.status,
  });
}

class _PhaseStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _PhaseStatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.hourglass_bottom_rounded;

    if (label == 'Completed') {
      icon = Icons.check_circle_rounded;
    } else if (label == 'Delayed') {
      icon = Icons.warning_amber_rounded;
    } else if (label == 'In Progress') {
      icon = Icons.pending_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _MiniInfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
                    fontSize: 15,
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

