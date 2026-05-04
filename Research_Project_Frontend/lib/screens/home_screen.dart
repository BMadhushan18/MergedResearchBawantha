import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/widgets/bottom_nav_bar.dart';

//  Feature Screens (Root Project)
import '../features/it22150998/presentation/screens/material_wood_quality_screen.dart';
import '../features/it22196460/screens/home_screen.dart' as logistics;
import '../features/it22196460/services/api_service.dart' as logistics_api;
import '../features/it22196460/services/hive_service.dart' as logistics_hive;
import '../features/it22172532/models/project/project_model.dart';
import '../features/it22172532/providers/project_provider.dart';
import '../features/it22172532/screens/projects/create_project_flow.dart'
    as it22172532_projects;
import '../features/it22172532/screens/projects/project_detail_screen.dart';
import '../features/auth/screens/profile_screen.dart';
import '../features/it22172532/components/quick_actions/project_hub_quick_actions.dart';
import '../features/it22172532/screens/plan_analysis/upload_building_plan_screen.dart';
import '../features/it22172532/screens/time_estimation/phase_wise_duration_screen.dart';
import '../features/it22172532/screens/project_progress/track_progress_screen.dart';
import '../features/it22172532/screens/cost_estimate/total_cost_estimate_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    // Auto-fetch projects when Home Page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectProvider>().listenProjects();
    });
  }

  final List<Widget> _screens = const [
    _HomeContent(),
    Center(child: Text('Search')),
    Center(child: Text('Analytics')),
    Center(child: Text('History')),
    ProfileScreen(),
  ];

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedNavIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedNavIndex],
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedNavIndex,
        onItemTapped: _onNavItemTapped,
      ),
    );
  }
}

class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  bool _actionsExpanded = false;

  void _onQuickActionTap(HomeSection section) {
    final project = context.read<ProjectProvider>().currentProject;
    
    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a project first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    switch (section) {
      case HomeSection.measurement:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UploadBuildingPlanScreen(projectId: project.projectId),
          ),
        );
        break;
      case HomeSection.visualization3d:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProjectDetailScreen(initialTab: 8),
          ),
        );
        break;
      case HomeSection.boqReport:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProjectDetailScreen(initialTab: 4),
          ),
        );
        break;
      case HomeSection.materialSelection:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProjectDetailScreen(initialTab: 1),
          ),
        );
        break;
    }
  }


  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final horizontalPadding = isWide ? 80.0 : 24.0;
    final projectProvider = context.watch<ProjectProvider>();
    final currentProject = projectProvider.currentProject;

    final modules = [
      _ModuleItem(
        id: 'M01',
        title: 'Identifiy Wood Type & Quality',
        subtitle: 'Computer vision defect detection',
        icon: Icons.fact_check_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MaterialWoodQualityScreen()),
        ),
      ),
      _ModuleItem(
        id: 'M02',
        title: 'Time Estimation',
        subtitle: 'Estimate duration for each construction phase',
        icon: Icons.timer_outlined,
        onTap: () {
          if (currentProject == null) {
            _showProjectSelectSnack(context);
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PhaseWiseDurationScreen(pid: currentProject.projectId),
            ),
          );
        },
      ),
      _ModuleItem(
        id: 'M03',
        title: 'Project Progress',
        subtitle: 'Track overall progress and daily logs',
        icon: Icons.trending_up_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrackProgressScreen(
                pid: currentProject?.projectId,
                projectName: currentProject?.projectName,
                location: currentProject?.location,
              ),
            ),
          );
        },
      ),
      _ModuleItem(
        id: 'M04',
        title: 'Cost Estimation',
        subtitle: 'Total project cost and breakdown',
        icon: Icons.account_balance_wallet_outlined,
        onTap: () {
          if (currentProject == null) {
            _showProjectSelectSnack(context);
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TotalCostEstimateScreen(pid: currentProject.projectId),
            ),
          );
        },
      ),
      _ModuleItem(
        id: 'M05',
        title: 'Smart Logistics',
        subtitle: 'Optimized machinery & resource allocation',
        icon: Icons.local_shipping_outlined,
        onTap: () async {
          // Initialize feature-specific services
          await logistics_hive.HiveService.init();
          final hiveService = logistics_hive.HiveService();
          final apiService = logistics_api.ApiService();
          
          if (!context.mounted) return;
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => logistics.HomeScreen(
                apiService: apiService,
                hiveService: hiveService,
              ),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F2), // Premium background from image
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Project Selector
                  _buildProjectSelector(context, projectProvider),
                  const SizedBox(height: 32),

                  // BUILDORA PLATFORM Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'BUILDORA PLATFORM',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    'Intelligent Construction\nManagement Platform',
                    style: GoogleFonts.outfit(
                      fontSize: isWide ? 52 : 38,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111111),
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    'Buildora is an AI-powered ecosystem designed to transform project lifecycles in Sri Lanka. From automated BOQ generation to real-time quality assessment, we eliminate manual errors and optimize efficiency.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.6,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Quick Access Section
                  _buildQuickAccess(context),
                  const SizedBox(height: 32),


                  // Create Project Primary Action
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const it22172532_projects.CreateProjectFlow(),
                        ),
                      ),
                      icon: const Icon(Icons.add_business_rounded, size: 24),
                      label: Text(
                        'CREATE NEW PROJECT',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Modules Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Management Modules',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111111),
                        ),
                      ),
                      Text(
                        '${modules.length} Modules',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.black38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Modules List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: modules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 20),
                    itemBuilder: (context, index) => _ModuleCard(item: modules[index]),
                  ),
                ],
              ),
            ),
            ProjectHubQuickActions(
              actionsExpanded: _actionsExpanded,
              onToggle: () => setState(() => _actionsExpanded = !_actionsExpanded),
              onActionTap: _onQuickActionTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccess(BuildContext context) {
    final actions = [
      (HomeSection.measurement, 'Measure', Icons.straighten),
      (HomeSection.visualization3d, '3D View', Icons.view_in_ar),
      (HomeSection.boqReport, 'BOQ', Icons.assessment),
      (HomeSection.materialSelection, 'Materials', Icons.shopping_cart),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Access',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: actions.map((a) {
            return Expanded(
              child: GestureDetector(
                onTap: () => _onQuickActionTap(a.$1),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(a.$3, color: const Color(0xFFFF5722), size: 24),
                      const SizedBox(height: 8),
                      Text(
                        a.$2,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }


  Widget _buildProjectSelector(BuildContext context, ProjectProvider provider) {
    if (provider.loading) {
      return const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()));
    }

    final projects = provider.projects;
    final current = provider.currentProject;

    if (projects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No projects found. Please create one to start.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.brown,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProjectModel>(
          isExpanded: true,
          value: projects.isEmpty ? null : projects.cast<ProjectModel?>().firstWhere(
            (p) => p?.projectId == current?.projectId,
            orElse: () => null,
          ),
          hint: Text(
            'Select Active Project',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.black45),
          ),
          items: {for (final p in projects) p.projectId: p}.values.map((p) {
            return DropdownMenuItem<ProjectModel>(
              value: p,
              child: Row(
                children: [
                  const Icon(
                    Icons.business_center_rounded,
                    size: 20,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.projectName ?? 'Unnamed Project',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      p.location ?? 'No location',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (p) async {
            if (p == null) return;

            await provider.selectProject(p.projectId);
            if (!context.mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Switched to ${p.projectName ?? p.projectId} workspace.'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  void _showProjectSelectSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select a project from the top dropdown first.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final _ModuleItem item;
  const _ModuleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5722),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.id,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Icon(item.icon, color: const Color(0xFFFF5722), size: 32),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                item.title,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.subtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.black45,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Text(
                    'LAUNCH MODULE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFF5722),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFFFF5722),
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModuleItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}
