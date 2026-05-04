import 'package:flutter/material.dart';

import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import 'paint_recommendation_screen.dart';
import 'skimcoat_recommendation_screen.dart';

//  Door types meta 
const _kDoorTypes = [
  (label: 'Panel Door',   icon: Icons.door_front_door_rounded),
  (label: 'Flush Door',   icon: Icons.crop_square_rounded),
  (label: 'Sliding Door', icon: Icons.swap_horiz_rounded),
  (label: 'Glass / FW',   icon: Icons.window_rounded),
];

//  Screen 

class DoorPaintRecommendationScreen extends StatefulWidget {
  final Map<String, dynamic>? doors;
  const DoorPaintRecommendationScreen({super.key, this.doors});

  @override
  State<DoorPaintRecommendationScreen> createState() =>
      _DoorPaintRecommendationScreenState();
}

class _DoorPaintRecommendationScreenState
    extends State<DoorPaintRecommendationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kenBurns;
  late final Animation<double> _scale;
  late final Animation<Alignment> _align;

  @override
  void initState() {
    super.initState();
    _kenBurns = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _kenBurns, curve: Curves.easeInOut),
    );
    _align = Tween<Alignment>(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).animate(CurvedAnimation(parent: _kenBurns, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _kenBurns.dispose();
    super.dispose();
  }

  String _fmt(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    return (s.isEmpty || s == 'null') ? '' : s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF5D4037),
            foregroundColor: Colors.white,
            title: const Text(
              'Door Recommendation',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: _buildHero(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Door Types',
                      Icons.door_front_door_rounded, const Color(0xFF5D4037)),
                  const SizedBox(height: 12),
                  _buildTypeChips(),
                  const SizedBox(height: 28),
                  _sectionLabel('Door Measurements',
                      Icons.straighten_rounded, const Color(0xFF5D4037)),
                  const SizedBox(height: 12),
                  widget.doors != null && widget.doors!.isNotEmpty
                      ? _buildTable(widget.doors!)
                      : _placeholder('No door schedule data available.'),
                  const SizedBox(height: 32),
                  _sectionLabel('Material Recommendations',
                      Icons.auto_awesome_rounded, const Color(0xFF5D4037)),
                  const SizedBox(height: 6),
                  Text(
                    'Select a recommendation type for door surfaces',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  _BigActionCard(
                    icon: Icons.format_paint_rounded,
                    title: 'Paint Recommendation',
                    subtitle: 'Best paint brand & grade for door surfaces',
                    colors: const [Color(0xFFFF6B35), Color(0xFFFF8A5B)],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PaintRecommendationScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _BigActionCard(
                    icon: Icons.layers_rounded,
                    title: 'Skimcoat Recommendation',
                    subtitle: 'Best skimcoat product for door surfaces',
                    colors: const [Color(0xFF00897B), Color(0xFF26A69A)],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const SkimcoatRecommendationScreen()),
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

  Widget _buildHero() {
    return AnimatedBuilder(
      animation: _kenBurns,
      builder: (_, __) => Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: _scale.value,
            alignment: _align.value,
            child: Image.asset('AppImages/wood/door1.png', fit: BoxFit.cover),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x225D4037),
                  Colors.transparent,
                  Color(0x885D4037),
                  Color(0xDD5D4037),
                ],
                stops: [0.0, 0.35, 0.70, 1.0],
              ),
            ),
          ),
          Positioned(
            bottom: 22,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: const Text('Door Surfaces',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8)),
                ),
                const SizedBox(height: 8),
                const Text('Paint & Skimcoat Guide',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                            color: Colors.black45,
                            blurRadius: 10,
                            offset: Offset(0, 2))
                      ],
                    )),
                const SizedBox(height: 4),
                Text('Tap below to get AI-powered material recommendations',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.80), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: _kDoorTypes.map((t) {
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: const Color(0xFF5D4037).withAlpha(50), width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(t.icon, size: 16, color: const Color(0xFF5D4037)),
            const SizedBox(width: 6),
            Text(t.label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5D4037))),
          ]),
        );
      }).toList(),
    );
  }

  Widget _sectionLabel(String text, IconData icon, Color color) {
    return Row(children: [
      Container(
        width: 3,
        height: 18,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(text,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: color)),
    ]);
  }

  Widget _buildTable(Map<String, dynamic> doors) {
    const color = Color(0xFF5D4037);
    const headers = ['Door', 'Width', 'Height', 'Type', 'Qty'];
    final rows = doors.entries.map((e) {
      final d = e.value is Map<String, dynamic>
          ? e.value as Map<String, dynamic>
          : <String, dynamic>{};
      return [
        e.key,
        _fmt(d['width']),
        _fmt(d['height']),
        _fmt(d['type']),
        _fmt(d['quantity']),
      ];
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Table(
        border: TableBorder(
          horizontalInside:
              BorderSide(color: color.withAlpha(25), width: 1),
        ),
        columnWidths: {
          0: const FlexColumnWidth(1.4),
          for (int i = 1; i < headers.length; i++)
            i: const FlexColumnWidth(1),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: color.withAlpha(22)),
            children: headers
                .map((h) => _cell(h, isHeader: true, color: color))
                .toList(),
          ),
          ...rows.asMap().entries.map((entry) => TableRow(
                decoration: BoxDecoration(
                  color: entry.key.isEven
                      ? Colors.white
                      : const Color(0xFFFBF7F4),
                ),
                children: entry.value
                    .map((v) =>
                        _cell(v.isEmpty ? '' : v, color: color))
                    .toList(),
              )),
        ],
      ),
    );
  }

  Widget _cell(String text,
      {bool isHeader = false, required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 11 : 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? color : Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _placeholder(String msg) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade500))),
        ]),
      );
}

//  Gradient action card 

class _BigActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _BigActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 16),
          ]),
        ),
      ),
    );
  }
}

//  Public ActionCard (backward compat  keep exported) 

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary),
        ]),
      ),
    );
  }
}
