import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import '../../utils/constants.dart';
import '../../services/mongo_api_service.dart';

class RecentDailyLogsScreen extends StatefulWidget {
  final String pid;
  final String phaseId;
  final String phaseName;
  final String projectName;

  const RecentDailyLogsScreen({
    super.key,
    required this.pid,
    required this.phaseId,
    required this.phaseName,
    required this.projectName,
  });

  @override
  State<RecentDailyLogsScreen> createState() => _RecentDailyLogsScreenState();
}

class _RecentDailyLogsScreenState extends State<RecentDailyLogsScreen> {
  final MongoApiService _api = MongoApiService();
  late DateTime fromDate;
  late DateTime toDate;
  bool _isLoading = true;
  String? _loadError;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    toDate = DateTime(now.year, now.month, now.day);
    fromDate = toDate.subtract(const Duration(days: 6));
    _loadRecentLogs();
  }

  DateTime _parseLogDate(dynamic raw) {
    if (raw is DateTime) return raw;
    final parsed = DateTime.tryParse((raw ?? '').toString());
    return parsed ?? DateTime.now();
  }

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }

  Future<void> _loadRecentLogs() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      await _api.loadToken();
      final raw = await _api.getRecentPhaseDailyLogs(
        widget.pid,
        widget.phaseId,
        limit: 7,
      );

      final mapped = raw
          .whereType<Map<String, dynamic>>()
          .map((item) {
            final workedToday = item['workedToday'] == true;
            return {
              'date': _parseLogDate(item['logDate']),
              'workedToday': workedToday,
              'laborCount': _asInt(item['laborCount'], 0),
              'workType': item['workType']?.toString(),
              'hoursPerLabor': _asInt(item['hoursPerLabor'], 0),
              'dailyManHours': _asInt(item['dailyManHours'], 0),
              'skipReason': item['skipReason']?.toString(),
            };
          })
          .toList();

      if (!mounted) return;
      setState(() {
        _logs = mapped;
        if (_logs.isNotEmpty) {
          final sorted = [..._logs]
            ..sort((a, b) =>
                (b['date'] as DateTime).compareTo(a['date'] as DateTime));
          toDate = sorted.first['date'] as DateTime;
          fromDate = sorted.last['date'] as DateTime;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String formatDate(DateTime? date) {
    if (date == null) return '-- / -- / ----';
    return DateFormat('dd MMM yyyy').format(date);
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fromDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        fromDate = DateTime(picked.year, picked.month, picked.day);
        if (fromDate.isAfter(toDate)) {
          toDate = fromDate;
        }
      });
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: toDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        toDate = DateTime(picked.year, picked.month, picked.day);
        if (toDate.isBefore(fromDate)) {
          fromDate = toDate;
        }
      });
    }
  }

  List<Map<String, dynamic>> get _exportRangeLogs {
    return _logs.where((log) {
      final DateTime logDate = log['date'] as DateTime;
      final d = DateTime(logDate.year, logDate.month, logDate.day);
      return !d.isBefore(fromDate) && !d.isAfter(toDate);
    }).toList()
      ..sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
  }

  List<Map<String, dynamic>> get _latestLogs {
    return [..._logs]
      ..sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
  }

  Future<void> _exportPdf() async {
    try {
      final pdf = pw.Document();
      final logs = _exportRangeLogs;
      final dateFormat = DateFormat('dd MMM yyyy');

      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Text(
              'Daily Logs Report',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Project: ${widget.projectName}'),
            pw.Text('Phase: ${widget.phaseName}'),
            pw.Text(
              'Date Range: ${dateFormat.format(fromDate)} - ${dateFormat.format(toDate)}',
            ),
            pw.SizedBox(height: 16),
            if (logs.isEmpty)
              pw.Text('No logs found for selected date range.')
            else
              pw.Table.fromTextArray(
                headers: const [
                  'Date',
                  'Labor Count',
                  'Work Type',
                  'Skip Reason',
                ],
                data: logs.map((log) {
                  final workedToday = log['workedToday'] == true;
                  final skipReason = ((log['skipReason'] ?? '').toString().trim().isEmpty)
                      ? 'N/A'
                      : '${log['skipReason']}';
                  return [
                    dateFormat.format(log['date'] as DateTime),
                    workedToday ? '${log['laborCount']}' : '-',
                    workedToday ? '${log['workType'] ?? '-'}' : '-',
                    workedToday ? '-' : skipReason,
                  ];
                }).toList(),
              ),
          ],
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/recent_logs_${widget.phaseName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF exported: ${file.path.split('/').last}'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              OpenFile.open(file.path);
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = _latestLogs;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Recent Daily Logs',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildFilterCard(),
          const SizedBox(height: 16),
          _buildExportButton(),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_loadError != null)
            _buildLoadErrorCard()
          else
            _buildLogsCard(logs),
        ],
      ),
    );
  }

  Widget _buildLoadErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Failed to load recent logs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _loadError ?? 'Unknown error',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadRecentLogs,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
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
              Icons.history_rounded,
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
                Text(
                  widget.phaseName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
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
            'Export Date Range',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'This range is used only for PDF export.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dateField(
                  label: 'From',
                  date: fromDate,
                  onTap: _pickFromDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dateField(
                  label: 'To',
                  date: toDate,
                  onTap: _pickToDate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.date_range_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatDate(date),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _exportPdf,
        icon: const Icon(Icons.picture_as_pdf_rounded),
        label: const Text(
          'Export PDF',
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
    );
  }

  Widget _buildLogsCard(List<Map<String, dynamic>> logs) {
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
            'Latest 7 Logs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (logs.isEmpty)
            const Text(
              'No recent logs found.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ...logs.map((log) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.assignment_turned_in_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy')
                                .format(log['date'] as DateTime),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log['workedToday'] == true
                                ? 'Labors: ${log['laborCount']}  •  ${log['workType'] ?? '-'}'
                                : 'Skipped Day',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (log['workedToday'] != true) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Reason: ${((log['skipReason'] ?? '').toString().trim().isEmpty) ? 'N/A' : log['skipReason']}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}