import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/mongo_api_service.dart';
import '../../utils/constants.dart';

class PhaseLogsCalendarScreen extends StatefulWidget {
  final String pid;
  final String phaseId;
  final String phaseName;

  const PhaseLogsCalendarScreen({
    super.key,
    required this.pid,
    required this.phaseId,
    required this.phaseName,
  });

  @override
  State<PhaseLogsCalendarScreen> createState() =>
      _PhaseLogsCalendarScreenState();
}

class _PhaseLogsCalendarScreenState extends State<PhaseLogsCalendarScreen> {
  final MongoApiService _api = MongoApiService();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, bool> _logs = {};
  bool _isLoading = true;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final data = await _api.getRecentPhaseDailyLogs(
        widget.pid,
        widget.phaseId,
        limit: 365,
      );

      _logs.clear();

      for (final item in data) {
        final date = DateTime.parse(item['logDate']);
        final worked = item['workedToday'] == true;
        _logs[_dateOnly(date)] = worked;
      }
    } catch (e) {
      debugPrint('Failed to load calendar logs: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color? _dayColor(DateTime day) {
    final status = _logs[_dateOnly(day)];
    if (status == true) return Colors.green.withOpacity(0.30);
    if (status == false) return Colors.red.withOpacity(0.30);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.phaseName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2023, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      return Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _dayColor(day),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _dayColor(day) ?? AppColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      return Container(
                        margin: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
              ),
            ),
    );
  }
}