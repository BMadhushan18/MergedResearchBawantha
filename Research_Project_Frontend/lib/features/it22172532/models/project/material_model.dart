
// --- Material Size ---------------------------------------------------------
class MaterialSize {
  final String sizeId;
  final String label;

  MaterialSize({required this.sizeId, required this.label});

  Map<String, dynamic> toMap() => {'sizeId': sizeId, 'label': label};

  factory MaterialSize.fromMap(Map<String, dynamic> d) =>
      MaterialSize(sizeId: d['sizeId'] ?? '', label: d['label'] ?? '');
}

// --- Material Brand ---------------------------------------------------------
class MaterialBrand {
  final String brandId;
  final String brandName;

  MaterialBrand({required this.brandId, required this.brandName});

  Map<String, dynamic> toMap() =>
      {'brandId': brandId, 'brandName': brandName};

  factory MaterialBrand.fromMap(Map<String, dynamic> d) => MaterialBrand(
      brandId: d['brandId'] ?? '', brandName: d['brandName'] ?? '');
}

// --- Material ----------------------------------------------------------------
class MaterialModel {
  final String materialId;
  final String materialName;
  final String category;
  final String baseUnit;
  final List<MaterialSize> allowedSizes;
  final List<MaterialBrand> allowedBrands;
  final List<String> specsGrades;
  final List<String> notes;

  MaterialModel({
    required this.materialId,
    required this.materialName,
    required this.category,
    this.baseUnit = 'bag',
    List<MaterialSize>? allowedSizes,
    List<MaterialBrand>? allowedBrands,
    List<String>? specsGrades,
    List<String>? notes,
  })  : allowedSizes = allowedSizes ?? [],
        allowedBrands = allowedBrands ?? [],
        specsGrades = specsGrades ?? [],
        notes = notes ?? [];

  Map<String, dynamic> toMap() => {
        'materialId': materialId,
        'materialName': materialName,
        'category': category,
        'baseUnit': baseUnit,
        'allowedSizes': allowedSizes.map((s) => s.toMap()).toList(),
        'allowedBrands': allowedBrands.map((b) => b.toMap()).toList(),
        'specsGrades': specsGrades,
        'notes': notes,
      };

  factory MaterialModel.fromMap(Map<String, dynamic> d) => MaterialModel(
        materialId: d['materialId'] ?? '',
        materialName: d['materialName'] ?? '',
        category: d['category'] ?? '',
        baseUnit: d['baseUnit'] ?? 'bag',
        allowedSizes: (d['allowedSizes'] as List<dynamic>?)
                ?.map((s) => MaterialSize.fromMap(s))
                .toList() ??
            [],
        allowedBrands: (d['allowedBrands'] as List<dynamic>?)
                ?.map((b) => MaterialBrand.fromMap(b))
                .toList() ??
            [],
        specsGrades: List<String>.from(d['specsGrades'] ?? []),
        notes: List<String>.from(d['notes'] ?? []),
      );

  // Firestore doc reference helper
  static MaterialModel cementTemplate() => MaterialModel(
        materialId: 'MAT-CEMENT',
        materialName: 'Cement',
        category: 'Concrete & Masonry',
        baseUnit: 'bag',
        allowedSizes: [
          MaterialSize(sizeId: 'SIZE-50KG', label: '50kg bag'),
          MaterialSize(sizeId: 'SIZE-25KG', label: '25kg bag'),
        ],
        allowedBrands: [
          MaterialBrand(brandId: 'BR-INSEE', brandName: 'INSEE'),
          MaterialBrand(brandId: 'BR-TOKYO', brandName: 'TOKYO'),
        ],
        specsGrades: ['OPC', 'PPC'],
      );
}
