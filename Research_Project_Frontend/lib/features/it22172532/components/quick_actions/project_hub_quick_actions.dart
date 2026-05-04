import 'package:flutter/material.dart';

enum HomeSection {
  measurement,
  visualization3d,
  boqReport,
  materialSelection,
}

class ProjectHubQuickActions extends StatelessWidget {
  const ProjectHubQuickActions({
    super.key,
    required this.actionsExpanded,
    required this.onToggle,
    required this.onActionTap,
  });

  final bool actionsExpanded;
  final VoidCallback onToggle;
  final ValueChanged<HomeSection> onActionTap;

  Widget _buildQuickActionButton({
    required String heroTag,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (actionsExpanded)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(label),
          ),
        FloatingActionButton.small(
          heroTag: heroTag,
          onPressed: onTap,
          child: Icon(icon),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildQuickActionButton(
            heroTag: 'home-measurement',
            icon: Icons.straighten,
            label: 'Measurement',
            onTap: () => onActionTap(HomeSection.measurement),
          ),
          const SizedBox(height: 10),
          _buildQuickActionButton(
            heroTag: 'home-3d',
            icon: Icons.view_in_ar,
            label: '3D Visualization',
            onTap: () => onActionTap(HomeSection.visualization3d),
          ),
          const SizedBox(height: 10),
          _buildQuickActionButton(
            heroTag: 'home-boq',
            icon: Icons.assessment,
            label: 'BOQ Report',
            onTap: () => onActionTap(HomeSection.boqReport),
          ),
          const SizedBox(height: 10),
          _buildQuickActionButton(
            heroTag: 'home-material',
            icon: Icons.shopping_cart,
            label: 'Material Selection',
            onTap: () => onActionTap(HomeSection.materialSelection),
          ),
          const SizedBox(height: 14),
          FloatingActionButton(
            heroTag: 'home-toggle',
            onPressed: onToggle,
            child: Icon(actionsExpanded ? Icons.close : Icons.menu),
          ),
        ],
      ),
    );
  }
}
