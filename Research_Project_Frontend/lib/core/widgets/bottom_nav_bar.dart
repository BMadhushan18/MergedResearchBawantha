import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onItemTapped;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.forgeBlackActual,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                label: 'HOME',
                isActive: currentIndex == 0,
                onTap: () => onItemTapped(0),
              ),
              _NavItem(
                icon: Icons.search_outlined,
                label: 'SEARCH',
                isActive: currentIndex == 1,
                onTap: () => onItemTapped(1),
              ),
              _NavItem(
                icon: Icons.pie_chart_rounded,
                label: 'ANALYTICS',
                isActive: currentIndex == 2,
                onTap: () => onItemTapped(2),
              ),
              _NavItem(
                icon: Icons.history_rounded,
                label: 'HISTORY',
                isActive: currentIndex == 3,
                onTap: () => onItemTapped(3),
              ),
              _NavItem(
                icon: Icons.person_outlined,
                label: 'PROFILE',
                isActive: currentIndex == 4,
                onTap: () => onItemTapped(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppColors.flameOrange : Colors.white54,
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.flameOrange : Colors.white54,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}
