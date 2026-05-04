import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'package:boq_frontend/features/it22172532/config/app_config.dart' as config;
import 'package:boq_frontend/features/it22172532/utils/constants.dart';

class HoughLineTransformScreen extends StatefulWidget {
  const HoughLineTransformScreen({super.key});

  @override
  State<HoughLineTransformScreen> createState() =>
      _HoughLineTransformScreenState();
}

class _HoughLineTransformScreenState extends State<HoughLineTransformScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _loading = false;
  String _status = '';
  String _selectedMethod = 'probabilistic'; // 'probabilistic' or 'standard'
  Map<String, dynamic>? _result;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = picked;
        _result = null;
        _status = '';
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _loading = true;
      _status = 'Processing image...';
    });

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final uri = Uri.parse('${config.AppConfig.baseUrl}/cv/hough');
      final request = http.MultipartRequest('POST', uri)
        ..fields['method'] = _selectedMethod
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: _selectedImage!.name,
          ),
        );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _result = data;
            _status = 'Analysis complete!';
          });
        } else {
          setState(() {
            _status = data['error'] ?? 'Analysis failed';
          });
        }
      } else {
        setState(() {
          _status = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hough Line Transform'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Method Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Hough Method:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Probabilistic'),
                            value: 'probabilistic',
                            groupValue: _selectedMethod,
                            onChanged: (value) {
                              setState(() => _selectedMethod = value!);
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Standard'),
                            value: 'standard',
                            groupValue: _selectedMethod,
                            onChanged: (value) {
                              setState(() => _selectedMethod = value!);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Image Selection
            OutlinedButton.icon(
              onPressed: _loading ? null : _pickImage,
              icon: const Icon(Icons.image),
              label: const Text('Select Image'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Selected Image
            if (_selectedImage != null) ...[
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_selectedImage!.path),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _analyzeImage,
                child: const Text('Analyze Hough Lines'),
              ),
              const SizedBox(height: 16),
            ],

            // Status
            if (_status.isNotEmpty)
              Text(
                _status,
                style: TextStyle(
                  color: _loading ? Colors.blue : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

            // Results
            if (_result != null) ...[
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Results (${_selectedMethod} method):',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Lines detected: ${_result!['count']}'),
                      const SizedBox(height: 12),
                      // Original image
                      if (_result!['original_b64'] != null) ...[
                        const Text(
                          'Original Image:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(_result!['original_b64']),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Processed image
                      const Text(
                        'Hough Lines Detected:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(_result!['image_b64']),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Lines details
                      if (_result!['lines'] != null) ...[
                        const Text(
                          'Line Details:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...(_result!['lines'] as List).map((line) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Line ${line['id']}: Start(${line['start'][0]}, ${line['start'][1]}) Î“Ã¥Ã† End(${line['end'][0]}, ${line['end'][1]}) | Length: ${line['length']}px',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
