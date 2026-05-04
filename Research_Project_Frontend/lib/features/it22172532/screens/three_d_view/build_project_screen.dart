import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import 'package:boq_frontend/features/it22172532/config/app_config.dart' as config;

// --- Constants ---------------------------------------------------------------

const String _kApiKey = 'AIzaSyBL1uhyottDs00SFAr54z9GcoNTW5HBFcg';
const String _kModel = 'gemini-2.5-flash';
const String _kAiUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/$_kModel:generateContent?key=$_kApiKey';

const String _kHardcodedPrompt = '''Act as a structural surveyor and computational architect.

Scan the provided 2D Ground Floor architectural plan carefully and extract only verified structural data with high mathematical accuracy.

Follow these steps strictly:

1) Drawing Scale & Real Size
- Detect the drawing measurement ratio from the plan.
- Convert all dimensions to real-world metric units (meters).
- Clearly state detected scale and conversion factor.
- Ensure zero approximation errors.

2) Global Coordinate System
- Set origin (0,0,0) at the Front-Left Exterior Corner of Ground Floor.
- X axis ? horizontal right
- Y axis ? depth (rear)
- Z axis ? vertical
- Define all coordinates in meters.

3) Extract Structural Measurements
- External boundary corner coordinates
- Internal partition start/end coordinates
- Wall thickness (external & internal)
- All connecting node coordinates
- All segment lengths

4) Angle Accuracy
- For every wall segment:
  dx = x2 - x1
  dy = y2 - y1
  ? = atan2(dy, dx)
- Provide:
  - Degrees (to 3 decimal precision)
  - Radians
- Do NOT assume 90° unless mathematically exact.
- Store angles clearly per segment.

5) Height Extraction
- From Section XX and Section YY:
  - Ground floor clear height
  - Slab thickness
  - Plinth level (if shown)
- Provide exact real vertical values.

6) Openings Extraction (Ground Floor Only)
For each Door and Window:
- Type (D1, W5, etc.)
- Width
- Height
- Sill height
- Wall reference (which segment)
- Exact start coordinate on wall
- Exact center coordinate in global system

7) Output Format
Return everything in a clean, structured JSON format like this:

{
  "scale_info": {},
  "vertical_data": {},
  "external_walls": [],
  "internal_walls": [],
  "wall_angles": [],
  "connecting_nodes": [],
  "doors": [],
  "windows": []
}

Rules:
- No explanations.
- No assumptions.
- No visual guesses.
- Only mathematically derived values.
- Maintain maximum angular precision.
- Ensure coordinate connectivity consistency.

Goal: Produce survey-grade structural JSON data for Ground Floor only.''';

// --- Entry Screen -------------------------------------------------------------

class BuildProjectScreen extends StatefulWidget {
  const BuildProjectScreen({super.key});

  @override
  State<BuildProjectScreen> createState() => _BuildProjectScreenState();
}

enum _ScreenState { upload, loading, results, error }

class _BuildProjectScreenState extends State<BuildProjectScreen> {
  _ScreenState _state = _ScreenState.upload;
  List<PlatformFile> _files = [];
  String _errorMessage = '';
  Map<String, dynamic>? _parsedResult;
  String _rawResponse = '';

  // -- File Picking ---------------------------------------------------------

  Future<void> _pickFiles() async {
    // request storage/photos permission first
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _showSnack('Storage permission required', isError: true);
        return;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        _showSnack('Photos permission required', isError: true);
        return;
      }
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      setState(() {
        _files = [..._files, ...result.files];
      });
    } catch (e) {
      _showSnack('Could not open file picker: $e', isError: true);
    }
  }

  void _removeFile(int index) {
    setState(() => _files.removeAt(index));
  }

  // -- Send to AI --------------------------------------------------------

  /// Gets edge map from contour detection API for a given image bytes
  Future<String?> _getEdgeMap(Uint8List imageBytes, String filename) async {
    try {
      final uri = Uri.parse('${config.AppConfig.baseUrl}/contour/detect');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: filename,
          ),
        );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['edge_map'] != null) {
          return data['edge_map'] as String; // base64 encoded edge map
        }
      }
      // If contour detection fails, return null to fall back to original image
      return null;
    } catch (e) {
      // If contour detection fails, return null to fall back to original image
      return null;
    }
  }

  String _mimeFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'bmp': 'image/bmp',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'md': 'text/plain',
      'csv': 'text/csv',
      'json': 'application/json',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  Future<void> _confirm() async {
    if (_files.isEmpty) {
      _showSnack('Please upload at least one file first.', isError: true);
      return;
    }

    setState(() {
      _state = _ScreenState.loading;
      _errorMessage = '';
      _parsedResult = null;
      _rawResponse = '';
    });

    try {
      // Build parts — process each image through contour detection first
      final List<Map<String, dynamic>> parts = [];

      for (final f in _files) {
        if (f.bytes == null) continue;

        // Try to get edge map from contour detection
        final edgeMapB64 = await _getEdgeMap(f.bytes!, f.name);
        final imageData = edgeMapB64 ?? base64Encode(f.bytes!); // fallback to original if contour fails

        parts.add({
          'inline_data': {
            'mime_type': 'image/jpeg', // edge maps are always JPEG
            'data': imageData,
          },
        });
      }

      parts.add({'text': _kHardcodedPrompt});

      final body = jsonEncode({
        'contents': [
          {'parts': parts}
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'text/plain',
        },
      });

      final response = await http
          .post(
            Uri.parse(_kAiUrl),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        throw Exception(
            'AI API error ${response.statusCode}:\n${response.body}');
      }

      final decoded = jsonDecode(response.body);
      final text = decoded['candidates']?[0]?['content']?['parts']?[0]?['text']
              as String? ??
          '';

      _rawResponse = text;

      // Strip markdown fences if present
      final jsonStr = _extractJson(text);
      final parsed = jsonDecode(jsonStr);

      setState(() {
        _parsedResult = parsed as Map<String, dynamic>;
        _state = _ScreenState.results;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _state = _ScreenState.error;
      });
    }
  }

  /// Strips ```json ... ``` fences and returns the raw JSON string.
  String _extractJson(String text) {
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true);
    final match = fenced.firstMatch(text);
    if (match != null) return match.group(1)!.trim();
    // Try to find first { ... } block
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return text.trim();
  }

  void _reset() {
    setState(() {
      _state = _ScreenState.upload;
      _files = [];
      _parsedResult = null;
      _rawResponse = '';
      _errorMessage = '';
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Build the Project',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          if (_state != _ScreenState.upload)
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
              label: const Text('Reset',
                  style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ScreenState.upload:
        return _UploadView(
          key: const ValueKey('upload'),
          files: _files,
          onPickFiles: _pickFiles,
          onRemoveFile: _removeFile,
          onConfirm: _confirm,
        );
      case _ScreenState.loading:
        return const _LoadingView(key: ValueKey('loading'));
      case _ScreenState.results:
        return _ResultsView(
          key: const ValueKey('results'),
          data: _parsedResult!,
          rawResponse: _rawResponse,
        );
      case _ScreenState.error:
        return _ErrorView(
          key: const ValueKey('error'),
          message: _errorMessage,
          onRetry: _reset,
        );
    }
  }
}

// --- Upload View --------------------------------------------------------------

class _UploadView extends StatelessWidget {
  final List<PlatformFile> files;
  final VoidCallback onPickFiles;
  final void Function(int) onRemoveFile;
  final VoidCallback onConfirm;

  const _UploadView({
    super.key,
    required this.files,
    required this.onPickFiles,
    required this.onRemoveFile,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4CAF50).withOpacity(0.15),
                          const Color(0xFF4CAF50).withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFF4CAF50).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.architecture_rounded,
                              color: Color(0xFF4CAF50), size: 28),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload Building Plan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Upload architectural drawings, images or\ndocuments for AI structural analysis',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Drop zone
                  GestureDetector(
                    onTap: onPickFiles,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withOpacity(0.5),
                          width: 2,
                          style: BorderStyle.none,
                        ),
                      ),
                      child: CustomPaint(
                        painter: _DashedBorderPainter(),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF4CAF50).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.cloud_upload_rounded,
                                  size: 48, color: Color(0xFF4CAF50)),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tap to upload files',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Supports: Images (JPG, PNG, WebP)\nDocuments (PDF, DOC, TXT, JSON) and more',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: onPickFiles,
                              icon: const Icon(Icons.add_rounded,
                                  color: Color(0xFF4CAF50)),
                              label: const Text('Choose Files',
                                  style: TextStyle(color: Color(0xFF4CAF50))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Color(0xFF4CAF50), width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // File list
                  if (files.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selected Files (${files.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: onPickFiles,
                          icon: const Icon(Icons.add_circle_outline,
                              size: 18, color: Color(0xFF4CAF50)),
                          label: const Text('Add More',
                              style: TextStyle(color: Color(0xFF4CAF50))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                        files.length, (i) => _FileListTile(file: files[i], onRemove: () => onRemoveFile(i))),
                  ],

                  const SizedBox(height: 100), // bottom padding for FAB
                ],
              ),
            ),
          ),

          // Confirm button (sticky at bottom)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.background,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, -3)),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: files.isEmpty ? null : onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  disabledBackgroundColor: Colors.grey.shade800,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  files.isEmpty
                      ? 'Upload files to continue'
                      : 'Confirm & Analyze (${files.length} file${files.length > 1 ? 's' : ''})',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileListTile extends StatelessWidget {
  final PlatformFile file;
  final VoidCallback onRemove;

  const _FileListTile({required this.file, required this.onRemove});

  String get _sizeLabel {
    if (file.size < 1024) return '${file.size} B';
    if (file.size < 1024 * 1024) {
      return '${(file.size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData get _icon {
    final ext = file.extension?.toLowerCase() ?? '';
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) {
      return Icons.image_rounded;
    }
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if (['doc', 'docx'].contains(ext)) return Icons.article_rounded;
    if (ext == 'json') return Icons.data_object_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color get _iconColor {
    final ext = file.extension?.toLowerCase() ?? '';
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) {
      return Colors.blue;
    }
    if (ext == 'pdf') return Colors.red;
    if (['doc', 'docx'].contains(ext)) return Colors.blueAccent;
    if (ext == 'json') return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, color: _iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(_sizeLabel,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// --- Loading View -------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
            ),
          ),
          SizedBox(height: 32),
          Text(
            'Analyzing Building Plan...',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            'AI is extracting structural data\nwith survey-grade precision.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// --- Error View ---------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded,
                  size: 60, color: AppColors.error),
            ),
            const SizedBox(height: 24),
            const Text(
              'Analysis Failed',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message,
                style: TextStyle(color: AppColors.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Try Again',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Results View -------------------------------------------------------------

class _ResultsView extends StatefulWidget {
  final Map<String, dynamic> data;
  final String rawResponse;

  const _ResultsView({super.key, required this.data, required this.rawResponse});

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<_ResultsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showRaw = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyRaw() {
    Clipboard.setData(ClipboardData(text: widget.rawResponse));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Copied to clipboard'),
      duration: Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      children: [
        // Summary banner
        _buildSummaryBanner(d),

        // Tab bar
        Container(
          color: AppColors.cardBackground,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: const Color(0xFF4CAF50),
            unselectedLabelColor: Colors.white54,
            indicatorColor: const Color(0xFF4CAF50),
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Scale'),
              Tab(text: 'Heights'),
              Tab(text: 'Ext. Walls'),
              Tab(text: 'Int. Walls'),
              Tab(text: 'Angles'),
              Tab(text: 'Nodes'),
              Tab(text: 'Doors'),
              Tab(text: 'Windows'),
            ],
          ),
        ),

        // Content
        Expanded(
          child: Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: [
                  _ScaleInfoTab(data: d['scale_info']),
                  _VerticalDataTab(data: d['vertical_data']),
                  _WallsTab(walls: d['external_walls'], label: 'External Walls'),
                  _WallsTab(walls: d['internal_walls'], label: 'Internal Walls'),
                  _AnglesTab(angles: d['wall_angles']),
                  _NodesTab(nodes: d['connecting_nodes']),
                  _OpeningsTab(items: d['doors'], label: 'Doors', icon: Icons.door_front_door_rounded),
                  _OpeningsTab(items: d['windows'], label: 'Windows', icon: Icons.window_rounded),
                ],
              ),

              // Raw JSON toggle
              Positioned(
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_showRaw) ...[
                      Container(
                        width: MediaQuery.of(context).size.width - 24,
                        height: 260,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            const JsonEncoder.withIndent('  ')
                                .convert(widget.data),
                            style: const TextStyle(
                                color: Color(0xFF4CAF50),
                                fontSize: 11,
                                fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _iconBtn(
                            icon: Icons.copy_rounded,
                            tooltip: 'Copy JSON',
                            onTap: _copyRaw,
                          ),
                          const SizedBox(width: 8),
                          _iconBtn(
                            icon: Icons.close_rounded,
                            tooltip: 'Hide',
                            onTap: () => setState(() => _showRaw = false),
                          ),
                        ],
                      ),
                    ] else
                      _iconBtn(
                        icon: Icons.code_rounded,
                        tooltip: 'View raw JSON',
                        onTap: () => setState(() => _showRaw = true),
                        label: 'JSON',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    String? label,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              EdgeInsets.symmetric(horizontal: label != null ? 12 : 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(label,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBanner(Map<String, dynamic> d) {
    final extWalls = (d['external_walls'] as List?)?.length ?? 0;
    final intWalls = (d['internal_walls'] as List?)?.length ?? 0;
    final doors = (d['doors'] as List?)?.length ?? 0;
    final windows = (d['windows'] as List?)?.length ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statChip(Icons.crop_square_rounded, '$extWalls', 'Ext Walls'),
          _divider(),
          _statChip(Icons.linear_scale_rounded, '$intWalls', 'Int Walls'),
          _divider(),
          _statChip(Icons.door_front_door_rounded, '$doors', 'Doors'),
          _divider(),
          _statChip(Icons.window_rounded, '$windows', 'Windows'),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _divider() => Container(
      width: 1, height: 40, color: Colors.white.withOpacity(0.2));
}

// --- Tab: Scale Info ----------------------------------------------------------

class _ScaleInfoTab extends StatelessWidget {
  final dynamic data;

  const _ScaleInfoTab({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return _emptyState('No scale info available');
    final map = data as Map<String, dynamic>;
    return _KeyValueTable(title: 'Drawing Scale & Measurement Info', entries: map);
  }
}

// --- Tab: Vertical Data -------------------------------------------------------

class _VerticalDataTab extends StatelessWidget {
  final dynamic data;

  const _VerticalDataTab({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return _emptyState('No vertical data available');
    final map = data as Map<String, dynamic>;
    return _KeyValueTable(title: 'Vertical / Height Data', entries: map);
  }
}

// --- Tab: Walls ---------------------------------------------------------------

class _WallsTab extends StatelessWidget {
  final dynamic walls;
  final String label;

  const _WallsTab({required this.walls, required this.label});

  @override
  Widget build(BuildContext context) {
    if (walls == null || (walls as List).isEmpty) {
      return _emptyState('No $label data available');
    }
    final list = walls as List;
    return _buildScrollable(
      ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (ctx, i) {
          final wall = list[i] as Map<String, dynamic>;
          return _CardTable(
            heading: '$label ${i + 1}',
            index: i + 1,
            color: label.contains('External')
                ? const Color(0xFF1565C0)
                : const Color(0xFF6A1B9A),
            entries: wall,
          );
        },
      ),
    );
  }
}

// --- Tab: Angles -------------------------------------------------------------

class _AnglesTab extends StatelessWidget {
  final dynamic angles;

  const _AnglesTab({required this.angles});

  @override
  Widget build(BuildContext context) {
    if (angles == null || (angles as List).isEmpty) {
      return _emptyState('No angle data available');
    }
    final list = angles as List;
    return _buildScrollable(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _sectionHeader('Wall Angles', Icons.rotate_right_rounded,
                const Color(0xFF00838F)),
            const SizedBox(height: 12),
            _DataTable(
              columns: const ['Segment / ID', 'Degrees', 'Radians', 'dx', 'dy'],
              rows: list.map((item) {
                final m = item as Map<String, dynamic>;
                return [
                  m['segment_id']?.toString() ??
                      m['id']?.toString() ??
                      m['wall_id']?.toString() ??
                      '—',
                  _fmt(m['degrees'] ?? m['angle_degrees'] ?? m['theta_degrees']),
                  _fmt(m['radians'] ?? m['angle_radians'] ?? m['theta_radians']),
                  _fmt(m['dx']),
                  _fmt(m['dy']),
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Tab: Nodes ---------------------------------------------------------------

class _NodesTab extends StatelessWidget {
  final dynamic nodes;

  const _NodesTab({required this.nodes});

  @override
  Widget build(BuildContext context) {
    if (nodes == null || (nodes as List).isEmpty) {
      return _emptyState('No node data available');
    }
    final list = nodes as List;
    return _buildScrollable(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _sectionHeader('Connecting Nodes', Icons.hub_rounded,
                const Color(0xFFF57F17)),
            const SizedBox(height: 12),
            _DataTable(
              columns: const ['Node ID', 'X (m)', 'Y (m)', 'Z (m)', 'Connected'],
              rows: list.map((item) {
                final m = item as Map<String, dynamic>;
                final coord = m['coordinate'] as Map<String, dynamic>? ?? m;
                return [
                  m['node_id']?.toString() ??
                      m['id']?.toString() ??
                      '—',
                  _fmt(coord['x']),
                  _fmt(coord['y']),
                  _fmt(coord['z'] ?? 0),
                  (m['connected_to'] as List?)?.join(', ') ?? '—',
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Tab: Openings (Doors / Windows) -----------------------------------------

class _OpeningsTab extends StatelessWidget {
  final dynamic items;
  final String label;
  final IconData icon;

  const _OpeningsTab(
      {required this.items, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (items == null || (items as List).isEmpty) {
      return _emptyState('No $label data available');
    }
    final list = items as List;
    return _buildScrollable(
      ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (ctx, i) {
          final item = list[i] as Map<String, dynamic>;
          return _CardTable(
            heading:
                '$label — ${item['type'] ?? item['id'] ?? (i + 1).toString()}',
            index: i + 1,
            color: label == 'Doors'
                ? const Color(0xFF4E342E)
                : const Color(0xFF0277BD),
            entries: item,
            icon: icon,
          );
        },
      ),
    );
  }
}

// --- Shared Widgets -----------------------------------------------------------

class _KeyValueTable extends StatelessWidget {
  final String title;
  final Map<String, dynamic> entries;

  const _KeyValueTable({required this.title, required this.entries});

  @override
  Widget build(BuildContext context) {
    return _buildScrollable(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20).withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF4CAF50), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: entries.entries
                    .toList()
                    .asMap()
                    .entries
                    .map((e) {
                      final isLast = e.key == entries.length - 1;
                      final kv = e.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : Border(
                                  bottom: BorderSide(
                                      color: Colors.white.withOpacity(0.07))),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 140,
                              child: Text(
                                _formatKey(kv.key),
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _valStr(kv.value),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardTable extends StatelessWidget {
  final String heading;
  final int index;
  final Color color;
  final Map<String, dynamic> entries;
  final IconData? icon;

  const _CardTable({
    required this.heading,
    required this.index,
    required this.color,
    required this.entries,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.25),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Icon(icon ?? Icons.square_foot_rounded,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    heading,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          // KV rows
          ...entries.entries.map((kv) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: Colors.white.withOpacity(0.05))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        _formatKey(kv.key),
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _valStr(kv.value),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _DataTable extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;

  const _DataTable({required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
              Colors.white.withOpacity(0.05)),
          headingTextStyle: const TextStyle(
              color: Color(0xFF4CAF50),
              fontSize: 12,
              fontWeight: FontWeight.bold),
          dataTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
          columnSpacing: 20,
          horizontalMargin: 16,
          dividerThickness: 0.5,
          columns:
              columns.map((c) => DataColumn(label: Text(c))).toList(),
          rows: rows
              .map((r) => DataRow(
                    cells: r
                        .map((cell) => DataCell(Text(cell)))
                        .toList(),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// --- Helpers ------------------------------------------------------------------

Widget _emptyState(String msg) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox_rounded, size: 56, color: Colors.white24),
        const SizedBox(height: 12),
        Text(msg,
            style: const TextStyle(color: Colors.white38, fontSize: 15)),
      ],
    ),
  );
}

Widget _buildScrollable(Widget child) => child;

Widget _sectionHeader(String title, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    ),
  );
}

String _formatKey(String key) {
  return key
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
      .join(' ');
}

String _valStr(dynamic v) {
  if (v == null) return '—';
  if (v is Map) {
    return v.entries
        .map((e) => '${_formatKey(e.key)}: ${_valStr(e.value)}')
        .join(' | ');
  }
  if (v is List) return v.map(_valStr).join(', ');
  return v.toString();
}

String _fmt(dynamic v) {
  if (v == null) return '—';
  if (v is num) {
    // Show up to 3 decimal places, trim trailing zeros
    final s = v.toStringAsFixed(3);
    return s.contains('.')
        ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
        : s;
  }
  return v.toString();
}

// --- Dashed Border Painter ----------------------------------------------------

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final radius = const Radius.circular(16);
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), radius);
    final path = Path()..addRRect(rrect);
    final pathMetrics = path.computeMetrics();

    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final extractPath =
            metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
