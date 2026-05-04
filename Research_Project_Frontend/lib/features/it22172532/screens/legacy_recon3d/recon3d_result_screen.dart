import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'recon3d_job_model.dart';
import 'recon3d_api_service.dart';
import 'recon3d_home_screen.dart';

class Recon3DResultScreen extends StatefulWidget {
  final String jobId;
  final Recon3DJobStatus? initialStatus;

  const Recon3DResultScreen({
    super.key,
    required this.jobId,
    this.initialStatus,
  });

  @override
  State<Recon3DResultScreen> createState() => _Recon3DResultScreenState();
}

class _Recon3DResultScreenState extends State<Recon3DResultScreen> {
  final _api = Recon3DApiService();
  late final WebViewController _webCtrl;
  Recon3DJobStatus? _status;

  bool _webLoading = true;
  bool _downloading = false;
  bool _statusLoading = true;
  bool _showHelp = true;
  double _orbitYaw = 0;
  double _orbitPitch = 75;

  bool get _isGlbReady =>
      _status?.artifactType == 'glb' &&
      (_status?.modelUrl.isNotEmpty ?? false);

  String get _resolvedModelUrl =>
      _api.resolveUrl(_status?.modelUrl ?? '');
  String get _cameraOrbit =>
      '${_orbitYaw.toStringAsFixed(0)}deg ${_orbitPitch.toStringAsFixed(0)}deg auto';

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _webCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _webLoading = false),
        onWebResourceError: (e) =>
            debugPrint('WebView error: ${e.description}'),
      ));

    if (_status != null) {
      _statusLoading = false;
      if (_isGlbReady) {
        _webLoading = false;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadViewer());
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatus());
    }
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _api.getStatus(widget.jobId);
      if (!mounted) return;
      setState(() {
        _status = status;
        _statusLoading = false;
      });
      if (_isGlbReady) {
        setState(() => _webLoading = false);
      } else {
        _loadViewer();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load reconstruction details: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _loadViewer() {
    if (_isGlbReady) {
      setState(() => _webLoading = false);
      return;
    }
    final viewerPath = _status?.viewerUrl.isNotEmpty == true
        ? _status!.viewerUrl
        : '/viewer/${widget.jobId}';
    _webCtrl.loadRequest(Uri.parse(_api.resolveUrl(viewerPath)));
  }

  Future<void> _runViewerCommand(String command) async {
    if (_isGlbReady) return;
    await _webCtrl
        .runJavaScript('window.viewerControls?.$command?.();');
  }

  void _adjustGlbOrbit({double yaw = 0, double pitch = 0}) {
    setState(() {
      _orbitYaw = (_orbitYaw + yaw) % 360;
      _orbitPitch = (_orbitPitch + pitch).clamp(20, 110);
    });
  }

  void _resetView() {
    if (_isGlbReady) {
      setState(() {
        _orbitYaw = 0;
        _orbitPitch = 75;
      });
      return;
    }
    _runViewerCommand('reset');
  }

  Future<void> _downloadPly() async {
    setState(() => _downloading = true);
    try {
      final dir = await getTemporaryDirectory();
      final extension =
          _status?.artifactType == 'glb' ? 'glb' : 'ply';
      final url = _status?.downloadUrl.isNotEmpty == true
          ? _status!.downloadUrl
          : '/result/${widget.jobId}';
      final savePath =
          '${dir.path}/reconstruction_${widget.jobId.substring(0, 8)}.$extension';

      await _api.downloadResult(url, savePath);

      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(savePath)],
            subject: '3D Reconstruction (.$extension)',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _deleteAndGoHome() async {
    await _api.deleteJob(widget.jobId).catchError((_) {});
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => const Recon3DHomeScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        title: const Text('3D Model Viewer',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Show movement help',
            icon: Icon(_showHelp
                ? Icons.help_rounded
                : Icons.help_outline_rounded),
            onPressed: () =>
                setState(() => _showHelp = !_showHelp),
          ),
          IconButton(
            tooltip: 'Download model',
            icon: _downloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.download_rounded),
            onPressed: _downloading ? null : _downloadPly,
          ),
          IconButton(
            tooltip: 'New reconstruction',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _deleteAndGoHome,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isGlbReady)
            Container(
              color: const Color(0xFF0F0F1A),
              child: ModelViewer(
                key: ValueKey('$_resolvedModelUrl|$_cameraOrbit'),
                src: _resolvedModelUrl,
                alt: '3D reconstruction model',
                ar: false,
                autoRotate: true,
                autoRotateDelay: 0,
                cameraControls: true,
                interactionPrompt: InteractionPrompt.auto,
                interactionPromptStyle:
                    InteractionPromptStyle.wiggle,
                cameraOrbit: _cameraOrbit,
                minCameraOrbit: 'auto 20deg auto',
                maxCameraOrbit: 'auto 110deg auto',
                disableZoom: false,
                backgroundColor: const Color(0xFF0F0F1A),
              ),
            )
          else
            WebViewWidget(controller: _webCtrl),

          if (_showHelp && !_statusLoading)
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: _buildHelpCard(),
            ),

          if (!_statusLoading && !_webLoading)
            Positioned(
              right: 14,
              bottom: 18,
              child: _buildControlPad(),
            ),

          if (_webLoading || _statusLoading)
            Container(
              color: const Color(0xFF0F0F1A),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation(
                                Color(0xFF5C9EFF))),
                    SizedBox(height: 16),
                    Text('Loading 3D viewer…',
                        style:
                            TextStyle(color: Color(0xFF8899BB))),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 14),
        color: const Color(0xFF12172A),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF22C55E), size: 20),
            const SizedBox(width: 8),
            Text(
              _status?.artifactType == 'glb'
                  ? 'Reconstruction complete · GLB ready'
                  : 'Reconstruction complete · PLY ready',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _downloadPly,
              icon: const Icon(Icons.save_alt_rounded, size: 18),
              label: Text(_status?.artifactType == 'glb'
                  ? 'Save .glb'
                  : 'Save .ply'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF5C9EFF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCard() {
    final viewerLabel = _isGlbReady ? 'GLB viewer' : 'PLY viewer';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC12172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3A5C)),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_rounded,
              color: Color(0xFF5C9EFF)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$viewerLabel: drag with one finger to rotate, use two fingers to move, pinch to zoom.',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12.5),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                setState(() => _showHelp = false),
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFF9FB2D1), size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPad() {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xE612172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A3A5C)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('View Control',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _controlButton(
                icon: Icons.keyboard_arrow_up_rounded,
                onTap: () => _isGlbReady
                    ? _adjustGlbOrbit(pitch: -10)
                    : _runViewerCommand('rotateUp'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _controlButton(
                icon: Icons.keyboard_arrow_left_rounded,
                onTap: () => _isGlbReady
                    ? _adjustGlbOrbit(yaw: -12)
                    : _runViewerCommand('rotateLeft'),
              ),
              const SizedBox(width: 8),
              _controlButton(
                icon: Icons.center_focus_strong_rounded,
                onTap: _resetView,
              ),
              const SizedBox(width: 8),
              _controlButton(
                icon: Icons.keyboard_arrow_right_rounded,
                onTap: () => _isGlbReady
                    ? _adjustGlbOrbit(yaw: 12)
                    : _runViewerCommand('rotateRight'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _controlButton(
                icon: Icons.keyboard_arrow_down_rounded,
                onTap: () => _isGlbReady
                    ? _adjustGlbOrbit(pitch: 10)
                    : _runViewerCommand('rotateDown'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _controlButton(
                  icon: Icons.remove_rounded,
                  onTap: () => _runViewerCommand('zoomOut')),
              const SizedBox(width: 8),
              _controlButton(
                  icon: Icons.add_rounded,
                  onTap: () => _runViewerCommand('zoomIn')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controlButton(
      {required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFF1B2842),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
