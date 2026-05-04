import 'package:flutter/material.dart';

import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import 'wood_type_screen.dart';
import 'wood_defects_screen.dart';

class WoodDetectionScreen extends StatelessWidget {
  const WoodDetectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Wood Detection'),
        backgroundColor: const Color(0xFF5D4037),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF5D4037).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.park_rounded,
                    color: Color(0xFF5D4037), size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wood Detection Module',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 3),
                    Text('AI-powered species & defect analysis',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 32),

            // Wood Type card
            Expanded(
              child: _WoodImageCard(
                title: 'Wood Type Classifier',
                subtitle:
                    'Upload a photo to identify the wood species',
                imagePath: 'AppImages/wood/woodTypeClas.png',
                accent: const Color(0xFF5D4037),
                tagText: 'Species ID',
                icon: Icons.image_search_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const WoodTypeScreen()),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Wood Defect card
            Expanded(
              child: _WoodImageCard(
                title: 'Wood Defect Classifier',
                subtitle:
                    'Detect defects and assess quality from a photo',
                imagePath: 'AppImages/wood/woodDefectClass.png',
                accent: const Color(0xFF4E342E),
                tagText: 'Defect Analysis',
                icon: Icons.report_problem_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const WoodDefectsScreen()),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

//  Image-background tap card 

class _WoodImageCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final Color accent;
  final String tagText;
  final IconData icon;
  final VoidCallback onTap;

  const _WoodImageCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.accent,
    required this.tagText,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_WoodImageCard> createState() => _WoodImageCardState();
}

class _WoodImageCardState extends State<_WoodImageCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 140),
        lowerBound: 0.0,
        upperBound: 1.0);
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withOpacity(0.28),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
            image: DecorationImage(
              image: AssetImage(widget.imagePath),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  widget.accent.withOpacity(0.70),
                  widget.accent.withOpacity(0.90),
                ],
                stops: const [0.0, 0.4, 0.75, 1.0],
              ),
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag pill at top-left
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(widget.icon,
                        size: 12, color: Colors.white70),
                    const SizedBox(width: 5),
                    Text(widget.tagText,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                  ]),
                ),
                const Spacer(),
                // Title & subtitle at bottom
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                          color: Colors.black38,
                          offset: Offset(0, 2),
                          blurRadius: 6)
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                // Tap indicator
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Get Started',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 13, color: Colors.white),
                        ]),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
