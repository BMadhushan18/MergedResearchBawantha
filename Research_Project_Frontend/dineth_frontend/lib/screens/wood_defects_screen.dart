import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/endpoints.dart';

class WoodDefectsScreen extends StatefulWidget {
  const WoodDefectsScreen({super.key});

  @override
  State<WoodDefectsScreen> createState() => _WoodDefectsScreenState();
}

class _WoodDefectsScreenState extends State<WoodDefectsScreen> {
  final api = ApiClient(kDinethApiBase);

  Uint8List? _imageBytes;
  String? _imageName;

  bool loading = false;
  Map<String, dynamic>? result;
  String? error;

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
        result = null;
        error = null;
      });
    }
  }

  Future<void> submit() async {
    if (_imageBytes == null) return;
    setState(() {
      loading = true;
      result = null;
      error = null;
    });
    try {
      final res = await api.postMultipart(
        Endpoints.woodDefectPredict,
        'file',
        _imageBytes!,
        _imageName ?? 'image.jpg',
      );
      setState(() => result = res);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Widget buildResult() {
    if (loading) return const CircularProgressIndicator();
    if (error != null) {
      return Text('Error: $error', style: const TextStyle(color: Colors.red));
    }
    if (result == null) return const SizedBox.shrink();

    final defect = result!['defect'] ?? '';
    final confidence = result!['confidence']?.toString() ?? '';
    final risk = result!['risk'] ?? '';
    final recommendedUse = result!['recommended_use'] ?? '';
    final avoidFor = result!['avoid_for'] ?? '';
    final action = result!['action'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Defect: $defect', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Confidence: $confidence%'),
        const SizedBox(height: 8),
        if (risk.isNotEmpty) ...[
          Text('Risk: $risk', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
        ],
        if (recommendedUse.isNotEmpty) ...[
          Text('Recommended Use: $recommendedUse'),
          const SizedBox(height: 4),
        ],
        if (avoidFor.isNotEmpty) ...[
          Text('Avoid For: $avoidFor'),
          const SizedBox(height: 4),
        ],
        if (action.isNotEmpty) ...[
          Text('Action: $action'),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wood Defect Classifier')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_imageBytes != null) Image.memory(_imageBytes!, height: 200),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Pick Image'),
              onPressed: pickImage,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (_imageBytes == null || loading) ? null : submit,
              child: const Text('Submit'),
            ),
            const SizedBox(height: 24),
            buildResult(),
          ],
        ),
      ),
    );
  }
}
