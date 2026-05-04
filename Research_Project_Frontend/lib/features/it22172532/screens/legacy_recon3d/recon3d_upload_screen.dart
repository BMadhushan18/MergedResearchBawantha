import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'recon3d_api_service.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import 'recon3d_result_screen.dart';

class Recon3DUploadScreen extends StatefulWidget {
  const Recon3DUploadScreen({super.key});

  @override
  State<Recon3DUploadScreen> createState() => _Recon3DUploadScreenState();
}

class _Recon3DUploadScreenState extends State<Recon3DUploadScreen> {
  final _api = Recon3DApiService();
  static const _profiles = ['fast', 'balanced', 'quality'];

  List<File> _files = [];
  String _filesDesc = '';
  String _phase = 'idle'; // idle | uploading | processing | done | error
  double _uploadPct = 0;
  int _progress = 0;
  String _stage = 'idle';
  String _statusMsg = '';
  String _errorMsg = '';
  String _profile = 'fast';
  String? _jobId;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4', 'avi', 'mov', 'mkv',
        'jpg', 'jpeg', 'png', 'bmp', 'tiff'
      ],
      allowMultiple: true,
    );
    if (res == null || res.files.isEmpty) return;
    setState(() {
      _files = res.files.map((f) => File(f.path!)).toList();
      _filesDesc = res.files.length == 1
          ? res.files.single.name
          : '${res.files.length} files selected';
      _phase = 'idle';
      _errorMsg = '';
    });
  }

  Future<void> _startReconstruction() async {
    if (_files.isEmpty) return;
    setState(() {
      _phase = 'uploading';
      _uploadPct = 0;
      _errorMsg = '';
    });

    try {
      final result = await _api.uploadFiles(
        _files,
        profile: _profile,
        onProgress: (sent, total) {
          if (total > 0) setState(() => _uploadPct = sent / total);
        },
      );

      _jobId = result['job_id'] as String;
      final frames = result['frame_count'] as int;
      setState(() {
        _phase = 'processing';
        _stage = result['stage'] as String? ?? 'uploaded';
        _statusMsg =
            'Uploaded ${_files.length} file(s). Processed $frames images with ${_profile.toUpperCase()} profile.';
        _progress = 5;
      });
      _startPolling();
    } on DioException catch (e) {
      _showError(
          e.response?.data?['detail'] ?? e.message ?? 'Upload failed');
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _startPolling() {
    _pollTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_jobId == null) return;
    try {
      final s = await _api.getStatus(_jobId!);
      if (!mounted) return;
      setState(() {
        _progress = s.progress;
        _stage = s.stage;
        _statusMsg = s.message;
      });

      if (s.isCompleted) {
        _pollTimer?.cancel();
        setState(() => _phase = 'done');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  Recon3DResultScreen(jobId: _jobId!, initialStatus: s),
            ),
          );
        }
      } else if (s.isFailed) {
        _pollTimer?.cancel();
        _showError(s.error.isNotEmpty ? s.error : 'Reconstruction failed');
      }
    } catch (_) {
      // transient network error — keep polling
    }
  }

  void _showError(String msg) {
    _pollTimer?.cancel();
    setState(() {
      _phase = 'error';
      _errorMsg = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('New Reconstruction'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilesCard(),
              const SizedBox(height: 16),
              _buildProfilePicker(),
              const SizedBox(height: 28),
              if (_phase == 'uploading') _buildUploadProgress(),
              if (_phase == 'processing') _buildProcessingCard(),
              if (_phase == 'error') _buildErrorCard(),
              const SizedBox(height: 24),
              _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Processing Speed',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Fast is recommended for most cases.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _profiles.map((profile) {
              final selected = _profile == profile;
              return ChoiceChip(
                label: Text(profile.toUpperCase()),
                selected: selected,
                onSelected: (_phase == 'idle' || _phase == 'error')
                    ? (_) => setState(() => _profile = profile)
                    : null,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surfaceVariant,
                side: BorderSide(color: selected ? AppColors.primary : Colors.grey.shade300),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesCard() {
    final picked = _files.isNotEmpty;
    return GestureDetector(
      onTap: (_phase == 'idle' || _phase == 'error') ? _pickFiles : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: picked ? AppColors.primary : Colors.grey.shade300,
            width: picked ? 2 : 1,
          ),
        ),
        child: picked
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_library_rounded,
                      color: AppColors.primary, size: 48),
                  const SizedBox(height: 10),
                  Text(
                    _filesDesc,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_files.length} file(s)',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      color: AppColors.primary.withAlpha(180), size: 48),
                  const SizedBox(height: 10),
                  const Text('Tap to select a video or photos',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('MP4, MOV, AVI or JPG, PNG',
                      style: TextStyle(
                          color: AppColors.textHint, fontSize: 12)),
                ],
              ),
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Uploading…',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        LinearPercentIndicator(
          percent: _uploadPct,
          lineHeight: 8,
          backgroundColor: AppColors.surfaceVariant,
          progressColor: AppColors.primary,
          barRadius: const Radius.circular(4),
          padding: EdgeInsets.zero,
          width: MediaQuery.of(context).size.width - 48,
        ),
        const SizedBox(height: 6),
        Text('${(_uploadPct * 100).toInt()}%',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildProcessingCard() {
    final steps = [
      ('uploaded', 'Uploaded'),
      ('extracting_frames', 'Extracting frames'),
      ('reconstructing', 'Running COLMAP pipeline'),
      ('generating_model', 'Generating final model'),
      ('completed', 'Completed'),
    ];
    final currentStageIndex =
        steps.indexWhere((s) => s.$1 == _stage);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _statusMsg,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearPercentIndicator(
            percent: _progress / 100,
            lineHeight: 6,
            backgroundColor: AppColors.surfaceVariant,
            progressColor: AppColors.primary,
            barRadius: const Radius.circular(3),
            padding: EdgeInsets.zero,
            width: MediaQuery.of(context).size.width - 88,
          ),
          const SizedBox(height: 16),
          ...steps.map((s) {
            final index = steps.indexOf(s);
            final done = currentStageIndex > index ||
                (currentStageIndex == index && _progress >= 100);
            final current =
                currentStageIndex == index && _stage != 'completed';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: done
                        ? AppColors.success
                        : current
                            ? AppColors.primary
                            : Colors.grey.shade400,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.$2,
                    style: TextStyle(
                      color: done
                          ? AppColors.success
                          : current
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                      fontSize: 13,
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

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMsg,
              style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final canStart =
        _files.isNotEmpty && (_phase == 'idle' || _phase == 'error');
    final isLoading = _phase == 'uploading' || _phase == 'processing';

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: canStart
            ? _startReconstruction
            : (isLoading ? null : _pickFiles),
        icon: Icon(
            canStart ? Icons.play_arrow_rounded : Icons.add_rounded,
            size: 22),
        label: Text(
          canStart
              ? 'Start Reconstruction'
              : isLoading
                  ? 'Processing…'
                  : 'Select Files',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
