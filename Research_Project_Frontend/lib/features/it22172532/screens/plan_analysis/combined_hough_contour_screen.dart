import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'package:boq_frontend/features/it22172532/config/app_config.dart' as config;
import 'package:boq_frontend/features/it22172532/utils/constants.dart';

/// Applies Contour Detection on the uploaded image, then feeds the contour
/// result image into the Hough Line Transform Î“Ã‡Ã¶ showing all three stages.
class CombinedHoughContourScreen extends StatefulWidget {
  const CombinedHoughContourScreen({super.key});

  @override
  State<CombinedHoughContourScreen> createState() =>
      _CombinedHoughContourScreenState();
}

class _CombinedHoughContourScreenState
    extends State<CombinedHoughContourScreen> {
  // Î“Ã¶Ã‡Î“Ã¶Ã‡ State Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡
  XFile? _pickedFile;
  Uint8List? _originalBytes;

  // Stage 1 Î“Ã‡Ã¶ contour
  Uint8List? _contourBytes;
  int? _contourCount;
  double? _contourTime;

  // Stage 2 Î“Ã‡Ã¶ hough on contour result
  Uint8List? _houghBytes;
  int? _houghCount;
  double? _houghTime;

  bool _loading = false;
  String _stage = ''; // current human-readable stage label
  String? _errorMessage;

  String _houghMethod = 'probabilistic';

  final ImagePicker _picker = ImagePicker();

  // Î“Ã¶Ã‡Î“Ã¶Ã‡ Helpers Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedFile = file;
        _originalBytes = bytes;
        _contourBytes = null;
        _houghBytes = null;
        _contourCount = null;
        _houghCount = null;
        _contourTime = null;
        _houghTime = null;
        _errorMessage = null;
        _stage = '';
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to pick image: $e');
    }
  }

  Future<void> _runPipeline() async {
    if (_pickedFile == null || _originalBytes == null) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _contourBytes = null;
      _houghBytes = null;
    });

    try {
      // Î“Ã¶Ã‡Î“Ã¶Ã‡ Stage 1: Contour Detection Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡
      setState(() => _stage = 'Stage 1 / 2 Î“Ã‡Ã¶ Contour DetectionÎ“Ã‡Âª');

      final contourUri =
          Uri.parse('${config.AppConfig.baseUrl}/contour/detect');
      final req1 = http.MultipartRequest('POST', contourUri)
        ..files.add(http.MultipartFile.fromBytes(
          'image',
          _originalBytes!,
          filename: _pickedFile!.name,
        ));

      final s1 = await req1.send().timeout(const Duration(seconds: 60));
      final r1 = await http.Response.fromStream(s1);

      if (r1.statusCode != 200 && r1.statusCode != 422) {
        throw Exception('Contour server error ${r1.statusCode}');
      }

      final d1 = json.decode(r1.body) as Map<String, dynamic>;
      if (d1['success'] != true) {
        throw Exception(d1['error'] ?? 'Contour detection failed');
      }

      final contourB64 = d1['processed_image'] as String?;
      if (contourB64 == null) {
        throw Exception('No processed image returned from contour endpoint');
      }

      final contourImageBytes = base64Decode(contourB64);

      setState(() {
        _contourBytes = contourImageBytes;
        _contourCount = d1['contour_count'] as int?;
        _contourTime = (d1['processing_time'] as num?)?.toDouble();
      });

      // Î“Ã¶Ã‡Î“Ã¶Ã‡ Stage 2: Hough Line Transform on contour result Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡
      setState(() => _stage = 'Stage 2 / 2 Î“Ã‡Ã¶ Hough Line TransformÎ“Ã‡Âª');

      final houghUri = Uri.parse('${config.AppConfig.baseUrl}/cv/hough');
      final req2 = http.MultipartRequest('POST', houghUri)
        ..fields['method'] = _houghMethod
        ..files.add(http.MultipartFile.fromBytes(
          'image',
          contourImageBytes,
          filename: 'contour_result.jpg',
        ));

      final s2 = await req2.send().timeout(const Duration(seconds: 60));
      final r2 = await http.Response.fromStream(s2);

      if (r2.statusCode != 200) {
        throw Exception('Hough server error ${r2.statusCode}');
      }

      final d2 = json.decode(r2.body) as Map<String, dynamic>;
      if (d2['success'] != true) {
        throw Exception(d2['error'] ?? 'Hough transform failed');
      }

      final houghB64 = d2['image_b64'] as String?;
      if (houghB64 == null) {
        throw Exception('No image returned from Hough endpoint');
      }

      setState(() {
        _houghBytes = base64Decode(houghB64);
        _houghCount = d2['count'] as int?;
        _houghTime = (d2['processing_time'] as num?)?.toDouble();
        _stage = 'Pipeline complete!';
      });
    } on SocketException {
      setState(() {
        _errorMessage =
            'Cannot reach backend at ${config.AppConfig.baseUrl}. Make sure backend is running.';
      });
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _reset() {
    setState(() {
      _pickedFile = null;
      _originalBytes = null;
      _contourBytes = null;
      _houghBytes = null;
      _contourCount = null;
      _houghCount = null;
      _contourTime = null;
      _houghTime = null;
      _errorMessage = null;
      _stage = '';
    });
  }

  // Î“Ã¶Ã‡Î“Ã¶Ã‡ UI Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡Î“Ã¶Ã‡

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Combined Houghline & Contour',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_pickedFile != null)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
              tooltip: 'Reset',
              onPressed: _reset,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroHeader(),
            const SizedBox(height: 24),
            _buildMethodSelector(),
            const SizedBox(height: 16),
            _buildUploadSection(),
            const SizedBox(height: 16),
            if (_errorMessage != null) _buildErrorBanner(),
            if (_originalBytes != null && !_loading) ...[
              const SizedBox(height: 8),
              _buildRunButton(),
            ],
            if (_loading) _buildProgressIndicator(),
            if (_contourBytes != null || _houghBytes != null) ...[
              const SizedBox(height: 24),
              _buildPipelineResults(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF6A1B9A), const Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A1B9A).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Combined Houghline & Contour',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Contour detection Î“Ã¥Ã† Hough line transform on the result',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hough Method',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _methodChip('Probabilistic', 'probabilistic',
                    Icons.scatter_plot_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _methodChip(
                    'Standard', 'standard', Icons.grid_on_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _methodChip(String label, String value, IconData icon) {
    final selected = _houghMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _houghMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6A1B9A).withOpacity(0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF6A1B9A) : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected
                    ? const Color(0xFF6A1B9A)
                    : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? const Color(0xFF6A1B9A)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    if (_originalBytes != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.memory(_originalBytes!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _pickImage(ImageSource.gallery),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showPickDialog(),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF6A1B9A).withOpacity(0.4),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_rounded,
                size: 48, color: const Color(0xFF6A1B9A).withOpacity(0.6)),
            const SizedBox(height: 12),
            Text(
              'Tap to upload an image',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'Gallery or Camera',
              style: TextStyle(
                  color: AppColors.textHint, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildRunButton() {
    return ElevatedButton.icon(
      onPressed: _runPipeline,
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text('Run Contour Î“Ã¥Ã† Hough Pipeline'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6A1B9A).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF6A1B9A).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF6A1B9A),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _stage,
              style: const TextStyle(
                  color: Color(0xFF6A1B9A), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stats row
        Row(
          children: [
            if (_contourCount != null)
              Expanded(
                  child: _statChip(Icons.auto_awesome_mosaic_rounded,
                      'Contours', '$_contourCount', const Color(0xFF1565C0))),
            if (_contourCount != null && _houghCount != null)
              const SizedBox(width: 10),
            if (_houghCount != null)
              Expanded(
                  child: _statChip(Icons.line_axis_rounded, 'Hough Lines',
                      '$_houghCount', const Color(0xFF6A1B9A))),
          ],
        ),
        const SizedBox(height: 8),
        if (_contourTime != null || _houghTime != null)
          Row(
            children: [
              if (_contourTime != null)
                Expanded(
                    child: _statChip(Icons.timer_outlined, 'Contour Time',
                        '${_contourTime!.toStringAsFixed(3)}s', Colors.teal)),
              if (_contourTime != null && _houghTime != null)
                const SizedBox(width: 10),
              if (_houghTime != null)
                Expanded(
                    child: _statChip(Icons.timer_outlined, 'Hough Time',
                        '${_houghTime!.toStringAsFixed(3)}s', Colors.orange)),
            ],
          ),
        const SizedBox(height: 20),

        // Stage 0: Original
        _stageLabel(0, 'Original Image'),
        const SizedBox(height: 8),
        _imagePane(_originalBytes!),
        const SizedBox(height: 20),

        // Stage 1: Contour result
        if (_contourBytes != null) ...[
          _stageLabel(1, 'After Contour Detection'),
          const SizedBox(height: 8),
          _imagePane(_contourBytes!),
          const SizedBox(height: 20),
        ],

        // Stage 2: Hough on contour
        if (_houghBytes != null) ...[
          _stageLabel(2, 'After Hough Line Transform (on contour result)'),
          const SizedBox(height: 8),
          _imagePane(_houghBytes!),
          const SizedBox(height: 8),
          Text(
            'Method: $_houghMethod',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _stageLabel(int step, String label) {
    const colors = [Colors.grey, Color(0xFF1565C0), Color(0xFF6A1B9A)];
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: colors[step],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePane(Uint8List bytes) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(bytes,
            width: double.infinity, fit: BoxFit.contain),
      ),
    );
  }

  Widget _statChip(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 10)),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
