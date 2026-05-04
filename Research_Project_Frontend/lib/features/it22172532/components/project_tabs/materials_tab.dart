import 'package:flutter/material.dart';
import 'package:boq_frontend/features/it22172532/services/mongo_api_service.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import 'package:boq_frontend/features/it22172532/screens/projects/material_library_screen.dart';

// ─── Image asset maps ─────────────────────────────────────────────────────────

/// Returns the asset path for a material name (loose match).
String? _matImagePath(String name) {
  final n = name.toLowerCase();
  if (n.contains('cement block') || n.contains('concrete block') || n.contains('hollow')) return 'AppImages/materials/cementBlock.png';
  if (n.contains('cement'))       return 'AppImages/materials/cement.png';
  if (n.contains('sand'))         return 'AppImages/materials/sand.png';
  if (n.contains('aggregate'))    return 'AppImages/materials/aggregates.png';
  if (n.contains('steel') || n.contains('rebar') || n.contains('lintel')) return 'AppImages/materials/steels.png';
  if (n.contains('binding wire')) return 'AppImages/materials/bindingWire.png';
  if (n.contains('nail'))         return 'AppImages/materials/nails.png';
  if (n.contains('tile') || n.contains('skirting')) return 'AppImages/materials/tile.png';
  if (n.contains('paint') || n.contains('ceiling paint') || n.contains('exterior paint')) return 'AppImages/materials/wallPaint.png';
  if (n.contains('primer') || n.contains('filler')) return 'AppImages/materials/fillerPaints.png';
  if (n.contains('putty') || n.contains('puty'))    return 'AppImages/materials/puty.png';
  if (n.contains('brick'))        return 'AppImages/materials/brick.png';
  if (n.contains('block'))        return 'AppImages/materials/cementBlock.png';
  return null;
}

/// Returns the asset path for a brand name (loose match).
String? _brandLogoPath(String brand) {
  final b = brand.toLowerCase();
  if (b.contains('causeway'))             return 'AppImages/brands/causewayPaints.png';
  if (b.contains('dulux'))                return 'AppImages/brands/duluxPaints.png';
  if (b.contains('lanwa'))                return 'AppImages/brands/lanwaCement.png';
  if (b.contains('robbialac') || b.contains('robialac')) return 'AppImages/brands/robbialacPaints.png';
  if (b.contains('sanstha'))              return 'AppImages/brands/sansthaCement.png';
  if (b.contains('taian') || b.contains('taiian'))       return 'AppImages/brands/taianSteels.png';
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Material blueprint definitions  (process → items)
// ─────────────────────────────────────────────────────────────────────────────

const List<_ProcessSection> _kBlueprint = [
  _ProcessSection(
    icon: Icons.foundation,
    label: 'Foundation',
    color: Color(0xFF5C4033),
    items: [
      _MatItem('Cement',           '50 kg Bag'),
      _MatItem('River Sand',       'm³'),
      _MatItem('Coarse Aggregate', 'm³'),
      _MatItem('Steel Rebar Y10',  'kg'),
      _MatItem('Steel Rebar Y12',  'kg'),
      _MatItem('Binding Wire',     'kg'),
      _MatItem('Formwork Timber',  'm²'),
      _MatItem('Nails',            'kg'),
    ],
  ),
  _ProcessSection(
    icon: Icons.bento_outlined,
    label: 'Masonry / Block Work',
    color: Color(0xFF546E7A),
    items: [
      _MatItem('Hollow Concrete Blocks', 'units'),
      _MatItem('Cement',                 '50 kg Bag'),
      _MatItem('River Sand',             'm³'),
      _MatItem('DPC Sheet',              'm²'),
      _MatItem('Lintel Steel',           'kg'),
    ],
  ),
  _ProcessSection(
    icon: Icons.roofing_outlined,
    label: 'Roofing',
    color: Color(0xFF37474F),
    items: [
      _MatItem('Roofing Sheets',  'm²'),
      _MatItem('Timber Rafters',  'm'),
      _MatItem('Timber Purlins',  'm'),
      _MatItem('Ridge Cap',       'm'),
      _MatItem('Fascia Board',    'm'),
      _MatItem('Roofing Nails',   'kg'),
      _MatItem('Roof Screws',     'units'),
    ],
  ),
  _ProcessSection(
    icon: Icons.format_paint_outlined,
    label: 'Plastering & Rendering',
    color: Color(0xFF6A1B9A),
    items: [
      _MatItem('Cement',      '50 kg Bag'),
      _MatItem('Fine Sand',   'm³'),
      _MatItem('Plasticizer', 'L'),
    ],
  ),
  _ProcessSection(
    icon: Icons.grid_on_outlined,
    label: 'Flooring',
    color: Color(0xFF00695C),
    items: [
      _MatItem('Floor Tiles',    'm²'),
      _MatItem('Tile Adhesive',  'Bag'),
      _MatItem('Cement',         '50 kg Bag'),
      _MatItem('Sand',           'm³'),
      _MatItem('Tile Grout',     'kg'),
      _MatItem('Skirting Tiles', 'm'),
    ],
  ),
  _ProcessSection(
    icon: Icons.door_front_door_outlined,
    label: 'Doors & Windows',
    color: AppColors.primary,
    items: [
      _MatItem('Door Frames',    'units'),
      _MatItem('Door Leaves',    'units'),
      _MatItem('Window Frames',  'units'),
      _MatItem('Window Glass',   'm²'),
      _MatItem('Hinges',         'Sets'),
      _MatItem('Door Locks',     'units'),
      _MatItem('Window Latches', 'units'),
    ],
  ),
  _ProcessSection(
    icon: Icons.brush_outlined,
    label: 'Painting & Finishing',
    color: Color(0xFFAD1457),
    items: [
      _MatItem('Wall Paint (Interior)',   'L'),
      _MatItem('Ceiling Paint',           'L'),
      _MatItem('Exterior Paint',          'L'),
      _MatItem('Primer',                  'L'),
      _MatItem('Wall Putty',              'kg'),
      _MatItem('Paint Brushes / Rollers', 'Sets'),
    ],
  ),
  _ProcessSection(
    icon: Icons.electrical_services_outlined,
    label: 'Electrical',
    color: Color(0xFFF57F17),
    items: [
      _MatItem('PVC Conduit Pipe',       'm'),
      _MatItem('Electrical Wire',        'm'),
      _MatItem('MCB Distribution Board', 'units'),
      _MatItem('Switches',               'units'),
      _MatItem('Electrical Sockets',     'units'),
      _MatItem('Light Fittings',         'units'),
      _MatItem('Junction Boxes',         'units'),
    ],
  ),
  _ProcessSection(
    icon: Icons.water_outlined,
    label: 'Plumbing',
    color: Color(0xFF0277BD),
    items: [
      _MatItem('PVC Pipes',    'm'),
      _MatItem('PVC Fittings', 'units'),
      _MatItem('Wash Basin',   'units'),
      _MatItem('WC Closet',    'units'),
      _MatItem('Kitchen Sink', 'units'),
      _MatItem('Water Taps',   'units'),
      _MatItem('Shower Set',   'units'),
      _MatItem('Water Tank',   'units'),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────

class MaterialsTab extends StatefulWidget {
  final String? roomLabel;
  final Map<String, dynamic>? roomData;

  const MaterialsTab({super.key, this.roomLabel, this.roomData});

  @override
  State<MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends State<MaterialsTab> {
  List<Map<String, dynamic>> _globalMaterials = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.roomLabel == null) _loadGlobalMaterials();
  }

  Future<void> _loadGlobalMaterials() async {
    setState(() => _loading = true);
    try {
      final api = MongoApiService();
      await api.loadToken();
      final list = await api.getAllMaterials();
      if (mounted) {
        setState(() =>
            _globalMaterials = list.cast<Map<String, dynamic>>());
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> _byCategory() {
    final r = <String, List<Map<String, dynamic>>>{};
    for (final m in _globalMaterials) {
      final cat = (m['category'] as String?) ?? 'General';
      r.putIfAbsent(cat, () => []).add(m);
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.roomLabel != null) {
      return _MaterialBlueprintView(
          roomLabel: widget.roomLabel!, roomData: widget.roomData);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Materials Library',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: _loadGlobalMaterials,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _globalMaterials.isEmpty
              ? _buildEmpty()
              : _buildTable(),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('No materials loaded',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loadGlobalMaterials,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      );

  Widget _buildTable() {
    final grouped = _byCategory();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      children: grouped.entries
          .map((e) => _CategoryCard(
                category: e.key,
                materials: e.value,
              ))
          .toList(),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddMaterialSheet(onAdded: _loadGlobalMaterials),
    );
  }
}

// ─── Category card (groups materials by category in a scrollable table) ───────

class _CategoryCard extends StatelessWidget {
  final String category;
  final List<Map<String, dynamic>> materials;
  const _CategoryCard({required this.category, required this.materials});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Category header ───────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                  bottom: BorderSide(
                      color: AppColors.primary.withAlpha(40))),
            ),
            child: Row(children: [
              Icon(_categoryIcon(category),
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(category,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.primary)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${materials.length}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          // ── Scrollable table ──────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 680),
              child: Column(children: [
                // Header row
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: const [
                    SizedBox(width: 44), // image
                    SizedBox(width: 8),
                    SizedBox(
                        width: 150,
                        child: Text('Material',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF757575)))),
                    SizedBox(width: 8),
                    SizedBox(
                        width: 52,
                        child: Text('Unit',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF757575)))),
                    SizedBox(width: 8),
                    SizedBox(
                        width: 160,
                        child: Text('Brands',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF757575)))),
                    SizedBox(width: 8),
                    SizedBox(
                        width: 155,
                        child: Text('Sizes',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF757575)))),
                    SizedBox(width: 8),
                    SizedBox(
                        width: 110,
                        child: Text('Unit Price (LKR)',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF757575)))),
                  ]),
                ),
                const Divider(height: 1, thickness: 1),
                for (int i = 0; i < materials.length; i++)
                  _MaterialTableRow(
                      material: materials[i],
                      isLast: i == materials.length - 1),
              ]),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('concrete') || c.contains('foundation'))
      return Icons.foundation;
    if (c.contains('steel')) return Icons.hardware_outlined;
    if (c.contains('masonry') || c.contains('walling'))
      return Icons.bento_outlined;
    if (c.contains('plaster') || c.contains('finish'))
      return Icons.format_paint_outlined;
    if (c.contains('floor')) return Icons.grid_on_outlined;
    if (c.contains('roof')) return Icons.roofing_outlined;
    if (c.contains('door') || c.contains('window'))
      return Icons.door_front_door_outlined;
    if (c.contains('paint') || c.contains('coating'))
      return Icons.brush_outlined;
    if (c.contains('electrical'))
      return Icons.electrical_services_outlined;
    if (c.contains('plumb')) return Icons.water_outlined;
    return Icons.inventory_2_outlined;
  }
}

// ─── One material row in the library table ───────────────────────────────────

class _MaterialTableRow extends StatelessWidget {
  final Map<String, dynamic> material;
  final bool isLast;
  const _MaterialTableRow(
      {required this.material, required this.isLast});

  String _formatPrice(dynamic price) {
    if (price == null) return '—';
    final n = price is num ? price.toDouble() : double.tryParse('$price') ?? 0;
    final s = n.toStringAsFixed(0);
    // thousands separator
    final formatted = s.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return 'LKR $formatted';
  }

  String _truncate(List<String> list) {
    if (list.isEmpty) return '—';
    if (list.length <= 2) return list.join(', ');
    return '${list.take(2).join(', ')} +${list.length - 2}';
  }

  @override
  Widget build(BuildContext context) {
    final name = material['name'] as String? ?? '';
    final unit = material['unit'] as String? ?? '';
    final brands = List<String>.from(material['brands'] as List? ?? []);
    final sizes = List<String>.from(material['sizes'] as List? ?? []);
    final imgPath = _matImagePath(name);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Image
                SizedBox(
                  width: 44,
                  height: 44,
                  child: imgPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.asset(imgPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _placeholder(name)),
                        )
                      : _placeholder(name),
                ),
                const SizedBox(width: 8),
                // Name
                SizedBox(
                  width: 150,
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                // Unit badge
                SizedBox(
                  width: 52,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text(unit,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                // Brands
                SizedBox(
                  width: 160,
                  child: Text(_truncate(brands),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                // Sizes
                SizedBox(
                  width: 155,
                  child: Text(_truncate(sizes),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                // Unit price
                SizedBox(
                  width: 110,
                  child: Text(_formatPrice(material['unitPrice']),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32))),
                ),
              ]),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }

  Widget _placeholder(String name) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.primary),
        ),
      );
}

// ─── Add Material Sheet (comprehensive form) ─────────────────────────────────

class _AddMaterialSheet extends StatefulWidget {
  final VoidCallback? onAdded;
  const _AddMaterialSheet({this.onAdded});

  @override
  State<_AddMaterialSheet> createState() => _AddMaterialSheetState();
}

class _AddMaterialSheetState extends State<_AddMaterialSheet> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _brandInput = TextEditingController();
  final _sizeInput = TextEditingController();

  String _selectedCategory = 'Concrete & Foundation';
  String _selectedUnit = 'bag';
  final List<String> _brands = [];
  final List<String> _sizes = [];
  bool _saving = false;

  static const _categories = [
    'Concrete & Foundation',
    'Structural Steel',
    'Masonry & Walling',
    'Plastering & Finishing',
    'Flooring',
    'Roofing',
    'Doors & Windows',
    'Paint & Coatings',
    'Electrical',
    'Plumbing',
    'Ironmongery & Misc',
    'General',
  ];

  static const _units = [
    'bag', 'kg', 'm³', 'm²', 'm', 'L', 'No.', 'ton', 'Set'
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _brandInput.dispose();
    _sizeInput.dispose();
    super.dispose();
  }

  void _addBrand() {
    final v = _brandInput.text.trim();
    if (v.isNotEmpty && !_brands.contains(v)) {
      setState(() => _brands.add(v));
      _brandInput.clear();
    }
  }

  void _addSize() {
    final v = _sizeInput.text.trim();
    if (v.isNotEmpty && !_sizes.contains(v)) {
      setState(() => _sizes.add(v));
      _sizeInput.clear();
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = MongoApiService();
      await api.loadToken();
      await api.createMaterial(
        name: _nameCtrl.text.trim(),
        category: _selectedCategory,
        unit: _selectedUnit,
        brands: _brands,
        sizes: _sizes,
        unitPrice: _priceCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(_priceCtrl.text.trim()),
      );
      widget.onAdded?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scroll) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Add Material',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Material Name ─────────────────────────────
                    _label('Material Name *'),
                    TextFormField(
                      controller: _nameCtrl,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      decoration: _inputDeco('e.g. Cement (OPC)'),
                    ),
                    const SizedBox(height: 14),

                    // ── Category ──────────────────────────────────
                    _label('Category'),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: _inputDeco(null),
                      isExpanded: true,
                      items: _categories
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedCategory = v!),
                    ),
                    const SizedBox(height: 14),

                    // ── Unit ──────────────────────────────────────
                    _label('Unit'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _units.map((u) {
                        final sel = _selectedUnit == u;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedUnit = u),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.primary
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sel
                                      ? AppColors.primary
                                      : Colors.grey[300]!),
                            ),
                            child: Text(u,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: sel
                                        ? Colors.white
                                        : Colors.grey[700])),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // ── Unit Price ────────────────────────────────
                    _label('Unit Price (LKR)'),
                    TextFormField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: _inputDeco('e.g. 2200'),
                    ),
                    const SizedBox(height: 14),

                    // ── Brands ────────────────────────────────────
                    _label('Brands'),
                    ..._brands.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withAlpha(12),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.primary
                                          .withAlpha(60)),
                                ),
                                child: Text(e.value,
                                    style: const TextStyle(
                                        fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(
                                  () => _brands.removeAt(e.key)),
                              child: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.redAccent,
                                  size: 20),
                            ),
                          ]),
                        )),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _brandInput,
                          decoration: _inputDeco('Add brand name'),
                          onFieldSubmitted: (_) => _addBrand(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _addBtn(_addBrand),
                    ]),
                    const SizedBox(height: 14),

                    // ── Sizes ─────────────────────────────────────
                    _label('Sizes / Variants'),
                    ..._sizes.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.green.withAlpha(15),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.green
                                          .withAlpha(60)),
                                ),
                                child: Text(e.value,
                                    style: const TextStyle(
                                        fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _sizes.removeAt(e.key)),
                              child: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.redAccent,
                                  size: 20),
                            ),
                          ]),
                        )),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _sizeInput,
                          decoration: _inputDeco(
                              'Add size (e.g. 50 kg, 200×200 mm)'),
                          onFieldSubmitted: (_) => _addSize(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _addBtn(_addSize),
                    ]),
                    const SizedBox(height: 24),

                    // ── Save button ───────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                            : const Text('Save Material',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF455A64))),
      );

  InputDecoration _inputDeco(String? hint) => InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      );

  Widget _addBtn(VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.add, color: Colors.white, size: 22),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Blueprint view: process-by-process material tables
// ─────────────────────────────────────────────────────────────────────────────

class _MaterialBlueprintView extends StatelessWidget {
  final String roomLabel;
  final Map<String, dynamic>? roomData;
  const _MaterialBlueprintView(
      {required this.roomLabel, this.roomData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ── Room header card ──────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.meeting_room_outlined,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Materials Blueprint',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 11)),
                    Text(roomLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Qty: pending',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Manage Material Library',
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MaterialLibraryScreen()),
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.library_books_outlined,
                        size: 18, color: Colors.white),
                  ),
                ),
              ),
            ]),
          ),

          // ── Process sections ──────────────────────────────────────────
          for (final section in _kBlueprint) ...[
            _ProcessCard(section: section),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Process section card ─────────────────────────────────────────────────────

class _ProcessCard extends StatelessWidget {
  final _ProcessSection section;
  const _ProcessCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: section.color.withAlpha(20),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                  bottom: BorderSide(
                      color: section.color.withAlpha(40), width: 1)),
            ),
            child: Row(children: [
              Icon(section.icon, size: 18, color: section.color),
              const SizedBox(width: 8),
              Text(section.label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: section.color)),
            ]),
          ),

          // Scrollable table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 560),
              child: Column(
                children: [
                  // Column headers row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      const SizedBox(width: 160,
                          child: Text('Material',
                              style: TextStyle(fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF757575)))),
                      const SizedBox(width: 12),
                      const SizedBox(width: 60,
                          child: Text('Unit',
                              style: TextStyle(fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF757575)))),
                      const SizedBox(width: 12),
                      const SizedBox(width: 70,
                          child: Text('Quantity',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF757575)))),
                      const SizedBox(width: 12),
                      const SizedBox(width: 100,
                          child: Text('Brand',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF757575)))),
                      const SizedBox(width: 12),
                      const SizedBox(width: 100,
                          child: Text('Size',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF757575)))),
                    ]),
                  ),
                  const Divider(height: 1),
                  for (int i = 0; i < section.items.length; i++)
                    _MatRow(
                        item: section.items[i],
                        isLast: i == section.items.length - 1),
                ],
              ),
            ),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _MatRow extends StatefulWidget {
  final _MatItem item;
  final bool isLast;
  const _MatRow({required this.item, required this.isLast});

  @override
  State<_MatRow> createState() => _MatRowState();
}

class _MatRowState extends State<_MatRow> {
  String? _selectedBrand;
  String? _selectedSize;

  // Cache so we only call the API once per row
  List<String>? _brands;
  List<String>? _sizes;
  bool _loadingOptions = false;

  Future<Map<String, List<String>>> _fetchOptions() async {
    if (_brands != null && _sizes != null) {
      return {'brands': _brands!, 'sizes': _sizes!};
    }
    setState(() => _loadingOptions = true);
    try {
      final api = MongoApiService();
      await api.loadToken();
      final res = await api.getMaterialOptions(widget.item.name);
      _brands = List<String>.from(res['brands'] as List? ?? []);
      _sizes  = List<String>.from(res['sizes']  as List? ?? []);
    } catch (_) {
      _brands = [];
      _sizes  = [];
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
    return {'brands': _brands!, 'sizes': _sizes!};
  }

  Future<void> _pickBrand() async {
    final opts = await _fetchOptions();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _BrandSelectSheet(
        title: 'Select Brand — ${widget.item.name}',
        brands: opts['brands']!,
        onSelected: (v) => setState(() => _selectedBrand = v),
      ),
    );
  }

  Future<void> _pickSize() async {
    final opts = await _fetchOptions();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SelectSheet(
        title: 'Select Size — ${widget.item.name}',
        options: opts['sizes']!,
        onSelected: (v) => setState(() => _selectedSize = v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
            // Material thumbnail
            _MatThumbnail(name: widget.item.name),
            const SizedBox(width: 8),
            // Material name
            SizedBox(
              width: 130,
              child: Text(widget.item.name,
                  style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 12),
            // Unit
            SizedBox(
              width: 60,
              child: Text(widget.item.unit,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[600])),
            ),
            const SizedBox(width: 12),
            // Quantity placeholder
            SizedBox(
              width: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: Colors.grey.withAlpha(60), width: 1),
                ),
                alignment: Alignment.center,
                child: const Text('—',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ),
            const SizedBox(width: 12),
            // Brand select
            SizedBox(
              width: 100,
              child: _loadingOptions
                  ? _loadingCell()
                  : _selectedBrand == null
                      ? _selectBtn('Select', onTap: _pickBrand)
                      : _selectedChip(_selectedBrand!, onTap: _pickBrand),
            ),
            const SizedBox(width: 12),
            // Size select
            SizedBox(
              width: 100,
              child: _loadingOptions
                  ? _loadingCell()
                  : _selectedSize == null
                      ? _selectBtn('Select', onTap: _pickSize)
                      : _selectedChip(_selectedSize!, onTap: _pickSize),
            ),
          ]),
          ),
        ),
        if (!widget.isLast) const Divider(height: 1),
      ],
    );
  }

  Widget _loadingCell() => Container(
        height: 28,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: AppColors.primary),
        ),
      );

  Widget _selectBtn(String label, {required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(
                color: AppColors.primary.withAlpha(150), width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.arrow_drop_down,
                size: 14, color: AppColors.primary),
            const SizedBox(width: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      );

  Widget _selectedChip(String value, {required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(18),
            border: Border.all(
                color: AppColors.primary.withAlpha(80), width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.edit_outlined,
                size: 11, color: AppColors.primary),
          ]),
        ),
      );
}

// ─── Material thumbnail widget ───────────────────────────────────────────────

class _MatThumbnail extends StatelessWidget {
  final String name;
  const _MatThumbnail({required this.name});

  @override
  Widget build(BuildContext context) {
    final path = _matImagePath(name);
    if (path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(path,
            width: 32, height: 32,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder()),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold,
            color: AppColors.primary),
      ),
    );
  }
}

// ─── Brand select bottom-sheet (shows logo tiles) ─────────────────────────────

class _BrandSelectSheet extends StatelessWidget {
  final String title;
  final List<String> brands;
  final void Function(String) onSelected;
  const _BrandSelectSheet(
      {required this.title, required this.brands, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          if (brands.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No brands available for this material.',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: brands.map((brand) {
                final logo = _brandLogoPath(brand);
                return GestureDetector(
                  onTap: () {
                    onSelected(brand);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 90,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.primary.withAlpha(60)),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (logo != null)
                          Image.asset(logo,
                              height: 44, width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.business_outlined,
                                      size: 36, color: AppColors.primary))
                        else
                          const Icon(Icons.business_outlined,
                              size: 36, color: AppColors.primary),
                        const SizedBox(height: 6),
                        Text(brand,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Size select bottom-sheet (text chips) ────────────────────────────────────

class _SelectSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final void Function(String) onSelected;
  const _SelectSheet(
      {required this.title,
      required this.options,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          if (options.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No sizes available for this material.',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map((o) => ActionChip(
                        label: Text(o),
                        onPressed: () {
                          onSelected(o);
                          Navigator.pop(context);
                        },
                        backgroundColor:
                            AppColors.primary.withAlpha(15),
                        side: BorderSide(
                            color: AppColors.primary.withAlpha(80)),
                        labelStyle: const TextStyle(
                            color: AppColors.primary, fontSize: 13),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────

class _ProcessSection {
  final IconData icon;
  final String label;
  final Color color;
  final List<_MatItem> items;
  const _ProcessSection(
      {required this.icon,
      required this.label,
      required this.color,
      required this.items});
}

class _MatItem {
  final String name;
  final String unit;
  const _MatItem(this.name, this.unit);
}
