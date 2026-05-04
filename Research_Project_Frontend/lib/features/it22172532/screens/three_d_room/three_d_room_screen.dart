import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ThreeDRoomScreen extends StatefulWidget {
  const ThreeDRoomScreen({super.key});

  @override
  State<ThreeDRoomScreen> createState() => _ThreeDRoomScreenState();
}

class _ThreeDRoomScreenState extends State<ThreeDRoomScreen> {
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
        ),
      );
    _loadViewer();
  }

  Future<void> _loadViewer() async {
    if (mounted) setState(() => _loading = true);
    final source = await rootBundle.loadString('assets/html/UpdatedThreeRoom');
    final html = _buildReactViewerHtml(source);
    await _controller.loadHtmlString(html);
  }

  String _buildReactViewerHtml(String source) {
    var code = source;
    final appStart = code.indexOf('const FT = 0.3048;');
    if (appStart >= 0) {
      code =
          'const { useMemo, useState, useCallback, useRef, memo, useEffect, createContext, useContext, Suspense } = React;\n'
          '${code.substring(appStart)}';
    }
    code = code.replaceFirst('export default function App()', 'function App()');

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Updated 3D Room</title>
  <style>
    html, body, #root {
      width: 100%;
      height: 100%;
      margin: 0;
      overflow: hidden;
      background: #080f18;
    }
    * { box-sizing: border-box; }
  </style>
  <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
  <script type="importmap">
  {
    "imports": {
      "three": "https://esm.sh/three@0.160.0",
      "react": "https://esm.sh/react@18.2.0",
      "react-dom": "https://esm.sh/react-dom@18.2.0",
      "react-dom/client": "https://esm.sh/react-dom@18.2.0/client",
      "@react-three/fiber": "https://esm.sh/@react-three/fiber@8.15.16?external=react,react-dom,three",
      "@react-three/drei": "https://esm.sh/@react-three/drei@9.96.1?external=react,react-dom,three,@react-three/fiber"
    }
  }
  </script>
</head>
<body>
  <div id="root"></div>
  <script type="text/babel" data-type="module" data-presets="react">
    import React from "react";
    import { createRoot } from "react-dom/client";
    import * as THREE from "three";
    import { Canvas, useFrame } from "@react-three/fiber";
    import { OrbitControls, Grid, Edges, Text } from "@react-three/drei";

$code

    createRoot(document.getElementById("root")).render(<App />);
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('3D Room'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: _loadViewer,
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
