import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boq_frontend/features/it22172532/providers/project_provider.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import 'create_project_screen.dart';
import '../../components/project_tabs/project_overview_tab.dart';
import '../../components/project_tabs/materials_tab.dart';
import '../../components/project_tabs/workers_tab.dart';
import '../../components/project_tabs/boq_tab.dart';
import '../../components/project_tabs/purchasing_tab.dart';
import '../../components/project_tabs/progress_tab.dart';
import '../../components/project_tabs/safety_tab.dart';
import '../cost_estimate/total_cost_estimate_screen.dart';
import '../three_d_floor_plan/floor_plan_3d_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int initialTab;
  const ProjectDetailScreen({super.key, this.initialTab = 0});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _materialRoomLabel;
  Map<String, dynamic>? _materialRoomData;

  final _tabItems = const [
    _TabItem(Icons.dashboard_outlined, 'Overview'),
    _TabItem(Icons.inventory_2_outlined, 'Materials'),
    _TabItem(Icons.calculate, 'Cost Estimate'),
    _TabItem(Icons.people_outline, 'Workers'),
    _TabItem(Icons.format_list_numbered, 'BOQ'),
    _TabItem(Icons.shopping_cart_outlined, 'Purchasing'),
    _TabItem(Icons.bar_chart_outlined, 'Progress'),
    _TabItem(Icons.health_and_safety_outlined, 'Safety'),
    _TabItem(Icons.view_in_ar_outlined, '3D Floor Plan'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: _tabItems.length,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, _tabItems.length - 1),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProjectProvider>();
    final project = pp.currentProject;
    final name = project?.projectName ?? 'Project';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Project',
            onPressed: project == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              CreateProjectScreen(existing: project)),
                    ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabAlignment: TabAlignment.start,
          tabs: _tabItems
              .map((t) => Tab(
                    icon: Icon(t.icon, size: 18, color: Colors.white),
                    text: t.label,
                    iconMargin: const EdgeInsets.only(bottom: 2),
                  ))
              .toList(),
        ),
      ),
      body: pp.loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                OverviewTab(
                  onNavigateToTab: (index,
                      {String? roomLabel, Map<String, dynamic>? roomData}) {
                    if (index == 1) {
                      setState(() {
                        _materialRoomLabel = roomLabel;
                        _materialRoomData = roomData;
                      });
                    }
                    _tabs.animateTo(index);
                  },
                ),
                MaterialsTab(
                  roomLabel: _materialRoomLabel,
                  roomData: _materialRoomData,
                ),
                const TotalCostEstimateScreen(),
                const WorkersTab(),
                const BOQTab(),
                const PurchasingTab(),
                const ProgressTab(),
                const SafetyTab(),
                const FloorPlan3DScreen(),
              ],
            ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem(this.icon, this.label);
}
