import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boq_frontend/features/it22172532/providers/ai_provider.dart';
import 'package:boq_frontend/features/it22172532/providers/hf_provider.dart';
import 'package:boq_frontend/features/it22172532/providers/openai_provider.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedProvider = 'AI';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AiProvider>(context, listen: false).loadKey();
      Provider.of<HfProvider>(context, listen: false).loadKey();
      Provider.of<OpenAIProvider>(context, listen: false).loadKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: AppColors.background, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AI Provider', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedProvider,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'AI', child: Text('AI')),
              DropdownMenuItem(value: 'HuggingFace', child: Text('HuggingFace')),
              DropdownMenuItem(value: 'OpenAI', child: Text('OpenAI')),
            ],
            onChanged: (v) { if (v != null) setState(() => _selectedProvider = v); },
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildPanel()),
        ]),
      ),
    );
  }

  Widget _buildPanel() {
    switch (_selectedProvider) {
      case 'HuggingFace': return const _HfPanel();
      case 'OpenAI':      return const _OpenAiPanel();
      case 'AI':
      default:            return const _AiPanel();
    }
  }
}

// ─── AI Panel ─────────────────────────────────────────────────────────────

class _AiPanel extends StatefulWidget {
  const _AiPanel();
  @override
  State<_AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends State<_AiPanel> {
  late final TextEditingController _keyCtrl;
  late final TextEditingController _modelCtrl;
  static const _defaultModel = 'gemini-2.0-flash';

  @override
  void initState() {
    super.initState();
    final prov = Provider.of<AiProvider>(context, listen: false);
    _keyCtrl   = TextEditingController(text: prov.apiKey ?? '');
    _modelCtrl = TextEditingController(text: prov.savedModel ?? _defaultModel);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiProvider>(builder: (context, prov, _) {
      return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AI API Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(controller: _keyCtrl, obscureText: true,
              decoration: InputDecoration(hintText: 'AI API key', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: prov.loading ? null : () async {
                await prov.saveKey(_keyCtrl.text.trim());
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI key saved')));
              },
              child: const Text('Save Key'),
            )),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: prov.loading ? null : () async {
                await prov.clearKey();
                _keyCtrl.clear();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI key cleared')));
              },
              child: const Text('Clear'),
            ),
          ]),
          const SizedBox(height: 20),
          const Text('Model', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(controller: _modelCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. gemini-2.0-flash',
                helperText: prov.savedModel != null ? 'Saved: ${prov.savedModel}' : 'Not saved yet',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              )),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save Model'),
              onPressed: () async {
                final v = _modelCtrl.text.trim();
                if (v.isEmpty) return;
                await prov.saveModelName(v);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Model saved: $v')));
              },
            )),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () async {
                await prov.clearModelName();
                _modelCtrl.text = _defaultModel;
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Model reset to default')));
              },
              child: const Text('Reset'),
            ),
          ]),
          const SizedBox(height: 20),
          const Text('Test AI Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TestPromptWidget(onTest: (prompt) => prov.testPrompt(prompt, model: _modelCtrl.text.trim())),
          const SizedBox(height: 16),
          const Text('Note: This key will be used by app features that integrate with AI.', style: TextStyle(color: AppColors.textSecondary)),
        ]),
      );
    });
  }
}

// ─── HuggingFace Panel ────────────────────────────────────────────────────────

class _HfPanel extends StatefulWidget {
  const _HfPanel();
  @override
  State<_HfPanel> createState() => _HfPanelState();
}

class _HfPanelState extends State<_HfPanel> {
  late final TextEditingController _keyCtrl;
  late final TextEditingController _modelCtrl;
  static const _defaultModel = 'meta-llama/Llama-4-Scout-17B-16E-Instruct:groq';

  @override
  void initState() {
    super.initState();
    final prov = Provider.of<HfProvider>(context, listen: false);
    _keyCtrl   = TextEditingController(text: prov.apiKey ?? '');
    _modelCtrl = TextEditingController(text: prov.savedModel ?? _defaultModel);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HfProvider>(builder: (context, prov, _) {
      return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('HuggingFace API Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(controller: _keyCtrl, obscureText: true,
              decoration: InputDecoration(hintText: 'HuggingFace API key', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: prov.loading ? null : () async {
                await prov.saveKey(_keyCtrl.text.trim());
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('HuggingFace key saved')));
              },
              child: const Text('Save Key'),
            )),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: prov.loading ? null : () async {
                await prov.clearKey();
                _keyCtrl.clear();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('HuggingFace key cleared')));
              },
              child: const Text('Clear'),
            ),
          ]),
          const SizedBox(height: 20),
          const Text('Model', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(controller: _modelCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. meta-llama/Llama-4-Scout-17B-16E-Instruct:groq',
                helperText: prov.savedModel != null ? 'Saved: ${prov.savedModel}' : 'Not saved yet',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              )),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save Model'),
              onPressed: () async {
                final v = _modelCtrl.text.trim();
                if (v.isEmpty) return;
                await prov.saveModelName(v);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Model saved: $v')));
              },
            )),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () async {
                await prov.clearModelName();
                _modelCtrl.text = _defaultModel;
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Model reset to default')));
              },
              child: const Text('Reset'),
            ),
          ]),
          const SizedBox(height: 20),
          const Text('Test HuggingFace Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TestPromptWidget(onTest: (prompt) => prov.testPrompt(prompt, model: _modelCtrl.text.trim())),
          const SizedBox(height: 16),
          const Text('Note: This key will be used by features that integrate with HuggingFace.', style: TextStyle(color: AppColors.textSecondary)),
        ]),
      );
    });
  }
}

// ─── OpenAI Panel ─────────────────────────────────────────────────────────────

class _OpenAiPanel extends StatefulWidget {
  const _OpenAiPanel();
  @override
  State<_OpenAiPanel> createState() => _OpenAiPanelState();
}

class _OpenAiPanelState extends State<_OpenAiPanel> {
  late final TextEditingController _keyCtrl;
  late final TextEditingController _modelCtrl;
  static const _defaultModel = 'gpt-5.2';

  @override
  void initState() {
    super.initState();
    final prov = Provider.of<OpenAIProvider>(context, listen: false);
    _keyCtrl   = TextEditingController(text: prov.apiKey ?? '');
    _modelCtrl = TextEditingController(text: prov.savedModel ?? _defaultModel);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OpenAIProvider>(builder: (context, prov, _) {
      return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('OpenAI API Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(controller: _keyCtrl, obscureText: true,
              decoration: InputDecoration(hintText: 'OpenAI API key', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: prov.loading ? null : () async {
                await prov.saveKey(_keyCtrl.text.trim());
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OpenAI key saved')));
              },
              child: const Text('Save Key'),
            )),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: prov.loading ? null : () async {
                await prov.clearKey();
                _keyCtrl.clear();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OpenAI key cleared')));
              },
              child: const Text('Clear'),
            ),
          ]),
          const SizedBox(height: 20),
          const Text('Model', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(controller: _modelCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. gpt-5.2',
                helperText: prov.savedModel != null ? 'Saved: ${prov.savedModel}' : 'Not saved yet',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              )),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save Model'),
              onPressed: () async {
                final v = _modelCtrl.text.trim();
                if (v.isEmpty) return;
                await prov.saveModelName(v);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Model saved: $v')));
              },
            )),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () async {
                await prov.clearModelName();
                _modelCtrl.text = _defaultModel;
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Model reset to default')));
              },
              child: const Text('Reset'),
            ),
          ]),
          const SizedBox(height: 20),
          const Text('Test OpenAI Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TestPromptWidget(onTest: (prompt) => prov.testPrompt(prompt, model: _modelCtrl.text.trim())),
          const SizedBox(height: 16),
          const Text('Note: This key will be used by features that integrate with OpenAI.', style: TextStyle(color: AppColors.textSecondary)),
        ]),
      );
    });
  }
}

// ─── Shared test widget ───────────────────────────────────────────────────────

class TestPromptWidget extends StatefulWidget {
  final Future<String> Function(String prompt) onTest;
  const TestPromptWidget({required this.onTest, super.key});

  @override
  State<TestPromptWidget> createState() => _TestPromptWidgetState();
}

class _TestPromptWidgetState extends State<TestPromptWidget> {
  final TextEditingController _promptCtrl = TextEditingController(text: 'hi');
  String _result = '';
  bool _loading = false;

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (!mounted) return;
    setState(() { _loading = true; _result = ''; });
    try {
      final out = await widget.onTest(_promptCtrl.text.trim());
      if (!mounted) return;
      setState(() => _result = out);
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: _promptCtrl,
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          minLines: 1, maxLines: 3),
      const SizedBox(height: 8),
      Row(children: [
        ElevatedButton(onPressed: _loading ? null : _run, child: const Text('Run Test')),
        const SizedBox(width: 8),
        if (_loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
      const SizedBox(height: 8),
      const Text('Response:', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
        child: SelectableText(_result.isEmpty ? '(no response yet)' : _result),
      ),
    ]);
  }
}
