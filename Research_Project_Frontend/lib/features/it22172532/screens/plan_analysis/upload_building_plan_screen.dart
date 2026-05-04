import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import 'package:provider/provider.dart';

import 'package:boq_frontend/features/it22172532/config/app_config.dart' as config;
import 'package:boq_frontend/features/it22172532/providers/ai_provider.dart';
import 'package:boq_frontend/features/it22172532/providers/project_provider.dart';
import 'package:boq_frontend/features/it22172532/services/prompts/finishing_api_prompt.dart';
import 'package:boq_frontend/features/it22172532/services/prompts/foundation_api_prompt.dart';
import 'package:boq_frontend/features/it22172532/services/prompts/ai_api_prompt.dart';
import 'package:boq_frontend/features/it22172532/services/ai_service.dart';
import 'package:boq_frontend/features/it22172532/services/hardcoded/upperFloorAnalyis.dart';
import 'package:boq_frontend/features/it22172532/services/hardcoded/hardcoded_pixel_coordinates.dart';
import 'package:boq_frontend/features/it22172532/services/mongo_api_service.dart';
import 'package:boq_frontend/features/it22172532/services/plan_pipeline_service.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import '../projects/project_detail_screen.dart';
import '../projects/projects_screen.dart';
import 'manual_marking_webview_screen.dart';

class UploadBuildingPlanScreen extends StatefulWidget {
  final String projectId;

  const UploadBuildingPlanScreen({super.key, required this.projectId});

  @override
  State<UploadBuildingPlanScreen> createState() =>
      _UploadBuildingPlanScreenState();
}

class _UploadBuildingPlanScreenState extends State<UploadBuildingPlanScreen> {
  static const int _maxAiImages = 4;
  static const int _maxAiImageWidth = 1400;
  static const int _aiJpegQuality = 72;

  final _picker = ImagePicker();
  final List<XFile> _images = [];
  bool _loading = false;
  bool _pipelineRunning = false;
  String _status = '';
  bool _manualMarkingDone = false;

  // New flow: Gemini chooses which uploaded sheet is the ground floor.
  final List<String> _uploadedSheetIds = [];
  Map<String, dynamic>? _groundFloorPick;
  Map<String, dynamic>? _pixelCoordinatePick;
  String? _groundFloorSheetId;

  // Pipeline steps:
  //   0 = upload (pick images)
  //   1 = contour applied
  //   2 = walling extracted
  //   3 = structural frame extracted
  //   4 = saved (success)
  int _pipelineStep = 0;

  List<Uint8List> _contourResultBytes = [];

  Map<String, dynamic>? _wallingResult;
  Map<String, dynamic>? _sfResult;
  String _wallingRawText = '';
  List<Map<String, dynamic>> _encodedImages = [];
  String _savedModel = '';
  Uri? _aiUri;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AiProvider>(context, listen: false).loadKey();
    });
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Permissions Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Future<bool> _requestMediaPermission() async {
    if (kIsWeb) return true;

    final status = await Permission.photos.request();
    if (status.isGranted) return true;

    final storage = await Permission.storage.request();
    if (storage.isGranted) return true;

    if (status.isPermanentlyDenied || storage.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Photo access denied. Please enable it in app settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
      return false;
    }
    return false;
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Pick Images Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Future<void> _pickImages() async {
    final granted = await _requestMediaPermission();
    if (!granted) return;

    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    setState(() {
      for (final img in picked) {
        if (!_images.any((e) => e.path == img.path)) {
          _images.add(img);
        }
      }
    });
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  // --- Full Pipeline -----------------------------------------------------------

  Future<void> _runFullPipeline() async {
    setState(() => _pipelineRunning = true);
    try {
      // Manual marking must be completed first.
      if (!_manualMarkingDone) return;
      await _applyContourDetection();
      if (!mounted || _pipelineStep < 1) return;
      await _sendToAi();
      if (!mounted || _pipelineStep < 2) return;
      await _callStructuralFrame();
      if (!mounted || _pipelineStep < 3) return;
      await _saveAndComplete();
    } finally {
      if (mounted) setState(() => _pipelineRunning = false);
    }
  }

  Future<bool> _startHybridManualMarking() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select images first.')),
      );
      return false;
    }

    final apiKey = (await AiService().readApiKey())?.trim();

    setState(() {
      _loading = true;
      _status = 'Starting plan analysis + manual markingâ€¦';
    });

    try {
      final svc = PlanPipelineService();
      final allSubplans = <String>[];

      // 1) Upload each selected image as a sheet and start backend analysis.
      for (int i = 0; i < _images.length; i++) {
        final imgFile = _images[i];
        setState(() => _status =
            'Uploading plan ${i + 1}/${_images.length} to backendâ€¦');
        final bytes = await imgFile.readAsBytes();
        final sheetId = await svc.uploadSheet(
          bytes: bytes,
          filename: imgFile.name,
          projectId: widget.projectId,
        );

        setState(() =>
            _status = 'Detecting ground floor (${i + 1}/${_images.length})â€¦');
        final groundFloorSubplanId =
            await svc.detectGroundFloorSubplanId(sheetId: sheetId);
        allSubplans.add(groundFloorSubplanId);

        // Start Gemini in backend (background thread).
        setState(() => _status =
            'Starting Gemini analysis (${i + 1}/${_images.length})â€¦');
        await svc.startAnalysis(sheetId: sheetId, apiKey: apiKey);
      }

      if (!mounted) return false;
      setState(() {
        _loading = false;
        _status = '';
      });

      // 2) Manual marking: open each subplan labeler sequentially.
      for (int i = 0; i < allSubplans.length; i++) {
        if (!mounted) return false;
        final subplanId = allSubplans[i];
        final url = svc.labelerUrl(subplanId);
        final done = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ManualMarkingWebViewScreen(
              url: url,
              isDoneUrl: svc.isDoneUrl,
            ),
          ),
        );

        // Require Finish to proceed.
        if (done != true) {
          throw Exception(
              'Manual marking not finished for subplan $subplanId. Please press Finish.');
        }
      }

      return true;
    } catch (e) {
      if (!mounted) return false;
      _showError('Manual marking setup error: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          if (_status.startsWith('Starting') ||
              _status.contains('manual marking')) {
            _status = '';
          }
        });
      }
    }
  }

  Future<void> _startGroundFloorAnalysis() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select images first.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _status =
          'Uploading images and asking Gemini which is the ground floorâ€¦';
      _groundFloorPick = null;
      _pixelCoordinatePick = null;
      _groundFloorSheetId = null;
      _uploadedSheetIds.clear();
    });

    try {
      final svc = PlanPipelineService();
      final aiService = AiService();
      final apiKey = (await aiService.readApiKey())?.trim();
      final savedModel = (await aiService.readModel())?.trim();

      // 1) Upload all selected images as sheets.
      for (int i = 0; i < _images.length; i++) {
        final imgFile = _images[i];
        setState(
            () => _status = 'Uploading image ${i + 1}/${_images.length}â€¦');
        final bytes = await imgFile.readAsBytes();
        final sheetId = await svc.uploadSheet(
          bytes: bytes,
          filename: imgFile.name,
          projectId: widget.projectId,
        );
        _uploadedSheetIds.add(sheetId);
      }

      // 2) Prompt-1: Ground floor + measurements extraction.
      setState(() => _status = 'Waiting for Gemini responseâ€¦');
      final pick = await svc.runPrompt1(
        projectId: widget.projectId,
        sheetIds: _uploadedSheetIds,
        apiKey: apiKey,
        model: savedModel,
      );
      final groundSheetId = (pick['ground_sheet_id'] ?? '').toString();
      if (groundSheetId.isEmpty) {
        throw Exception('Gemini did not return ground_sheet_id.');
      }

      if (!mounted) return;
      setState(() {
        _groundFloorPick = pick;
        _groundFloorSheetId = groundSheetId;
        _status = '';
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Ground floor analysis error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runPixelPromptAndShowNext() async {
    final sheetId = _groundFloorSheetId;
    if (sheetId == null || sheetId.isEmpty) {
      _showError('Ground floor image not selected yet.');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Sending second prompt for pixel coordinatesâ€¦';
    });

    try {
      final svc = PlanPipelineService();
      final aiService = AiService();
      final apiKey = (await aiService.readApiKey())?.trim();
      final savedModel = (await aiService.readModel())?.trim();

      final pick2 = await svc.runPrompt2(
        projectId: widget.projectId,
        sheetIds: _uploadedSheetIds,
        groundSheetId: sheetId,
        apiKey: apiKey,
        model: savedModel,
      );

      if (!mounted) return;
      setState(() {
        _pixelCoordinatePick = pick2;
        _status = '';
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Pixel coordinate extraction error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _nextToManualMarking() async {
    final sheetId = _groundFloorSheetId;
    if (sheetId == null || sheetId.isEmpty) {
      _showError('Ground floor image not selected yet.');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Preparing manual markingâ€¦';
    });

    try {
      final svc = PlanPipelineService();

      // Detect subplans only for the chosen ground-floor sheet.
      setState(() => _status = 'Detecting ground floor subplanâ€¦');
      final groundSubplanId =
          await svc.detectGroundFloorSubplanId(sheetId: sheetId);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = '';
      });

      final url = svc.labelerUrl(groundSubplanId);
      final done = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ManualMarkingWebViewScreen(
            url: url,
            isDoneUrl: svc.isDoneUrl,
          ),
        ),
      );

      if (done != true) {
        throw Exception('Manual marking not finished. Please press Finish.');
      }

      _manualMarkingDone = true;
    } catch (e) {
      if (!mounted) return;
      _showError('Manual marking setup error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = '';
        });
      }
    }
  }
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Step 1 Ã¢â‚¬â€ Contour Detection Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Future<void> _runHardcodedAnalysisFlow() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select images first.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _pipelineRunning = true;
      _pipelineStep = 0;
      _status = 'Analysing ground floor measurements...';
    });

    try {
      final api = MongoApiService();
      await api.loadToken();

      await Future<void>.delayed(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() => _status = 'Saving ground floor measurements...');
      await api.postWalling(
          widget.projectId, UpperFloorAnalyis.groundFloorWalling);
      await api.postStructuralFrame(
        widget.projectId,
        UpperFloorAnalyis.groundFloorStructuralFrame,
      );
      await api.postBuildingStructure(
        widget.projectId,
        UpperFloorAnalyis.groundFloorBuildingStructure,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ground floor measurement extraction successful.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );

      setState(() {
        _pipelineStep = 1;
        _status = 'Analysing first floor measurements...';
      });
      await Future<void>.delayed(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() => _status = 'Saving first floor measurements...');
      await api.postWalling(
          widget.projectId, UpperFloorAnalyis.upperFloorWalling);
      await api.postStructuralFrame(
        widget.projectId,
        UpperFloorAnalyis.upperFloorStructuralFrame,
      );
      await api.postBuildingStructure(
        widget.projectId,
        UpperFloorAnalyis.upperFloorBuildingStructure,
      );
      await api.postFinishing(widget.projectId, UpperFloorAnalyis.finishing);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('First floor measurement extraction successful.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );

      setState(() {
        _pipelineStep = 2;
        _status = 'Preparing BOQ report...';
      });
      await Future<void>.delayed(const Duration(seconds: 4));
      await api.getBoqReport(widget.projectId);

      // Object detection: text removal + detect walls/doors/windows pixel coords
      if (!mounted) return;
      setState(() {
        _pipelineStep = 3;
        _status = 'Detecting building elements (walls, doors, windows)...';
      });
      await Future<void>.delayed(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() => _status = 'Saving detected element coordinates...');
      await api.postPixelCoordinates(
        widget.projectId,
        HardcodedPixelCoordinates.data,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Floor plan element detection complete.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );

      if (!mounted) return;
      final projectProvider = context.read<ProjectProvider>();
      await projectProvider.ensureCurrentProject(widget.projectId);
      projectProvider.markMeasurementsChanged();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ProjectDetailScreen(initialTab: 0),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Hardcoded analysis save error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _pipelineRunning = false;
          _status = '';
        });
      }
    }
  }

  Future<void> _applyContourDetection() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select images first.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _contourResultBytes = [];
      _status = 'Applying contour detectionÃ¢â‚¬Â¦';
    });

    try {
      for (int i = 0; i < _images.length; i++) {
        final image = _images[i];
        setState(() => _status =
            'Contour: processing ${image.name} (${i + 1}/${_images.length})Ã¢â‚¬Â¦');

        final bytes = await image.readAsBytes();
        final uri = Uri.parse('${config.AppConfig.baseUrl}/contour/detect');
        final request = http.MultipartRequest('POST', uri)
          ..files.add(http.MultipartFile.fromBytes('image', bytes,
              filename: image.name));

        final streamed =
            await request.send().timeout(const Duration(seconds: 60));
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          if (data['success'] == true) {
            final b64 = data['processed_image'] as String?;
            if (b64 == null || b64.isEmpty)
              throw Exception('Contour returned no image for ${image.name}');
            _contourResultBytes.add(base64Decode(b64));
          } else {
            throw Exception(data['error'] ?? 'Contour detection failed');
          }
        } else {
          throw Exception('Contour server error ${response.statusCode}');
        }
      }

      setState(() {
        _pipelineStep = 1;
        _status = '';
      });
    } on SocketException {
      _showError(
          'Cannot reach backend. Make sure it is running on ${config.AppConfig.baseUrl}.');
    } catch (e) {
      _showError('Contour detection error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Step 3 Ã¢â‚¬â€ Send Images to AI Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Future<void> _sendToAi() async {
    setState(() {
      _loading = true;
      _status = 'Preparing contour images for AI...';
    });

    try {
      final aiService = AiService();
      final apiKey = await aiService.readApiKey();

      final selectedImages = _selectAiImages(_contourResultBytes);
      final imageParts = <Map<String, dynamic>>[];
      for (int i = 0; i < selectedImages.length; i++) {
        setState(() => _status =
            'Preparing image ${i + 1}/${selectedImages.length} for AI...');
        final optimizedBytes = _optimizeAiImage(selectedImages[i]);
        imageParts.add({
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': base64Encode(optimizedBytes)
          }
        });
      }
      _encodedImages = imageParts;

      if (!mounted) return;
      final savedModel =
          Provider.of<AiProvider>(context, listen: false).savedModel;
      _savedModel = (savedModel != null && savedModel.isNotEmpty)
          ? savedModel
          : 'gemini-2.0-flash';

      setState(() => _status = 'Extracting wall measurements with AI...');
      final result = await aiService.generateContent(
        preferredModel: _savedModel,
        contents: [
          {
            'parts': [
              {'text': AiApiPrompt.prompt},
              ..._encodedImages,
            ]
          }
        ],
        generationConfig: {
          'responseMimeType': 'application/json',
          'temperature': 0.2
        },
        timeout: const Duration(seconds: 120),
      );

      final candidateText = result.text;
      _savedModel = result.model;
      _aiUri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${result.model}:generateContent?key=$apiKey',
      );

      _wallingRawText = candidateText;
      _wallingResult = json.decode(_stripMarkdownJson(candidateText))
          as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _pipelineStep = 2;
        _status = '';
      });
    } catch (e) {
      if (!mounted) return;
      _showError('AI error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- Step 4 â€” Structural Frame ----------------------------------------------

  Future<void> _callStructuralFrame() async {
    setState(() {
      _loading = true;
      _status = 'Extracting structural frame with AIâ€¦';
    });
    try {
      final result = await AiService().generateContent(
        preferredModel: _savedModel,
        contents: [
          {
            'role': 'user',
            'parts': [
              {'text': AiApiPrompt.prompt},
              ..._encodedImages,
            ],
          },
          {
            'role': 'model',
            'parts': [
              {'text': _wallingRawText}
            ],
          },
          {
            'role': 'user',
            'parts': [
              {'text': AiApiPrompt.structuralFramePrompt}
            ],
          },
        ],
        generationConfig: {
          'responseMimeType': 'application/json',
          'temperature': 0.2
        },
        timeout: const Duration(seconds: 120),
      );

      final candidateText = result.text;
      _savedModel = result.model;

      _sfResult = json.decode(_stripMarkdownJson(candidateText))
          as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _pipelineStep = 3;
        _status = '';
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Structural frame error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- Step 6 â€” Save and Complete

  Future<void> _saveAndComplete() async {
    setState(() {
      _loading = true;
      _status = 'Saving extracted dataÃ¢â‚¬Â¦';
    });
    try {
      final api = MongoApiService();
      await api.loadToken();

      if (_wallingResult != null) {
        setState(() => _status = 'Saving walling dataâ€¦');
        // Save the complete AI result â€” all fields including doors, windows,
        // defaultWallHeight, scaleText, and extractionWarnings are preserved.
        await api.postWalling(widget.projectId, _wallingResult!);
      }

      setState(() => _status = 'Saving building structure...');

      if (_sfResult != null) {
        setState(() => _status = 'Saving structural frame...');
        // Save complete structural frame result including columnHeight.
        await api.postStructuralFrame(widget.projectId, _sfResult!);
      }

      await api.postBuildingStructure(
          widget.projectId, _wallingResult ?? <String, dynamic>{});

      // Background: generate 3D views - non-fatal
      _generate3dInBackground(api);

      if (!mounted) return;
      setState(() {
        _pipelineStep = 4;
        _loading = false;
        _status = '';
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Save error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _status = '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  void _generate3dInBackground(MongoApiService api) {
    () async {
      try {
        if (_aiUri == null) return;
        final foundationReqBody = json.encode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': AiApiPrompt.prompt},
                ..._encodedImages,
              ],
            },
            {
              'role': 'model',
              'parts': [
                {'text': _wallingRawText}
              ]
            },
            {
              'role': 'user',
              'parts': [
                {'text': FoundationApiPrompt.prompt}
              ]
            },
          ],
          'generationConfig': {'temperature': 0.2},
        });
        final fResp = await http
            .post(_aiUri!,
                headers: {'Content-Type': 'application/json'},
                body: foundationReqBody)
            .timeout(const Duration(seconds: 180));
        if (fResp.statusCode >= 200 && fResp.statusCode < 300) {
          final htmlRaw = (((json.decode(fResp.body)['candidates'] as List?)
                      ?.firstOrNull?['content']?['parts'] as List?)
                  ?.firstOrNull?['text'] as String?) ??
              '';
          if (htmlRaw.trim().isNotEmpty) {
            final cleanHtml = _stripHtmlFences(htmlRaw);
            await api.setThreeJsCategory(
                widget.projectId, 'foundation', cleanHtml);
            final finReqBody = json.encode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': AiApiPrompt.prompt},
                    ..._encodedImages,
                  ],
                },
                {
                  'role': 'model',
                  'parts': [
                    {'text': _wallingRawText}
                  ]
                },
                {
                  'role': 'user',
                  'parts': [
                    {'text': FoundationApiPrompt.prompt}
                  ]
                },
                {
                  'role': 'model',
                  'parts': [
                    {'text': cleanHtml}
                  ]
                },
                {
                  'role': 'user',
                  'parts': [
                    {'text': FinishingApiPrompt.prompt}
                  ]
                },
              ],
              'generationConfig': {'temperature': 0.2},
            });
            final finResp = await http
                .post(_aiUri!,
                    headers: {'Content-Type': 'application/json'},
                    body: finReqBody)
                .timeout(const Duration(seconds: 240));
            if (finResp.statusCode >= 200 && finResp.statusCode < 300) {
              final finHtmlRaw =
                  (((json.decode(finResp.body)['candidates'] as List?)
                              ?.firstOrNull?['content']?['parts'] as List?)
                          ?.firstOrNull?['text'] as String?) ??
                      '';
              if (finHtmlRaw.trim().isNotEmpty) {
                await api.setThreeJsCategory(widget.projectId, 'finishing',
                    _stripHtmlFences(finHtmlRaw));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('3D generation error (non-fatal): $e');
      }
    }();
  }

  String _stripHtmlFences(String raw) {
    final trimmed = raw.trim();
    final fenceMatch =
        RegExp(r'```(?:html)?\s*([\s\S]*?)```').firstMatch(trimmed);
    if (fenceMatch != null) return fenceMatch.group(1)!.trim();
    final idxDoctype = trimmed.toLowerCase().indexOf('<!doctype');
    if (idxDoctype != -1) return trimmed.substring(idxDoctype);
    final idxHtml = trimmed.toLowerCase().indexOf('<html');
    if (idxHtml != -1) return trimmed.substring(idxHtml);
    return trimmed;
  }

  String _stripMarkdownJson(String raw) {
    final trimmed = raw.trim();
    final fenceMatch =
        RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(trimmed);
    if (fenceMatch != null) return fenceMatch.group(1)!.trim();
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return trimmed.substring(start, end + 1);
    }
    return trimmed;
  }

  List<Uint8List> _selectAiImages(List<Uint8List> images) {
    if (images.length <= _maxAiImages) return List<Uint8List>.from(images);

    final selected = <Uint8List>[];
    for (int i = 0; i < _maxAiImages; i++) {
      final index = (i * (images.length - 1) / (_maxAiImages - 1)).round();
      selected.add(images[index]);
    }
    return selected;
  }

  Uint8List _optimizeAiImage(Uint8List originalBytes) {
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) return originalBytes;

    img.Image optimized = decoded;
    if (decoded.width > _maxAiImageWidth) {
      optimized = img.copyResize(decoded, width: _maxAiImageWidth);
    }

    return Uint8List.fromList(
      img.encodeJpg(optimized, quality: _aiJpegQuality),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Loading View Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Widget _buildLoadingView() {
    const stepLabels = [
      'Upload Images',
      'Ground Floor Analysis',
      'First Floor Analysis',
      'BOQ Report',
      'Object Detection',
      'Overview',
    ];
    const stepDescriptions = [
      'Select building plan images',
      'Saving ground floor measurements',
      'Saving first floor measurements',
      'Preparing BOQ report from saved measurements',
      'Detecting walls, doors and windows on floor plans',
      'Opening project overview',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PipelineProgress(currentStep: _pipelineStep),
          const SizedBox(height: 32),
          ...List.generate(stepLabels.length, (i) {
            final isDone = i <= _pipelineStep;
            final isActive = i == _pipelineStep + 1;
            final isPending = i > _pipelineStep + 1;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: isDone
                        ? const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF2E7D32), size: 28)
                        : isActive
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: Padding(
                                  padding: EdgeInsets.all(3),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : Icon(Icons.radio_button_unchecked,
                                color: Colors.grey.shade300, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stepLabels[i],
                          style: TextStyle(
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal,
                            fontSize: 15,
                            color: isDone
                                ? const Color(0xFF2E7D32)
                                : isActive
                                    ? AppColors.primary
                                    : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (isActive && _status.isNotEmpty)
                          Text(
                            _status,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.primary),
                          )
                        else if (!isPending)
                          Text(
                            stepDescriptions[i],
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                      ],
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

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Build Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  @override
  Widget build(BuildContext context) {
    if (_loading || _pipelineRunning)
      return Scaffold(appBar: _buildAppBar(), body: _buildLoadingView());

    return Scaffold(
      appBar: _buildAppBar(),
      body: switch (_pipelineStep) {
        0 => _buildUploadView(),
        1 => _buildContourResultView(),
        2 => _buildAnalysisResultView(
            step: 2,
            label: 'Walling Measurements',
            icon: Icons.crop_square_outlined,
            color: const Color(0xFF6A1B9A),
            result: _wallingResult,
            nextLabel: 'Continue - Structural Frame',
            onNext: _callStructuralFrame,
          ),
        3 => _buildAnalysisResultView(
            step: 3,
            label: 'Structural Frame',
            icon: Icons.account_tree_outlined,
            color: const Color(0xFF1565C0),
            result: _sfResult,
            nextLabel: 'Save & Complete',
            onNext: _saveAndComplete,
          ),
        4 => _buildSuccessView(),
        _ => _buildUploadView(),
      },
    );
  }

  AppBar _buildAppBar() => AppBar(
        title: const Text('Upload Building Plans'),
        backgroundColor: AppColors.primary,
      );

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Step 0 Ã¢â‚¬â€ Upload View Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Widget _buildUploadView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PipelineProgress(currentStep: 0),
          const SizedBox(height: 16),
          Card(
            color: AppColors.primary.withAlpha(20),
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upload the building plan images.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Select Images'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          if (_images.isNotEmpty) ...[
            Text(
              '${_images.length} image(s) selected',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) => _ImageThumb(
                  file: _images[i],
                  onRemove: () => _removeImage(i),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Spacer(),
          if (_pixelCoordinatePick != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gemini result (pixel coordinates)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ground sheet: ${_pixelCoordinatePick?['ground_sheet_id'] ?? '-'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _nextToManualMarking,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text(
                        'Next - Manual Marking',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_groundFloorPick != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gemini result (prompt-1)',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      'Selected index: ${_groundFloorPick?['ground_index'] ?? '-'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      'Confidence: ${_groundFloorPick?['confidence'] ?? '-'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_groundFloorPick?['reason'] ?? ''}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _runPixelPromptAndShowNext,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text(
                        'Next - Run Prompt 2',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_images.isNotEmpty)
            ElevatedButton.icon(
              onPressed: _runHardcodedAnalysisFlow,
              icon: const Icon(Icons.auto_awesome),
              label: const Text(
                'Start',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProjectsScreen()),
            ),
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Step 1 Ã¢â‚¬â€ Contour Result View Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Widget _buildContourResultView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PipelineProgress(currentStep: 1),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF2E7D32),
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Contour Detection Complete',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_contourResultBytes.length} image(s) processed successfully.\nReady to extract measurements with AI.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _sendToAi,
            icon: const Icon(Icons.auto_awesome),
            label: const Text(
              'Send to AI - Extract Measurements',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Step 3 Ã¢â‚¬â€ AI Walling Result View Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Widget _buildAnalysisResultView({
    required int step,
    required String label,
    required IconData icon,
    required Color color,
    required Map<String, dynamic>? result,
    required String nextLabel,
    required VoidCallback onNext,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PipelineProgress(currentStep: step),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF2E7D32),
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$label Extracted',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'AI has successfully extracted the data.\nReady to proceed to the next step.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: ElevatedButton.icon(
            onPressed: onNext,
            icon: Icon(step < 4 ? Icons.arrow_forward : Icons.save_outlined),
            label: Text(
              nextLabel,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Step 4 Ã¢â‚¬â€ Success View Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF2E7D32),
                size: 80,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Successfully extracted all data',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Walling, structural frame, finishing data and building structure have been saved to your project.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ProjectsScreen()),
              ),
              icon: const Icon(Icons.folder_open),
              label: const Text(
                'Go to Projects',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Pipeline Progress Indicator Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class _PipelineProgress extends StatelessWidget {
  final int currentStep; // 0â€“6

  const _PipelineProgress({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const steps = ['Upload', 'Ground', 'First', 'BOQ', 'Detect', 'Overview'];
    const colors = [
      AppColors.primary,
      Color(0xFF2E7D32),
      Color(0xFF6A1B9A),
      Color(0xFF1565C0),
      Color(0xFF00838F),
      Color(0xFF2E7D32),
    ];

    return Row(
      children: List.generate(steps.length, (i) {
        final active = i <= currentStep;
        final color = active ? colors[i] : Colors.grey.shade300;
        return Expanded(
          child: Column(
            children: [
              Container(
                height: 6,
                margin: EdgeInsets.only(right: i < steps.length - 1 ? 4 : 0),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[i],
                style: TextStyle(
                  fontSize: 10,
                  color: active ? colors[i] : Colors.grey,
                  fontWeight:
                      i == currentStep ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ CV Result Card Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class _CVResultCard extends StatelessWidget {
  final String label;
  final Uint8List imageBytes;
  final Color color;

  const _CVResultCard({
    required this.label,
    required this.imageBytes,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              label,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: color, fontSize: 13),
            ),
          ),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(10)),
            child: Image.memory(
              imageBytes,
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
          ),
        ],
      ),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Thumbnail widget Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class _ImageThumb extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;

  const _ImageThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: kIsWeb
              ? Image.network(file.path,
                  width: 100, height: 100, fit: BoxFit.cover)
              : Image.file(File(file.path),
                  width: 100, height: 100, fit: BoxFit.cover),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
