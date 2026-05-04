import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../data/datasources/dineth_api_client.dart';
import '../../domain/dineth_config.dart';
import '../../domain/dineth_endpoints.dart';

class WoodDefectsScreen extends StatefulWidget {
  const WoodDefectsScreen({super.key});

  @override
  State<WoodDefectsScreen> createState() => _WoodDefectsScreenState();
}

class _WoodDefectsScreenState extends State<WoodDefectsScreen> {
  final _api = DinethApiClient(dinethApiBaseUrl);

  Uint8List? _imageBytes;
  String? _imageName;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageName = picked.name;
      _result = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_imageBytes == null) return;

    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });

    try {
      final response = await _api.postMultipart(
        DinethEndpoints.woodDefectPredict,
        'file',
        _imageBytes!,
        _imageName ?? 'image.jpg',
      );
      setState(() => _result = response);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.forgeBlackActual,
        foregroundColor: Colors.white,
        title: const Text('Wood Defect Detection'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.s24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ImagePickerPanel(
                  imageBytes: _imageBytes,
                  imageName: _imageName,
                  onPickImage: _pickImage,
                  onSubmit: _submit,
                  submitEnabled: _imageBytes != null && !_loading,
                ),
                const SizedBox(height: AppSizes.s24),
                _WoodDefectResult(
                  loading: _loading,
                  error: _error,
                  result: _result,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePickerPanel extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? imageName;
  final VoidCallback onPickImage;
  final VoidCallback onSubmit;
  final bool submitEnabled;

  const _ImagePickerPanel({
    required this.imageBytes,
    required this.imageName,
    required this.onPickImage,
    required this.onSubmit,
    required this.submitEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.s24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusPanel),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              child: Image.memory(imageBytes!, height: 240, fit: BoxFit.cover),
            ),
            const SizedBox(height: AppSizes.s12),
            Text(
              imageName ?? 'Selected image',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSizes.s16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Pick Image'),
                ),
              ),
              const SizedBox(width: AppSizes.s12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: submitEnabled ? onSubmit : null,
                  icon: const Icon(Icons.search_outlined),
                  label: const Text('Detect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.flameOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WoodDefectResult extends StatelessWidget {
  final bool loading;
  final String? error;
  final Map<String, dynamic>? result;

  const _WoodDefectResult({
    required this.loading,
    required this.error,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return _ResultPanel(
        title: 'Detection Failed',
        icon: Icons.error_outline,
        child: Text(error!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (result == null) return const SizedBox.shrink();

    final defect = result!['defect']?.toString() ?? 'Unknown';
    final confidence = result!['confidence']?.toString() ?? '-';
    final risk = result!['risk']?.toString() ?? '';
    final recommendedUse = result!['recommended_use']?.toString() ?? '';
    final avoidFor = result!['avoid_for']?.toString() ?? '';
    final action = result!['action']?.toString() ?? '';

    return _ResultPanel(
      title: 'Detection Result',
      icon: Icons.report_problem_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            defect,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.s8),
          Text('Confidence: $confidence%'),
          if (risk.isNotEmpty) _ResultLine(label: 'Risk', value: risk),
          if (recommendedUse.isNotEmpty)
            _ResultLine(label: 'Recommended Use', value: recommendedUse),
          if (avoidFor.isNotEmpty) _ResultLine(label: 'Avoid For', value: avoidFor),
          if (action.isNotEmpty) _ResultLine(label: 'Action', value: action),
        ],
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  final String label;
  final String value;

  const _ResultLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.s8),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(color: AppColors.textSecondary),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ResultPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.s24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusPanel),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.flameOrange),
              const SizedBox(width: AppSizes.s8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s16),
          child,
        ],
      ),
    );
  }
}
