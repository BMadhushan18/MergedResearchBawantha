import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../config/app_config.dart';

class FloorPlan3DScreen extends StatefulWidget {
  final String? projectId;
  const FloorPlan3DScreen({super.key, this.projectId});

  @override
  State<FloorPlan3DScreen> createState() => _FloorPlan3DScreenState();
}

class _FloorPlan3DScreenState extends State<FloorPlan3DScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    final pid = widget.projectId;
    final path = pid != null && pid.isNotEmpty
        ? '/3d-floor-plan/viewer?project_id=${Uri.encodeComponent(pid)}'
        : '/3d-floor-plan/viewer';
    final uri = Uri.parse('${AppConfig.baseUrl}$path');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _hasError = true);
          },
        ),
      )
      ..loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('3D Floor Plan'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loading = true;
                _hasError = false;
              });
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_hasError) WebViewWidget(controller: _controller),
          if (_hasError)
            _ErrorView(onRetry: () {
              setState(() {
                _loading = true;
                _hasError = false;
              });
              _controller.reload();
            }),
          if (_loading && !_hasError)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Loading 3D viewer…',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: Colors.white54, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Could not connect to backend.\nMake sure the server is running.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
