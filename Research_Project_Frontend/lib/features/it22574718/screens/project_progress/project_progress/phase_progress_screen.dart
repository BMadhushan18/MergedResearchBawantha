import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import '../../services/mongo_api_service.dart';
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
                // Icon at top
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

                // Title
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

                // Main message
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
                  child: Column(
                    children: [
                      Text(
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
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Dates info
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

                // Close button
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
    if (s == 'pending' || s == 'not started' || s == 'not_started') {
      return 'Not Started';
    }
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
    final DateTime boundedInitial =
        currentInitial.isBefore(minDate) ? minDate : currentInitial;
    final DateTime initialDate =
        boundedInitial.isAfter(today) ? today : boundedInitial;

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

  @override
  Widget build(BuildContext context) {
    final progress = progressPercent.clamp(0, 100).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleSpacing: 0,
        toolbarHeight: 72,
        title: Text(
          widget.phaseName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildProjectHeader(progress),
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

  Widget _buildProjectHeader(double progress) {
    final chipColor = _statusColor(_phaseStatus);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF6F0), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x33FF6B35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  color: Colors.white,
                  size: 30,
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
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.phaseName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (widget.projectLocation.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.projectLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: chipColor.withOpacity(0.30)),
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
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 12,
                        backgroundColor: const Color(0xFFFFE2D4),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
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
                      color: Color(0x33FF6B35),
                      blurRadius: 16,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${progress.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'done',
                        style: TextStyle(
                          color: Colors.white,
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
          const SizedBox(height: 18),
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
                  icon: Icons.checklist_rounded,
                  title: 'Worked Days',
                  value: '$completedDays days',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double progress) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          // Progress journey removed as requested.
        ],
      ),
    );
  }

  Widget _buildStartDateCard() {
    final showUpdatedEndDateCard = !_isSameDate(initialEndDate, updatedEndDate);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Schedule Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: InkWell(
              onTap: _pickStartDate,
              borderRadius: BorderRadius.circular(18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Start Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatDate(startDate),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hasAnyDailyLogs ? 'Locked after first log' : 'Tap to set or update',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isSavingStartDate
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _hasAnyDailyLogs ? Icons.lock_rounded : Icons.edit_calendar_rounded,
                          color: _hasAnyDailyLogs ? AppColors.textSecondary : AppColors.primary,
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Show Updated End Date in place of the Initial End Date
          _infoTile(
            icon: Icons.update_rounded,
            title: 'Estimated End Date',
            value: formatDate(updatedEndDate ?? initialEndDate),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyStatusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.today_rounded,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Daily Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label('Log Date'),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickUpdateDate,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.date_range_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      formatDate(updateDate),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF6F0), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x33FF6B35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
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
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.primaryDark,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewCalendarButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFF6F9FF), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
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
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.secondary,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.success, Color(0xFF2E9A44)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x224CAF50),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 58,
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

                    // Get phaseDuration from response
                    final phaseDurationData = res['phaseDuration'];
                    if (phaseDurationData is Map<String, dynamic>) {
                      _showCompletionSummary(phaseDurationData);
                    } else {
                      // Fallback: reload and navigate
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
                    : 'Complete Phase',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
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
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [selectedColor.withOpacity(0.14), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? selectedColor.withOpacity(0.45)
                : AppColors.borderLight,
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: selectedColor.withOpacity(0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
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
                fontWeight: FontWeight.w800,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.12), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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