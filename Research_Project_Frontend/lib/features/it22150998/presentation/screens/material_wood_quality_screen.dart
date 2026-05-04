import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/module_header.dart';
import '../../../../core/widgets/bottom_nav_bar.dart';
import 'wood_defects_screen.dart';
import 'wood_type_screen.dart';

class MaterialWoodQualityScreen extends StatefulWidget {
  const MaterialWoodQualityScreen({super.key});

  @override
  State<MaterialWoodQualityScreen> createState() => _MaterialWoodQualityScreenState();
}

class _MaterialWoodQualityScreenState extends State<MaterialWoodQualityScreen> {
  void _onNavItemTapped(int index) {
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.forgeBlackActual,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('MODULE M01'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ModuleHeader(
              moduleId: 'M01',
              title: 'Material & Wood Quality',
              description: 'Computer vision defect detection for ensuring high-grade construction materials.',
            ),
            const SizedBox(height: AppSizes.s32),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final cards = [
                  _WoodQualityActionCard(
                    title: 'Wood Type Identification',
                    subtitle: 'Upload a timber image and classify the wood type.',
                    icon: Icons.forest_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WoodTypeScreen()),
                      );
                    },
                  ),
                  _WoodQualityActionCard(
                    title: 'Wood Defect Detection',
                    subtitle: 'Detect visible defects and review recommended usage guidance.',
                    icon: Icons.search_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WoodDefectsScreen()),
                      );
                    },
                  ),
                ];

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final card in cards) ...[
                        Expanded(child: card),
                        if (card != cards.last) const SizedBox(width: AppSizes.s20),
                      ],
                    ],
                  );
                }

                return Column(
                  children: [
                    for (final card in cards) ...[
                      card,
                      if (card != cards.last) const SizedBox(height: AppSizes.s16),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onItemTapped: _onNavItemTapped,
      ),
    );
  }
}

class _WoodQualityActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _WoodQualityActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusPanel),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusPanel),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.s24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusPanel),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.statusActiveBg,
                  borderRadius: BorderRadius.circular(AppSizes.radiusButton),
                ),
                child: Icon(icon, color: AppColors.flameOrange),
              ),
              const SizedBox(height: AppSizes.s20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.s8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSizes.s24),
              const Row(
                children: [
                  Text(
                    'OPEN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppColors.flameOrange,
                    ),
                  ),
                  SizedBox(width: AppSizes.s8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.flameOrange,
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
