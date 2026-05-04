import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mongo_api_service.dart';
import '../../utils/constants.dart';

class PhaseDailyUpdateScreen extends StatefulWidget {
  final String pid;
  final String phaseId;
  final String phaseName;
  final String projectName;
  final DateTime selectedLogDate;

  const PhaseDailyUpdateScreen({
    super.key,
    required this.pid,
    required this.phaseId,
    required this.phaseName,
    required this.projectName,
    required this.selectedLogDate,
  });

  @override
  State<PhaseDailyUpdateScreen> createState() => _PhaseDailyUpdateScreenState();
}

class _PhaseDailyUpdateScreenState extends State<PhaseDailyUpdateScreen> {
  final TextEditingController _laborCountController =
      TextEditingController(text: '3');
  final MongoApiService _api = MongoApiService();
  bool _isSaving = false;

  String workingType = 'Full Day';

  int get hoursPerLabor => workingType == 'Full Day' ? 8 : 4;

  int get previewDailyManHours {
    final labor = int.tryParse(_laborCountController.text.trim()) ?? 0;
    return labor * hoursPerLabor;
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  Future<void> _saveDailyUpdate() async {
    final labor = int.tryParse(_laborCountController.text.trim());

    if (labor == null || labor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid labor count')),
      );
      return;
    }

    if (_isSaving) return;

    final dailyManHours = labor * hoursPerLabor;

    setState(() => _isSaving = true);

    try {
      await _api.loadToken();
      await _api.savePhaseDailyLog(
        pid: widget.pid,
        phaseId: widget.phaseId,
        phaseName: widget.phaseName,
        logDate: DateFormat('yyyy-MM-dd').format(widget.selectedLogDate),
        workedToday: true,
        laborCount: labor,
        workType: workingType,
        hoursPerLabor: hoursPerLabor,
        dailyManHours: dailyManHours,
        skipReason: null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily update saved successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save daily update: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _laborCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Daily Update',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildFormCard(),
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
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
                  '${widget.phaseName} • ${_formatDate(widget.selectedLogDate)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
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
            'Daily Update Form',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _label('Log Date'),
          const SizedBox(height: 8),
          Container(
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
                    _formatDate(widget.selectedLogDate),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _label('Today Labor Count'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _laborCountController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('Enter labor count'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          _label('Working Hours'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: workingType,
            decoration: _inputDecoration('Select working type'),
            items: const [
              DropdownMenuItem(
                value: 'Full Day',
                child: Text('Full Day'),
              ),
              DropdownMenuItem(
                value: 'Half Day',
                child: Text('Half Day'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                workingType = value;
              });
            },
          ),
          
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveDailyUpdate,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _isSaving ? 'Saving...' : 'Save Daily Update',
                style: const TextStyle(
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }
}