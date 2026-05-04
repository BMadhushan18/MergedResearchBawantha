import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/module_header.dart';
import '../../../core/widgets/custom_button.dart';

import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../screens/home_screen.dart' as main_home;

import '../models/boq_input.dart';
import '../services/api_service.dart';
import '../services/hive_service.dart';
import '../utils/constants.dart';
import 'all_projects_screen.dart';
import 'dashboard_screen.dart';
import 'logistics_management_screen.dart';
import 'upload_screen.dart';

class HomeScreen extends StatefulWidget {
  final ApiService apiService;
  final HiveService hiveService;

  const HomeScreen({
    super.key,
    required this.apiService,
    required this.hiveService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  List<OfflineUploadRecord> _offline = const [];

  @override
  void initState() {
    super.initState();
    _reloadLocal();
  }

  void _reloadLocal() {
    setState(() {
      _offline = widget.hiveService.getOfflineUploads();
    });
  }

  Future<void> _openBackendSettings() async {
    final current = widget.hiveService.getBaseUrl() ?? AppConstants.defaultBaseUrl;
    final controller = TextEditingController(text: current);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusCard)),
          title: Text(
            'BACKEND SETTINGS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.32,
              color: AppColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update API Endpoint',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: AppConstants.defaultBaseUrl,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            CustomButton(
              label: 'CANCEL',
              type: CustomButtonType.ghost,
              onPressed: () => Navigator.pop(context),
              width: 100,
            ),
            CustomButton(
              label: 'SAVE',
              type: CustomButtonType.primary,
              onPressed: () async {
                final raw = controller.text.trim();
                final value = raw.isEmpty ? AppConstants.defaultBaseUrl : raw;
                final normalized = value.startsWith('http://') || value.startsWith('https://')
                    ? value
                    : 'http://$value';
                
                await widget.hiveService.setBaseUrl(normalized);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Backend URL saved'),
                      backgroundColor: AppColors.flameOrange,
                    ),
                  );
                }
              },
              width: 100,
            ),
          ],
        );
      },
    );
  }

  void _onMainNavItemTapped(int index) {
    if (index == 0) return; // Already in a module, Home means staying or going back?
    // For now, let's just allow them to go back to main home with that index
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 900;
    
    final pages = [
      UploadScreen(
        apiService: widget.apiService,
        hiveService: widget.hiveService,
        onUploaded: _reloadLocal,
      ),
      DashboardScreen(
        apiService: widget.apiService,
        hiveService: widget.hiveService,
      ),
      AllProjectsScreen(
        apiService: widget.apiService,
        hiveService: widget.hiveService,
      ),
    ];

    final destinations = const [
      NavigationDestination(
        icon: Icon(Icons.upload_file_outlined, size: 20),
        selectedIcon: Icon(Icons.upload_file, color: AppColors.flameOrange, size: 20),
        label: 'Upload',
      ),
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined, size: 20),
        selectedIcon: Icon(Icons.dashboard, color: AppColors.flameOrange, size: 20),
        label: 'Dashboard',
      ),
      NavigationDestination(
        icon: Icon(Icons.analytics_outlined, size: 20),
        selectedIcon: Icon(Icons.analytics_rounded, color: AppColors.flameOrange, size: 20),
        label: 'All Projects',
      ),
    ];

    final railDestinations = const [
      NavigationRailDestination(
        icon: Icon(Icons.upload_file_outlined),
        selectedIcon: Icon(Icons.upload_file, color: AppColors.flameOrange),
        label: Text('Upload'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard, color: AppColors.flameOrange),
        label: Text('Dashboard'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.analytics_outlined),
        selectedIcon: Icon(Icons.analytics_rounded, color: AppColors.flameOrange),
        label: Text('All Projects'),
      ),
    ];

    Widget bodyContent = Column(
      children: [
        Expanded(
          child: pages[_index],
        ),
        if (_index == 0) _buildRecentOfflinePanel(),
      ],
    );

    return DefaultTabController(
      length: 3,
      initialIndex: _index,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.forgeBlackActual,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'BUILDORA',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LogisticsManagementScreen(
                    apiService: widget.apiService,
                    hiveService: widget.hiveService,
                  ),
                ),
              ),
              icon: const Icon(Icons.psychology_outlined, size: 20),
              tooltip: 'ML Management',
            ),
            IconButton(
              onPressed: _openBackendSettings,
              icon: const Icon(Icons.settings_outlined, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Container(
              color: AppColors.forgeBlackActual,
              child: TabBar(
                onTap: (i) => setState(() => _index = i),
                indicatorColor: AppColors.flameOrange,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(text: 'UPLOAD'),
                  Tab(text: 'DASHBOARD'),
                  Tab(text: 'PROJECTS'),
                ],
              ),
            ),
          ),
        ),
        body: isWide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: (value) => setState(() => _index = value),
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: AppColors.forgeBlackActual,
                    indicatorColor: AppColors.flameOrange.withOpacity(0.15),
                    unselectedIconTheme: const IconThemeData(color: Colors.white54, size: 22),
                    selectedIconTheme: const IconThemeData(color: AppColors.flameOrange, size: 22),
                    selectedLabelTextStyle: GoogleFonts.inter(
                      color: AppColors.flameOrange,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    unselectedLabelTextStyle: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    destinations: railDestinations,
                  ),
                  const VerticalDivider(thickness: 0.5, width: 0.5, color: AppColors.divider),
                  Expanded(child: bodyContent),
                ],
              )
            : bodyContent,
        bottomNavigationBar: BottomNavBar(
          currentIndex: 0,
          onItemTapped: _onMainNavItemTapped,
        ),
      ),
    );
  }

  Widget _buildRecentOfflinePanel() {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Recent Local Records',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_offline.isEmpty)
            const Text('No local records yet',
                style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12))
          else
            ..._offline.take(3).map(
              (item) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle,
                        color: Color(0xFF9E9E9E), size: 5),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.fileName} — ${dateFormat.format(item.uploadedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF757575), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
