import 'package:flutter/material.dart';
import 'package:boq_frontend/features/it22172532/services/mongo_api_service.dart';
import 'package:boq_frontend/features/it22172532/utils/material_image_utils.dart';

/// Full-CRUD management screen for the global materials library.
/// Each material has a name, a list of brands, and a list of sizes.
class MaterialLibraryScreen extends StatefulWidget {
  const MaterialLibraryScreen({super.key});

  @override
  State<MaterialLibraryScreen> createState() => _MaterialLibraryScreenState();
}

class _MaterialLibraryScreenState extends State<MaterialLibraryScreen> {
  final _api = MongoApiService();
  List<Map<String, dynamic>> _materials = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _api.loadToken();
      final raw = await _api.getAllMaterials();
      setState(() {
        _materials = raw.cast<Map<String, dynamic>>();
        _loading   = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _delete(Map<String, dynamic> mat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Material'),
        content: Text('Delete "${mat['name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteMaterial(mat['_id'] as String);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MaterialFormSheet(
        onSaved: (name, brands, sizes) async {
          await _api.createMaterial(name: name, brands: brands, sizes: sizes);
          _load();
        },
      ),
    );
  }

  void _openEdit(Map<String, dynamic> mat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MaterialFormSheet(
        initialName:   mat['name']   as String? ?? '',
        initialBrands: List<String>.from(mat['brands'] as List? ?? []),
        initialSizes:  List<String>.from(mat['sizes']  as List? ?? []),
        editMode: true,
        onSaved: (name, brands, sizes) async {
          await _api.updateMaterial(
            mat['_id'] as String,
            name:   name,
            brands: brands,
            sizes:  sizes,
          );
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Material Library',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        tooltip: 'Add Material',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _materials.isEmpty
                  ? _EmptyView(onAdd: _openAdd)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                      itemCount: _materials.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final mat = _materials[i];
                        final brands =
                            List<String>.from(mat['brands'] as List? ?? []);
                        final sizes =
                            List<String>.from(mat['sizes'] as List? ?? []);
                        return _MaterialCard(
                          name:    mat['name'] as String? ?? '',
                          brands:  brands,
                          sizes:   sizes,
                          onEdit:  () => _openEdit(mat),
                          onDelete: () => _delete(mat),
                        );
                      },
                    ),
    );
  }
}

// ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
// Material card
// ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

class _MaterialCard extends StatelessWidget {
  final String name;
  final List<String> brands;
  final List<String> sizes;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MaterialCard({
    required this.name,
    required this.brands,
    required this.sizes,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imgPath = matImagePath(name);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding:
                const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(children: [
              // Material thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imgPath != null
                    ? Image.asset(imgPath,
                        width: 40, height: 40, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _iconBox())
                    : _iconBox(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: Color(0xFF1565C0)),
                onPressed: onEdit,
                tooltip: 'Edit',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.red),
                onPressed: onDelete,
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
            ]),
          ),
          const Divider(height: 1, indent: 14, endIndent: 14),

          // Brands row (with logos)
          _BrandChipRow(brands: brands),

          // Sizes row
          _ChipRow(label: 'Sizes', items: sizes,
              color: const Color(0xFF00695C)),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _iconBox() => Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0).withAlpha(18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory_2_outlined,
            size: 20, color: Color(0xFF1565C0)),
      );
}

class _BrandChipRow extends StatelessWidget {
  final List<String> brands;
  const _BrandChipRow({required this.brands});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text('Brands',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
          ),
          Expanded(
            child: brands.isEmpty
                ? Text('ΓÇö',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[400]))
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: brands.map((brand) {
                      final logo = brandLogoPath(brand);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withAlpha(12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF1565C0).withAlpha(60),
                              width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (logo != null) ...[  
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: Image.asset(logo,
                                    width: 20, height: 20,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox.shrink()),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(brand,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF1565C0))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final String label;
  final List<String> items;
  final Color color;
  const _ChipRow(
      {required this.label, required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
          ),
          Expanded(
            child: items.isEmpty
                ? Text('ΓÇö',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[400]))
                : Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: items
                        .map((v) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withAlpha(18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: color.withAlpha(60), width: 1),
                              ),
                              child: Text(v,
                                  style: TextStyle(
                                      fontSize: 11, color: color)),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
// Add / Edit form bottom sheet
// ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

class _MaterialFormSheet extends StatefulWidget {
  final String initialName;
  final List<String> initialBrands;
  final List<String> initialSizes;
  final bool editMode;
  final Future<void> Function(
      String name, List<String> brands, List<String> sizes) onSaved;

  const _MaterialFormSheet({
    this.initialName   = '',
    this.initialBrands = const [],
    this.initialSizes  = const [],
    this.editMode      = false,
    required this.onSaved,
  });

  @override
  State<_MaterialFormSheet> createState() => _MaterialFormSheetState();
}

class _MaterialFormSheetState extends State<_MaterialFormSheet> {
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _sizeCtrl  = TextEditingController();
  late List<String> _brands;
  late List<String> _sizes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialName;
    _brands = List.from(widget.initialBrands);
    _sizes  = List.from(widget.initialSizes);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _sizeCtrl.dispose();
    super.dispose();
  }

  void _addBrand() {
    final v = _brandCtrl.text.trim();
    if (v.isNotEmpty && !_brands.contains(v)) {
      setState(() { _brands.add(v); _brandCtrl.clear(); });
    }
  }

  void _addSize() {
    final v = _sizeCtrl.text.trim();
    if (v.isNotEmpty && !_sizes.contains(v)) {
      setState(() { _sizes.add(v); _sizeCtrl.clear(); });
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Material name required')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSaved(name, _brands, _sizes);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.editMode ? 'Edit Material' : 'Add Material',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Material name
            TextField(
              controller: _nameCtrl,
              enabled: !widget.editMode,
              decoration: InputDecoration(
                labelText: 'Material Name *',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                filled: widget.editMode,
                fillColor: widget.editMode
                    ? Colors.grey[100]
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // Brands
            _ChipEditor(
              label: 'Brands',
              color: const Color(0xFF1565C0),
              chips: _brands,
              controller: _brandCtrl,
              onAdd: _addBrand,
              onRemove: (v) => setState(() => _brands.remove(v)),
            ),
            const SizedBox(height: 14),

            // Sizes
            _ChipEditor(
              label: 'Sizes',
              color: const Color(0xFF00695C),
              chips: _sizes,
              controller: _sizeCtrl,
              onAdd: _addSize,
              onRemove: (v) => setState(() => _sizes.remove(v)),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(widget.editMode ? 'Save Changes' : 'Add Material'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ΓöÇΓöÇΓöÇ Tag/chip editor with text field + add button ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

class _ChipEditor extends StatelessWidget {
  final String label;
  final Color color;
  final List<String> chips;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final void Function(String) onRemove;

  const _ChipEditor({
    required this.label,
    required this.color,
    required this.chips,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Type and tap +',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                isDense: true,
              ),
              onSubmitted: (_) => onAdd(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              minimumSize: const Size(44, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: EdgeInsets.zero,
            ),
            child: const Icon(Icons.add, size: 20),
          ),
        ]),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips
                .map((v) => InputChip(
                      label: Text(v,
                          style: TextStyle(fontSize: 12, color: color)),
                      onDeleted: () => onRemove(v),
                      deleteIconColor: color,
                      backgroundColor: color.withAlpha(18),
                      side: BorderSide(color: color.withAlpha(60)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

// ΓöÇΓöÇΓöÇ Empty / Error states ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('No materials yet',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add First Material'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
