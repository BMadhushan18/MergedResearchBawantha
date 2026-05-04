import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import 'package:boq_frontend/features/it22172532/services/mongo_api_service.dart';
import 'track_progress_screen.dart';
import 'phase_daily_log_screen.dart';
import 'skip_daily_work_screen.dart';
import 'recent_daily_logs_screen.dart';
import 'phase_logs_calendar_screen.dart';

class PhaseDailyLogScreen extends StatefulWidget {
  final String pid;
  final String phaseId;
  final String phaseName;
  final String projectName;
  final String projectLocation;

  const PhaseDailyLogScreen({
    super.key,
    required this.pid,
    required this.phaseId,
    required this.phaseName,
    required this.projectName,
    this.projectLocation = '',
  });

  @override
  State<PhaseDailyLogScreen> createState() => _PhaseDailyLogScreenState();
}

class _PhaseDailyLogScreenState extends State<PhaseDailyLogScreen> {
  final MongoApiService _api = MongoApiService();

  int estimatedDays = 24;
  int estimatedLaborCount = 3;
  int _completedDays = 0;
  int _remainingManHours = 0;
  double _progressPercent = 0;
  String _phaseStatus = 'Not Started';
  bool _isCompleted = false;
  DateTime? _initialEstimatedEndDate;
  DateTime? _updatedEstimatedEndDate;

  DateTime? startDate;
  DateTime? updateDate;
  String? workStatus; // Yes / No
  String _workTypeForToday = 'Full Day';
  bool _isSavingStartDate = false;
  bool _isSavingDailyStatus = false;
  bool _isCompletingPhase = false;
  bool _hasAnyDailyLogs = false;

  @override
  void initState() {
    super.initState();
    _loadPhaseDurationContext();
  }

  @override
  void didUpdateWidget(covariant PhaseDailyLogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final phaseChanged =
        oldWidget.pid != widget.pid || oldWidget.phaseId != widget.phaseId;
    if (phaseChanged) {
      // Prevent previous phase values from leaking into a newly opened phase.
      setState(() {
        startDate = null;
        updateDate = null;
        workStatus = null;
        _workTypeForToday = 'Full Day';
      });
      _loadPhaseDurationContext();
    }
  }

  int get totalEstimatedManHours => estimatedDays * estimatedLaborCount * 8;

  int get completedDays => _completedDays;

  int get remainingManHours => _remainingManHours;

  double get progressPercent => _progressPercent;

  DateTime? get initialEndDate {
    if (_initialEstimatedEndDate != null) return _initialEstimatedEndDate;
    if (startDate == null) return null;
    return startDate!.add(Duration(days: (estimatedDays - 1).clamp(0, 100000)));
  }

  DateTime? get updatedEndDate {
    if (_updatedEstimatedEndDate != null) return _updatedEstimatedEndDate;
    return initialEndDate;
  }

  String formatDate(DateTime? date) {
    if (date == null) return '-- / -- / ----';
    return DateFormat('dd MMM yyyy').format(date);
  }

  bool _isSameDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }

  double _asDouble(dynamic value, double fallback) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? fallback;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  void _applyPhaseDuration(Map<String, dynamic> phaseDoc) {
    _initialEstimatedEndDate = _parseDate(phaseDoc['initialEstimatedEndDate']);
    _updatedEstimatedEndDate = _parseDate(phaseDoc['updatedEstimatedEndDate']);

    final remaining = _asInt(phaseDoc['remainingManHours'], 0);
    final progress = _asDouble(phaseDoc['progressPercent'], 0.0).clamp(0, 100);
    final rawStatus = (phaseDoc['status'] ?? '').toString();
    final rawIsCompleted = phaseDoc['isCompleted'];

    _remainingManHours = remaining < 0 ? 0 : remaining;
    _progressPercent = progress.toDouble();
    _phaseStatus = _normalizeStatus(rawStatus);
    _isCompleted = rawIsCompleted == true;
  }

  String _normalizeStatus(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'completed') return 'Completed';
    if (s == 'delayed') return 'Delayed';
    if (s == 'in progress' || s == 'in_progress') return 'In Progress';
    if (s == 'pending' || s == 'not started' || s == 'not_started') return 'Not Started';
    if (s.isEmpty) return 'Not Started';
    return status;
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'completed') return AppColors.success;
    if (s == 'delayed') return AppColors.error;
    if (s == 'in progress') return AppColors.info;
    return AppColors.warning;
  }

  Future<void> _loadCompletedDays() async {
    try {
      final completed = await _api.getCompletedPhaseDays(widget.pid, widget.phaseId);
      if (!mounted) return;
      setState(() {
        _completedDays = completed < 0 ? 0 : completed;
      });
    } catch (e) {
      debugPrint('Failed to load completed days: $e');
    }
  }

  Future<void> _loadDailyLogLockState() async {
    try {
      final recent = await _api.getRecentPhaseDailyLogs(
        widget.pid,
        widget.phaseId,
        limit: 1,
      );
      if (!mounted) return;
      setState(() {
        _hasAnyDailyLogs = recent.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Failed to load daily log lock state: $e');
    }
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  Future<void> _loadPhaseDurationContext() async {
    try {
      await _api.loadToken();
      final raw = await _api.getPhaseDurations(widget.pid);

      Map<String, dynamic>? phaseDoc;
      for (final item in raw) {
        if (item is Map<String, dynamic> &&
            (item['phaseId']?.toString() ?? '') == widget.phaseId) {
          phaseDoc = item;
          break;
        }
      }

      if (!mounted) return;

      if (phaseDoc == null) {
        setState(() {
          startDate = null;
          _completedDays = 0;
          _phaseStatus = 'Not Started';
          _isCompleted = false;
          _hasAnyDailyLogs = false;
        });
        return;
      }

      final parsedStartDate = DateTime.tryParse(
        (phaseDoc['startDate'] ?? '').toString(),
      );

      setState(() {
        estimatedDays = _asInt(phaseDoc!['durationDays'], estimatedDays);
        estimatedLaborCount = _asInt(phaseDoc['laborCount'], estimatedLaborCount);
        startDate = parsedStartDate;
        _applyPhaseDuration(phaseDoc);
      });

      await _loadCompletedDays();
      await _loadDailyLogLockState();
    } catch (e) {
      debugPrint('Failed to load phase duration context: $e');
    }
  }

  Future<void> _saveStartDate(DateTime selectedDate) async {
    if (_isSavingStartDate) return;

    final DateTime normalizedDate = _dateOnly(selectedDate);
    final DateTime? previousStartDate = startDate;
    final DateTime? previousUpdateDate = updateDate;

    setState(() {
      _isSavingStartDate = true;
      startDate = normalizedDate;
      if (updateDate != null && _dateOnly(updateDate!).isBefore(normalizedDate)) {
        updateDate = null;
      }
    });

    try {
      await _api.loadToken();
      await _api.savePhaseDurationPayload({
        'pid': widget.pid,
        'phaseId': widget.phaseId,
        'phaseName': widget.phaseName,
        'durationDays': estimatedDays,
        'laborCount': estimatedLaborCount,
        'startDate': DateFormat('yyyy-MM-dd').format(normalizedDate),
      });

      // Reload summary values from backend so UI stays in sync.
      await _loadPhaseDurationContext();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Start date saved.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        startDate = previousStartDate;
        updateDate = previousUpdateDate;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save start date: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingStartDate = false);
      }
    }
  }

  Future<void> _pickStartDate() async {
    if (_hasAnyDailyLogs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start date is locked after first log.'),
        ),
      );
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      await _saveStartDate(picked);
    }
  }

  Future<void> _pickUpdateDate() async {
    if (_isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phase is completed. Daily logs are locked.')),
      );
      return;
    }

    if (startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set start date first.')),
      );
      return;
    }

    final DateTime minDate = _dateOnly(startDate!);
    final DateTime today = _dateOnly(DateTime.now());
    final DateTime currentInitial = _dateOnly(updateDate ?? today);
    final DateTime boundedInitial = currentInitial.isBefore(minDate) ? minDate : currentInitial;
    final DateTime initialDate = boundedInitial.isAfter(today) ? today : boundedInitial;

    if (minDate.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log date cannot be in the future.')),
      );
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate,
      lastDate: today,
    );

    if (picked != null) {
      setState(() {
        updateDate = picked;
      });
    }
  }

  Future<void> _continueDailyFlow() async {
    if (_isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phase is completed. You cannot add daily logs.')),
      );
      return;
    }

    if (startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set and save start date first.')),
      );
      return;
    }

    if (updateDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select log date')),
      );
      return;
    }

    final DateTime start = _dateOnly(startDate!);
    final DateTime log = _dateOnly(updateDate!);
    final DateTime today = _dateOnly(DateTime.now());
    if (log.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You can log only from ${DateFormat('dd MMM yyyy').format(startDate!)} onwards.',
          ),
        ),
      );
      return;
    }

    if (log.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Future dates are not allowed for daily logs.')),
      );
      return;
    }

    if (workStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select work status')),
      );
      return;
    }

    if (_isSavingDailyStatus) return;

    setState(() => _isSavingDailyStatus = true);

    try {
      await _api.loadToken();

      final String logDateIso = DateFormat('yyyy-MM-dd').format(updateDate!);

      if (workStatus == 'Yes') {
        final int hoursPerLabor = _workTypeForToday == 'Half Day' ? 4 : 8;
        final int laborCount = estimatedLaborCount;
        final int dailyManHours = laborCount * hoursPerLabor;

        final res = await _api.savePhaseDailyLog(
          pid: widget.pid,
          phaseId: widget.phaseId,
          phaseName: widget.phaseName,
          logDate: logDateIso,
          workedToday: true,
          laborCount: laborCount,
          workType: _workTypeForToday,
          hoursPerLabor: hoursPerLabor,
          dailyManHours: dailyManHours,
          skipReason: null,
        );

        final phaseDuration = res['phaseDuration'];
        if (phaseDuration is Map<String, dynamic>) {
          if (mounted) {
            setState(() {
              _applyPhaseDuration(phaseDuration);
            });
          }
        }

        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhaseDailyUpdateScreen(
              pid: widget.pid,
              phaseId: widget.phaseId,
              phaseName: widget.phaseName,
              projectName: widget.projectName,
              selectedLogDate: updateDate!,
            ),
          ),
        );

        if (mounted) {
          await _loadPhaseDurationContext();
        }
      } else {
        final res = await _api.savePhaseDailyLog(
          pid: widget.pid,
          phaseId: widget.phaseId,
          phaseName: widget.phaseName,
          logDate: logDateIso,
          workedToday: false,
          laborCount: 0,
          workType: null,
          hoursPerLabor: 0,
          dailyManHours: 0,
          skipReason: null,
        );

        final phaseDuration = res['phaseDuration'];
        if (phaseDuration is Map<String, dynamic>) {
          if (mounted) {
            setState(() {
              _applyPhaseDuration(phaseDuration);
            });
          }
        }

        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SkipDailyWorkScreen(
              pid: widget.pid,
              phaseId: widget.phaseId,
              phaseName: widget.phaseName,
              projectName: widget.projectName,
              selectedLogDate: updateDate!,
            ),
          ),
        );

        if (mounted) {
          await _loadPhaseDurationContext();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save daily log: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingDailyStatus = false);
      }
    }
  }

  Future<void> _onWorkStatusSelected(String status) async {
    if (_isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phase is completed. Daily logs are disabled.')),
      );
      return;
    }

    if (_isSavingDailyStatus) return;
    setState(() {
      workStatus = status;
    });
    await _continueDailyFlow();
  }

  void _openRecentLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecentDailyLogsScreen(
          pid: widget.pid,
          phaseId: widget.phaseId,
          phaseName: widget.phaseName,
          projectName: widget.projectName,
        ),
      ),
    );
  }

  void _openCalendarView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhaseLogsCalendarScreen(
          pid: widget.pid,
          phaseId: widget.phaseId,
          phaseName: widget.phaseName,
        ),
      ),
    );
  }

  Future<DateTime?> _pickCompletionDate() async {
    final DateTime today = _dateOnly(DateTime.now());
    final DateTime minDate = startDate != null ? _dateOnly(startDate!) : DateTime(2024);
    final DateTime seedDate = updateDate != null ? _dateOnly(updateDate!) : today;
    final DateTime initialDate = seedDate.isAfter(today)
        ? today
        : (seedDate.isBefore(minDate) ? minDate : seedDate);

    if (minDate.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completion date cannot be before start date.')),
      );
      return null;
    }

    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate,
      lastDate: today,
      helpText: 'Select Actual Completion Date',
    );
  }

  void _showCompletionSummary(Map<String, dynamic> phaseData) {
    final DateTime? plannedEndDate = _parseDate(
      phaseData['initialEstimatedEndDate'] ?? phaseData['updatedEstimatedEndDate'],
    );
    final DateTime? actualEndDate = _parseDate(phaseData['actualCompletedDate']);

    if (plannedEndDate == null || actualEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot calculate completion summary')),
      );
      return;
    }

    final int daysDifference = actualEndDate.difference(plannedEndDate).inDays;
    final bool isEarly = daysDifference < 0;
    final bool isOnTime = daysDifference == 0;
    final bool isDelayed = daysDifference > 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDelayed
                        ? AppColors.error.withOpacity(0.12)
                        : AppColors.success.withOpacity(0.12),
                  ),
                  child: Icon(
                    isDelayed ? Icons.warning_rounded : Icons.celebration_rounded,
                    size: 40,
                    color: isDelayed ? AppColors.error : AppColors.success,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Summary of The Phase',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDelayed
                        ? AppColors.error.withOpacity(0.08)
                        : AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDelayed
                          ? AppColors.error.withOpacity(0.25)
                          : AppColors.success.withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    isOnTime
                        ? 'You completed the phase on time\nas planned'
                        : isEarly
                            ? 'You saved ${daysDifference.abs()} day${daysDifference.abs() == 1 ? '' : 's'}\nin this phase'
                            : 'You delayed ${daysDifference.abs()} day${daysDifference.abs() == 1 ? '' : 's'}\nin this phase',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDelayed ? AppColors.error : AppColors.success,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.event_available_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Planned End Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatDate(plannedEndDate),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Actual End Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatDate(actualEndDate),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (Navigator.of(context).canPop()) {
                        Navigator.pop(context, true);
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TrackProgressScreen(
                              pid: widget.pid,
                              projectName: widget.projectName,
                              location: widget.projectLocation,
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = progressPercent.clamp(0, 100).toDouble();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          widget.phaseName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildProjectHeader(),
          const SizedBox(height: 16),
          _buildSummaryCard(progress),
          const SizedBox(height: 16),
          _buildStartDateCard(),
          if (!_isCompleted) ...[
            const SizedBox(height: 16),
            _buildDailyStatusCard(),
          ],
          const SizedBox(height: 16),
          _buildViewLogsButton(),
          const SizedBox(height: 16),
          _buildViewCalendarButton(),
          const SizedBox(height: 16),
          _buildCompleteButton(),
        ],
      ),
    );
  }

  Widget _buildProjectHeader() {
    final chipColor = _statusColor(_phaseStatus);
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
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.timeline_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.projectName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.phaseName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: chipColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: chipColor.withOpacity(0.35)),
                      ),
                      child: Text(
                        _phaseStatus,
                        style: TextStyle(
                          color: chipColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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

  Widget _buildSummaryCard(double progress) {
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
          const Text(
            'Phase Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  icon: Icons.schedule_rounded,
                  title: 'Estimated Days',
                  value: '$estimatedDays days',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoTile(
                  icon: Icons.groups_rounded,
                  title: 'Labor Count',
                  value: '$estimatedLaborCount',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  icon: Icons.hourglass_bottom_rounded,
                  title: 'Worked Days',
                  value: '$completedDays days',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
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
              const SizedBox(width: 10),
              Text(
                '${progress.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartDateCard() {
    final showUpdatedEndDateCard = !_isSameDate(initialEndDate, updatedEndDate);

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
          const Text(
            'Schedule Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickStartDate,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                formatDate(startDate),
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _isSavingStartDate
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                _hasAnyDailyLogs
                                    ? Icons.lock_rounded
                                    : Icons.edit_calendar_rounded,
                                color: AppColors.primary,
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (showUpdatedEndDateCard)
            Row(
              children: [
                Expanded(
                  child: _infoTile(
                    icon: Icons.event_available_rounded,
                    title: 'Initial End Date',
                    value: formatDate(initialEndDate),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _infoTile(
                    icon: Icons.update_rounded,
                    title: 'Updated End Date',
                    value: formatDate(updatedEndDate),
                  ),
                ),
              ],
            )
          else
            _infoTile(
              icon: Icons.event_available_rounded,
              title: 'Initial End Date',
              value: formatDate(initialEndDate),
            ),
        ],
      ),
    );
  }

  Widget _buildDailyStatusCard() {
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
          const Text(
            'Daily Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _label('Log Date'),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickUpdateDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      formatDate(updateDate),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label('Did work happen today?'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _workStatusOption(
                  label: 'Yes',
                  icon: Icons.check_circle_rounded,
                  selected: workStatus == 'Yes',
                  selectedColor: AppColors.success,
                  onTap: () => _onWorkStatusSelected('Yes'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _workStatusOption(
                  label: 'No',
                  icon: Icons.cancel_rounded,
                  selected: workStatus == 'No',
                  selectedColor: AppColors.error,
                  onTap: () => _onWorkStatusSelected('No'),
                ),
              ),
            ],
          ),
          if (_isSavingDailyStatus) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _buildViewLogsButton() {
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
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: _openRecentLogs,
          icon: const Icon(Icons.history_rounded),
          label: const Text(
            'View Recent Logs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewCalendarButton() {
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
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: _openCalendarView,
          icon: const Icon(Icons.calendar_month_rounded),
          label: const Text(
            'View Calendar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
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
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: (_isCompletingPhase || _isCompleted)
              ? null
              : () async {
                  final pickedCompletionDate = await _pickCompletionDate();
                  if (pickedCompletionDate == null) return;

                  setState(() => _isCompletingPhase = true);
                  try {
                    await _api.loadToken();
                    final completionIso = DateFormat('yyyy-MM-dd').format(
                      _dateOnly(pickedCompletionDate),
                    );
                    final res = await _api.completePhaseDuration(
                      pid: widget.pid,
                      phaseId: widget.phaseId,
                      actualCompletedDate: completionIso,
                    );

                    if (!mounted) return;

                    final phaseDurationData = res['phaseDuration'];
                    if (phaseDurationData is Map<String, dynamic>) {
                      _showCompletionSummary(phaseDurationData);
                    } else {
                      await _loadPhaseDurationContext();
                      if (!mounted) return;
                      if (Navigator.of(context).canPop()) {
                        Navigator.pop(context, true);
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TrackProgressScreen(
                              pid: widget.pid,
                              projectName: widget.projectName,
                              location: widget.projectLocation,
                            ),
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to complete phase: $e')),
                    );
                  } finally {
                    if (mounted) {
                      setState(() => _isCompletingPhase = false);
                    }
                  }
                },
          icon: _isCompletingPhase
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.check_circle_rounded),
          label: Text(
            _isCompletingPhase
                ? 'Completing...'
                : _isCompleted
                    ? 'Completed'
                    : 'Complete',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _workStatusOption({
    required String label,
    required IconData icon,
    required bool selected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withOpacity(0.10)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? selectedColor.withOpacity(0.40)
                : AppColors.borderLight,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? selectedColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? selectedColor : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
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
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
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

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}