import 'dart:async';
import 'package:flutter/material.dart';

import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import 'door_paint_recommendation_screen.dart' show ActionCard;
import 'paint_recommendation_screen.dart';
import 'skimcoat_recommendation_screen.dart';

//  Window types meta 
const _kWindowTypes = [
  (label: 'Casement',  icon: Icons.crop_square_rounded),
  (label: 'Sliding',   icon: Icons.swap_horiz_rounded),
  (label: 'Fixed / FW',icon: Icons.window_rounded),
  (label: 'Louvered',  icon: Icons.format_list_numbered_rounded),
];

const _kWindowImages = [
  'AppImages/wood/win1.png',
  'AppImages/wood/win3.png',
];

//  Screen 

class WindowPaintRecommendationScreen extends StatefulWidget {
  final Map<String, dynamic>? windows;
  const WindowPaintRecommendationScreen({super.key, this.windows});

  @override
  State<WindowPaintRecommendationScreen> createState() =>
      _WindowPaintRecommendationScreenState();
}

class _WindowPaintRecommendationScreenState
    extends State<WindowPaintRecommendationScreen>
    with TickerProviderStateMixin {
  // Carousel
  int _currentImage = 0;
  Timer? _carouselTimer;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 1.0,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fadeCtrl.reverse().then((_) {
        if (mounted) {
          setState(() =>
              _currentImage = (_currentImage + 1) % _kWindowImages.length);
          _fadeCtrl.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _fadeCtrl.dispose();
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
      backgroundColor: const Color(0xFFF0F7F6),
      body: CustomScrollView(
        slivers: [
          //  Crossfade image header 
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF00695C),
            foregroundColor: Colors.white,
            title: const Text(
              'Window Recommendation',
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
                  //  Window type chips 
                  _sectionLabel('Window Types',
                      Icons.window_rounded, const Color(0xFF00695C)),
                  const SizedBox(height: 12),
                  _buildTypeChips(),
                  const SizedBox(height: 28),

                  //  Measurements 
                  _sectionLabel('Window & FW Measurements',
                      Icons.straighten_rounded, const Color(0xFF00695C)),
                  const SizedBox(height: 12),
                  widget.windows != null && widget.windows!.isNotEmpty
                      ? _buildTable(widget.windows!)
                      : _placeholder('No window schedule data available.'),
                  const SizedBox(height: 32),

                  //  Recommendations 
                  _sectionLabel('Material Recommendations',
                      Icons.auto_awesome_rounded, const Color(0xFF00695C)),
                  const SizedBox(height: 6),
                  Text(
                    'Select a recommendation type for window frames',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  _BigActionCard(
                    icon: Icons.format_paint_rounded,
                    title: 'Paint Recommendation',
                    subtitle: 'Best paint brand for window frames & sills',
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
                    subtitle: 'Best skimcoat for window surrounds',
                    colors: const [Color(0xFF00695C), Color(0xFF26A69A)],
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

  //  Crossfade carousel hero 
  Widget _buildHero() {
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: _fadeAnim,
          child: Image.asset(
            _kWindowImages[_currentImage],
            fit: BoxFit.cover,
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x2200695C),
                Colors.transparent,
                Color(0x8800695C),
                Color(0xDD00695C),
              ],
              stops: [0.0, 0.35, 0.70, 1.0],
            ),
          ),
        ),
        // Dot indicators
        Positioned(
          top: 14,
          right: 16,
          child: Row(
            children: List.generate(_kWindowImages.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(left: 5),
                width: _currentImage == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentImage == i
                      ? Colors.white
                      : Colors.white38,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
        // Bottom label block
        Positioned(
          bottom: 22,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30),
                ),
                child: const Text('Window & FW Surfaces',
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
    );
  }

  //  Window-type chips 
  Widget _buildTypeChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: _kWindowTypes.map((t) {
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: const Color(0xFF00695C).withAlpha(50), width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(t.icon, size: 16, color: const Color(0xFF00695C)),
            const SizedBox(width: 6),
            Text(t.label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00695C))),
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

  Widget _buildTable(Map<String, dynamic> windows) {
    const color = Color(0xFF00695C);
    const headers = ['Mark', 'Width', 'Height', 'Type', 'Qty'];
    final rows = windows.entries.map((e) {
      final w = e.value is Map<String, dynamic>
          ? e.value as Map<String, dynamic>
          : <String, dynamic>{};
      return [
        e.key,
        _fmt(w['width']),
        _fmt(w['height']),
        _fmt(w['type']),
        _fmt(w['quantity']),
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
                      : const Color(0xFFF3FAF8),
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

//  Gradient action card (local) 

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
