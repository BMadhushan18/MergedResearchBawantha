import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:boq_frontend/features/it22172532/providers/project_provider.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';

class View3DScreen extends StatefulWidget {
  const View3DScreen({super.key});

  @override
  State<View3DScreen> createState() => _View3DScreenState();
}

class _View3DScreenState extends State<View3DScreen> {
  // 'foundation' | 'finishing' | null
  String? _selectedCategory;
  WebViewController? _webController;
  bool _webViewReady = false;

  @override
  void initState() {
    super.initState();
    // Clear stale cache when the screen opens with a fresh project
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectProvider>().clearThreeJsCache();
    });
  }

  Future<void> _loadCategory(String category) async {
    final provider = context.read<ProjectProvider>();
    if (provider.currentProject == null) {
      _showSnack('No project selected. Please select a project on the Home screen.');
      return;
    }

    setState(() {
      _selectedCategory = category;
      _webViewReady = false;
    });

    final html = await provider.fetchThreeJsCategory(category);

    if (!mounted) return;

    if (html == null || html.trim().isEmpty) {
      _showSnack('No 3D data available for ${_label(category)} yet.');
      setState(() => _selectedCategory = null);
      return;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _webViewReady = true);
        },
      ))
      ..loadHtmlString(html);

    setState(() => _webController = controller);
  }

  String _label(String category) =>
      category == 'foundation' ? 'Foundation' : 'Finishing';

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (context, provider, _) {
        final project = provider.currentProject;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              project != null ? '3D View â€” ${project.projectName ?? project.projectId}' : '3D View',
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (_selectedCategory != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Back to selection',
                  onPressed: () => setState(() {
                    _selectedCategory = null;
                    _webController = null;
                    _webViewReady = false;
                  }),
                ),
            ],
          ),
          body: project == null
              ? _buildNoProject()
              : _selectedCategory == null
                  ? _buildCategorySelector(provider)
                  : _buildWebView(provider),
        );
      },
    );
  }

  Widget _buildNoProject() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_in_ar_rounded, size: 72, color: AppColors.primary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              'No project selected',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Go to the Home screen and select a project first.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(ProjectProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select a 3D View',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose which stage of the building to visualise',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          _CategoryCard(
            icon: Icons.foundation_rounded,
            label: 'Foundation',
            description: 'Ground-floor layout, boundary walls & openings',
            color: AppColors.primary,
            loading: provider.threejsLoading && _selectedCategory == 'foundation',
            onTap: provider.threejsLoading ? null : () => _loadCategory('foundation'),
          ),
          const SizedBox(height: 20),
          _CategoryCard(
            icon: Icons.home_work_rounded,
            label: 'Finishing',
            description: 'Final interior layout with finishes applied',
            color: Colors.teal,
            loading: false,
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _buildWebView(ProjectProvider provider) {
    if (_webController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        WebViewWidget(controller: _webController!),
        if (!_webViewReady)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

// â”€â”€â”€ Category Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: color),
                      )
                    : Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
