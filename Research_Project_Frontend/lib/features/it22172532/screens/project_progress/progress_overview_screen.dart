import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boq_frontend/features/it22172532/providers/project_provider.dart';
import 'package:boq_frontend/features/it22172532/models/project/project_model.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import '../projects/project_detail_screen.dart';

class ProgressOverviewScreen extends StatefulWidget {
  const ProgressOverviewScreen({super.key});

  @override
  State<ProgressOverviewScreen> createState() =>
      _ProgressOverviewScreenState();
}

class _ProgressOverviewScreenState extends State<ProgressOverviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectProvider>().listenProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProjectProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Project Progress',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: pp.loading
          ? const Center(child: CircularProgressIndicator())
          : pp.projects.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  onRefresh: () async => pp.listenProjects(),
                  child: Column(
                    children: [
                      // â”€â”€ Summary banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                      _SummaryBanner(projects: pp.projects),
                      // â”€â”€ Project list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: pp.projects.length,
                          itemBuilder: (_, i) => _ProgressCard(
                            project: pp.projects[i],
                            onTap: () async {
                              await context
                                  .read<ProjectProvider>()
                                  .selectProject(pp.projects[i].projectId);
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ProjectDetailScreen()),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// â”€â”€ Summary banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _SummaryBanner extends StatelessWidget {
  final List<ProjectModel> projects;
  const _SummaryBanner({required this.projects});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatItem(
            label: 'Total',
            value: '${projects.length}',
            icon: Icons.folder_copy_outlined,
          ),
          _Divider(),
          _StatItem(
            label: 'With Client',
            value: '${projects.where((p) => (p.client ?? '').isNotEmpty).length}',
            icon: Icons.people_outline_rounded,
          ),
          _Divider(),
          _StatItem(
            label: 'Locations',
            value:
                '${projects.map((p) => p.location).where((l) => l != null && l.isNotEmpty).toSet().length}',
            icon: Icons.location_on_outlined,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatItem(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 40,
        color: Colors.white30,
      );
}

// â”€â”€ Progress card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ProgressCard extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback onTap;
  const _ProgressCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Use a dummy progress value for display if no real value available
    final double progress = 0.0;
    final pct = (progress * 100).toInt();
    final date = project.createdDate != null
        ? '${project.createdDate!.day}/${project.createdDate!.month}/${project.createdDate!.year}'
        : 'â€”';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1.5,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.business_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.projectName ?? project.projectId,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 12,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              project.location ?? 'â€”',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Created $date',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint)),
                  Text('Tap to view details',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Empty state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No Progress Yet',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Create a project to track progress here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
