import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ManualMarkingWebViewScreen extends StatefulWidget {
  final Uri url;
  final bool Function(String url) isDoneUrl;

  const ManualMarkingWebViewScreen({
    super.key,
    required this.url,
    required this.isDoneUrl,
  });

  @override
  State<ManualMarkingWebViewScreen> createState() => _ManualMarkingWebViewScreenState();
}

class _ManualMarkingWebViewScreenState extends State<ManualMarkingWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (req) {
            if (widget.isDoneUrl(req.url)) {
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Marking'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
