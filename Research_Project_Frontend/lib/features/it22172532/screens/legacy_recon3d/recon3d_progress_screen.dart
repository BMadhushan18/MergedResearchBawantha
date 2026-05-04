import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'recon3d_progress_model.dart';
import 'recon3d_api_service.dart';

class Recon3DProgressScreen extends StatefulWidget {
  const Recon3DProgressScreen({super.key});

  @override
  State<Recon3DProgressScreen> createState() =>
      _Recon3DProgressScreenState();
}

class _Recon3DProgressScreenState
    extends State<Recon3DProgressScreen> {
  final _api = Recon3DApiService();

  File? _yesterdayFile;
  File? _todayFile;
  String _yesterdayLabel = 'Pick yesterday output';
  String _todayLabel = 'Pick today output';
  bool _loading = false;
  String _error = '';
  Recon3DProgressComparison? _comparison;

  Future<void> _pickFile(bool isYesterday) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ply', 'glb', 'gltf'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) {
      return;
    }

    final file = File(result.files.single.path!);
    setState(() {
      _error = '';
      _comparison = null;
      if (isYesterday) {
        _yesterdayFile = file;
        _yesterdayLabel = result.files.single.name;
      } else {
        _todayFile = file;
        _todayLabel = result.files.single.name;
      }
    });
  }

  Future<void> _compare() async {
    if (_yesterdayFile == null || _todayFile == null) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final comparison =
          await _api.compareProgress(_yesterdayFile!, _todayFile!);
      if (!mounted) return;
      setState(() => _comparison = comparison);
    } on DioException catch (e) {
      setState(() => _error =
          e.response?.data?['detail']?.toString() ??
              e.message ??
              'Comparison failed');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        title: const Text('Progress Comparison'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIntroCard(),
              const SizedBox(height: 18),
              _buildPickerCard(
                title: 'Yesterday output',
                subtitle: _yesterdayLabel,
                icon: Icons.history_rounded,
                onTap: () => _pickFile(true),
              ),
              const SizedBox(height: 12),
              _buildPickerCard(
                title: 'Today output',
                subtitle: _todayLabel,
                icon: Icons.today_rounded,
                onTap: () => _pickFile(false),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ||
                          _yesterdayFile == null ||
                          _todayFile == null
                      ? null
                      : _compare,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                      : const Icon(Icons.analytics_rounded),
                  label: Text(_loading
                      ? 'Comparing models...'
                      : 'Confirm And Calculate Progress'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildErrorCard(),
              ],
              if (_comparison != null) ...[
                const SizedBox(height: 20),
                _buildSummaryCard(_comparison!),
                const SizedBox(height: 14),
                _buildPlanCard(_comparison!),
                const SizedBox(height: 14),
                _buildDeltaCard(_comparison!),
                const SizedBox(height: 14),
                _buildSnapshotCard('Yesterday',
                    _comparison!.yesterday),
                const SizedBox(height: 12),
                _buildSnapshotCard('Today', _comparison!.today),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A3A5C)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compare daily site outputs',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Upload yesterday and today 3D outputs from the same task area. '
            'The backend compares them against hardcoded plan measurements '
            'and returns a supervisor-friendly progress summary.',
            style: TextStyle(
                color: Color(0xFF9FB2D1), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF12172A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2A3A5C)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF5C9EFF)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF8DA2C4))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF8DA2C4)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1218),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7F1D1D)),
      ),
      child: Text(_error,
          style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildSummaryCard(Recon3DProgressComparison comparison) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comparison.summary.headline,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          LinearPercentIndicator(
            percent: (comparison.summary.completionPercent / 100)
                .clamp(0.0, 1.0),
            lineHeight: 10,
            backgroundColor: const Color(0x553B82F6),
            progressColor: Colors.white,
            barRadius: const Radius.circular(8),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metricChip(
                  '${comparison.summary.completionPercent.toStringAsFixed(1)}%',
                  'Completion'),
              const SizedBox(width: 10),
              _metricChip(
                  '${(comparison.summary.confidence * 100).toStringAsFixed(0)}%',
                  'Confidence'),
            ],
          ),
          const SizedBox(height: 12),
          ...comparison.summary.humanReadable.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line,
                  style: const TextStyle(
                      color: Color(0xFFE5EEFF))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x220F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x338BA8FF)),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFFD4E4FF), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Recon3DProgressComparison comparison) {
    final plan = comparison.plan;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A3A5C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.taskName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(plan.humanSummary,
              style: const TextStyle(
                  color: Color(0xFF9FB2D1), height: 1.5)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _smallInfoCard('Planned area',
                  '${plan.plannedAreaM2.toStringAsFixed(2)} m²'),
              _smallInfoCard('Planned volume',
                  '${plan.plannedVolumeM3.toStringAsFixed(2)} m³'),
              _smallInfoCard('Length',
                  '${plan.plannedLengthM.toStringAsFixed(2)} m'),
              _smallInfoCard('Height',
                  '${plan.plannedHeightM.toStringAsFixed(2)} m'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaCard(Recon3DProgressComparison comparison) {
    final delta = comparison.delta;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A3A5C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Difference Summary',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _smallInfoCard('Change since yesterday',
                  '${delta.progressPercentPoints.toStringAsFixed(1)} pts'),
              _smallInfoCard('Added area',
                  '${delta.addedAreaM2.toStringAsFixed(3)} m²'),
              _smallInfoCard('Added volume',
                  '${delta.addedVolumeM3.toStringAsFixed(3)} m³'),
              _smallInfoCard('Remaining area',
                  '${delta.remainingAreaM2.toStringAsFixed(3)} m²'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallInfoCard(String label, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF8DA2C4), fontSize: 12)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildSnapshotCard(
      String title, Recon3DProgressSnapshot snapshot) {
    final dims = snapshot.estimatedDimensionsM;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A3A5C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(snapshot.progressBand,
                    style: const TextStyle(
                        color: Color(0xFFBFD6FF),
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(snapshot.fileName,
              style:
                  const TextStyle(color: Color(0xFF8DA2C4))),
          const SizedBox(height: 14),
          LinearPercentIndicator(
            percent: (snapshot.progressPercent / 100)
                .clamp(0.0, 1.0),
            lineHeight: 8,
            backgroundColor: const Color(0xFF1E3A5F),
            progressColor: const Color(0xFF22C55E),
            barRadius: const Radius.circular(6),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _smallInfoCard('Completion',
                  '${snapshot.progressPercent.toStringAsFixed(1)}%'),
              _smallInfoCard('Built area',
                  '${snapshot.builtFaceAreaM2.toStringAsFixed(3)} m²'),
              _smallInfoCard('Built volume',
                  '${snapshot.builtVolumeM3.toStringAsFixed(3)} m³'),
              _smallInfoCard(
                  'Est. size',
                  '${(dims['length'] ?? 0)} x ${(dims['height'] ?? 0)} x ${(dims['thickness'] ?? 0)} m'),
            ],
          ),
        ],
      ),
    );
  }
}
