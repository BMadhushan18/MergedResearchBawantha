import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boq_frontend/features/it22172532/providers/project_provider.dart';
import 'package:boq_frontend/features/it22172532/models/project/project_model.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import 'project_detail_screen.dart';

class ProjectSearchScreen extends StatefulWidget {
  const ProjectSearchScreen({super.key});

  @override
  State<ProjectSearchScreen> createState() => _ProjectSearchScreenState();
}

class _ProjectSearchScreenState extends State<ProjectSearchScreen> {
  final _searchCtrl = TextEditingController();

  // Active filter
  String _filterBy = 'projectName'; // 'projectName' | 'location' | 'owner'
  String _query = '';

  static const _filterOptions = [
    _Filter('projectName', Icons.folder_outlined, 'Project Name'),
    _Filter('location', Icons.location_on_outlined, 'Location'),
    _Filter('owner', Icons.person_outline, 'Owner'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ProjectModel> _applyFilter(List<ProjectModel> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((p) {
      switch (_filterBy) {
        case 'location':
          return (p.location ?? '').toLowerCase().contains(q);
        case 'owner':
          return (p.client ?? '').toLowerCase().contains(q);
        default:
          return (p.projectName ?? '').toLowerCase().contains(q) ||
              (p.projectId).toLowerCase().contains(q);
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProjectProvider>();
    final results = _applyFilter(pp.projects);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Search Projects',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // â”€â”€ Search bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: _hintText(),
                  hintStyle: TextStyle(color: AppColors.textHint),
                  prefixIcon:
                      Icon(Icons.search, color: AppColors.primary),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          color: AppColors.textHint,
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
          ),

          // â”€â”€ Filter chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            color: AppColors.background,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  'Filter by:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filterOptions
                          .map((f) => _FilterChip(
                                filter: f,
                                selected: _filterBy == f.value,
                                onTap: () => setState(
                                    () => _filterBy = f.value),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // â”€â”€ Results â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Expanded(
            child: pp.loading
                ? const Center(child: CircularProgressIndicator())
                : results.isEmpty
                    ? _EmptyResults(query: _query)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: results.length,
                        itemBuilder: (_, i) => _ResultCard(
                          project: results[i],
                          filterBy: _filterBy,
                          query: _query,
                          onTap: () async {
                            await context
                                .read<ProjectProvider>()
                                .selectProject(results[i].projectId);
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
    );
  }

  String _hintText() {
    switch (_filterBy) {
      case 'location':
        return 'Search by locationâ€¦';
      case 'owner':
        return 'Search by owner nameâ€¦';
      default:
        return 'Search by project nameâ€¦';
    }
  }
}

// â”€â”€ Filter chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _Filter {
  final String value;
  final IconData icon;
  final String label;
  const _Filter(this.value, this.icon, this.label);
}

class _FilterChip extends StatelessWidget {
  final _Filter filter;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.filter, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(filter.icon,
                size: 14,
                color: selected ? Colors.white : AppColors.primary),
            const SizedBox(width: 5),
            Text(
              filter.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Result card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ResultCard extends StatelessWidget {
  final ProjectModel project;
  final String filterBy;
  final String query;
  final VoidCallback onTap;
  const _ResultCard(
      {required this.project,
      required this.filterBy,
      required this.query,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = project.createdDate != null
        ? '${project.createdDate!.day}/${project.createdDate!.month}/${project.createdDate!.year}'
        : 'â€”';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.construction,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.projectName ?? project.projectId,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
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
                        const SizedBox(width: 10),
                        Icon(Icons.calendar_today_outlined,
                            size: 12,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          date,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Empty results â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _EmptyResults extends StatelessWidget {
  final String query;
  const _EmptyResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              query.isEmpty ? 'Start Typing to Search' : 'No Results Found',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              query.isEmpty
                  ? 'Enter a project name, location or owner.'
                  : 'Try a different keyword or filter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
