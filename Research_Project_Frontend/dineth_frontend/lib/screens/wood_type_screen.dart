import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/endpoints.dart';
import '../core/config.dart';

class WoodTypeScreen extends StatefulWidget {
  const WoodTypeScreen({super.key});

  @override
  State<WoodTypeScreen> createState() => _WoodTypeScreenState();
}

class _WoodTypeScreenState extends State<WoodTypeScreen> {
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
        Endpoints.woodTypePredict,
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
    if (error != null) return Text('Error: $error', style: const TextStyle(color: Colors.red));
    if (result == null) return const SizedBox.shrink();

    final woodType = result!['wood_type'] ?? '';
    final confidence = result!['confidence']?.toString() ?? '';
    final top3 = result!['top3'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Prediction: $woodType', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text('Confidence: $confidence'),
        if (top3.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Top 3:'),
          for (var item in top3)
            Text('${item[0]} (${(item[1] as num).toStringAsFixed(2)})'),
        ]
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wood Type Classifier')),
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
