import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:boq_frontend/features/it22172532/services/wood_api_client.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';

// Dineth's backend endpoint
final String _kWoodApiBase = AppConstants.baseUrl;

const _kWoodTypeEndpoint = '/wood-type/type-predict';


class WoodTypeScreen extends StatefulWidget {
  const WoodTypeScreen({super.key});

  @override
  State<WoodTypeScreen> createState() => _WoodTypeScreenState();
}

class _WoodTypeScreenState extends State<WoodTypeScreen> {
  final _api = WoodApiClient(_kWoodApiBase);


  Uint8List? _imageBytes;
  String? _imageName;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
        _result = null;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_imageBytes == null) return;
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    try {
      final res = await _api.postMultipart(
        _kWoodTypeEndpoint,
        'file',
        _imageBytes!,
        _imageName ?? 'image.jpg',
      );
      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: Colors.brown,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Wood Type Classifier',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _imageBytes != null
                      ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                      : Image.asset(
                          'AppImages/wood/woodTypeClas.png',
                          fit: BoxFit.cover,
                        ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC3E2723)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                children: [
                  _buildActionCard(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.search_rounded),
                      label:
                          Text(_loading ? 'Analysing…' : 'Classify Wood Type'),
                      onPressed:
                          (_imageBytes == null || _loading) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      icon: Icons.error_outline_rounded,
                      iconColor: Colors.red,
                      child: Text('Error: $_error',
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13)),
                    ),
                  ],
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    _buildResultCard(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return _buildInfoCard(
      icon: Icons.photo_library_rounded,
      iconColor: Colors.brown,
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Image',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                SizedBox(height: 2),
                Text(
                  'Pick a wood photo from your gallery',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _pickImage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            child: Text(
              _imageBytes == null ? 'Pick' : 'Change',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final woodType = _result!['wood_type']?.toString() ?? '—';
    final confidence = _result!['confidence']?.toString() ?? '';
    final top3 = _result!['top3'] as List? ?? [];

    return _buildInfoCard(
      icon: Icons.forest_rounded,
      iconColor: Colors.brown,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Classification Result',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          _resultRow('Wood Type', woodType, bold: true),
          if (confidence.isNotEmpty) ...[
            const Divider(height: 20),
            _resultRow('Confidence', '$confidence%'),
          ],
          if (top3.isNotEmpty) ...[
            const Divider(height: 20),
            const Text(
              'Top 3 Predictions',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ...top3.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(e.toString(),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
