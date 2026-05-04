/// Building Plan Models
/// All data structures for the Building Plan Analyzer feature.

// ─────────────────────────────────────────────────────────────────────────────
// Plan Metadata
// ─────────────────────────────────────────────────────────────────────────────

class PlanMetadata {
  final String planType;
  final String totalBuiltUpArea;
  final String totalCarpetArea;
  final String plotArea;
  final String scale;
  final String orientation;
  final String floors;

  const PlanMetadata({
    required this.planType,
    required this.totalBuiltUpArea,
    required this.totalCarpetArea,
    required this.plotArea,
    required this.scale,
    required this.orientation,
    required this.floors,
  });

  factory PlanMetadata.fromJson(Map<String, dynamic> json) => PlanMetadata(
        planType: json['plan_type'] ?? 'Floor Plan',
        totalBuiltUpArea: json['total_built_up_area'] ?? 'N/A',
        totalCarpetArea: json['total_carpet_area'] ?? 'N/A',
        plotArea: json['plot_area'] ?? 'N/A',
        scale: json['scale'] ?? 'N/A',
        orientation: json['orientation'] ?? 'N/A',
        floors: json['floors']?.toString() ?? '1',
      );

  factory PlanMetadata.empty() => const PlanMetadata(
        planType: 'Floor Plan',
        totalBuiltUpArea: 'N/A',
        totalCarpetArea: 'N/A',
        plotArea: 'N/A',
        scale: 'N/A',
        orientation: 'N/A',
        floors: '1',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Room Measurements
// ─────────────────────────────────────────────────────────────────────────────

class RoomMeasurements {
  final String length;
  final String width;
  final String height;
  final String area;
  final String perimeter;
  final String volume;

  const RoomMeasurements({
    required this.length,
    required this.width,
    required this.height,
    required this.area,
    required this.perimeter,
    required this.volume,
  });

  factory RoomMeasurements.fromJson(Map<String, dynamic> json) =>
      RoomMeasurements(
        length: json['length'] ?? 'N/A',
        width: json['width'] ?? 'N/A',
        height: json['height'] ?? "10'-0\"",
        area: json['area'] ?? 'N/A',
        perimeter: json['perimeter'] ?? 'N/A',
        volume: json['volume'] ?? 'N/A',
      );

  double get areaValue {
    final s = area.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(s) ?? 0.0;
  }

  double get perimeterValue {
    final s = perimeter.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(s) ?? 0.0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Building Part (room, corridor, kitchen, etc.)
// ─────────────────────────────────────────────────────────────────────────────

class BuildingPart {
  final String id;
  final String partName;
  final String category;
  final RoomMeasurements measurements;
  final List<BOQMaterialItem> boqMaterials;

  const BuildingPart({
    required this.id,
    required this.partName,
    required this.category,
    required this.measurements,
    required this.boqMaterials,
  });

  factory BuildingPart.fromJson(Map<String, dynamic> json) {
    // Parse BOQ materials from backend (flat list)
    final rawMaterials = json['materials'] as List<dynamic>? ?? [];
    final boqMats = rawMaterials
        .map((m) => BOQMaterialItem.fromJson(m as Map<String, dynamic>))
        .toList();

    return BuildingPart(
      id: json['id'] ?? 'part_${json['part_name']}',
      partName: json['part_name'] ?? 'Unknown',
      category: json['category'] ?? 'room',
      measurements: RoomMeasurements.fromJson(
          (json['measurements'] as Map<String, dynamic>?) ?? {}),
      boqMaterials: boqMats,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Door / Window
// ─────────────────────────────────────────────────────────────────────────────

class DoorInfo {
  final String id;
  final String location;
  final String width;
  final String height;
  final String type;

  const DoorInfo({
    required this.id,
    required this.location,
    required this.width,
    required this.height,
    required this.type,
  });

  factory DoorInfo.fromJson(Map<String, dynamic> json) => DoorInfo(
        id: json['id'] ?? '',
        location: json['location'] ?? '',
        width: json['width'] ?? 'N/A',
        height: json['height'] ?? 'N/A',
        type: json['type'] ?? 'Wooden Door',
      );
}

class WindowInfo {
  final String id;
  final String location;
  final String width;
  final String height;
  final String type;

  const WindowInfo({
    required this.id,
    required this.location,
    required this.width,
    required this.height,
    required this.type,
  });

  factory WindowInfo.fromJson(Map<String, dynamic> json) => WindowInfo(
        id: json['id'] ?? '',
        location: json['location'] ?? '',
        width: json['width'] ?? 'N/A',
        height: json['height'] ?? 'N/A',
        type: json['type'] ?? 'Sliding Window',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// BOQ Material
// ─────────────────────────────────────────────────────────────────────────────

class BOQMaterialItem {
  final String name;
  final double quantity;
  final String unit;
  final bool wastageIncluded;
  bool isSelected;

  BOQMaterialItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.wastageIncluded,
    this.isSelected = false,
  });

  factory BOQMaterialItem.fromJson(Map<String, dynamic> json) =>
      BOQMaterialItem(
        name: json['name'] ?? 'Unknown',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit'] ?? 'unit',
        wastageIncluded: json['wastage_included'] ?? false,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Full Plan Analysis Result
// ─────────────────────────────────────────────────────────────────────────────

class PlanAnalysisResult {
  final bool success;
  final String filename;
  final PlanMetadata metadata;
  final List<BuildingPart> buildingParts;
  final List<DoorInfo> doors;
  final List<WindowInfo> windows;

  const PlanAnalysisResult({
    required this.success,
    required this.filename,
    required this.metadata,
    required this.buildingParts,
    required this.doors,
    required this.windows,
  });

  int get totalRooms => buildingParts
      .where((p) => ['room', 'bedroom', 'living', 'dining', 'kitchen']
          .contains(p.category.toLowerCase()))
      .length;

  int get totalBedrooms => buildingParts
      .where((p) => p.category.toLowerCase().contains('bedroom') ||
          p.partName.toLowerCase().contains('bedroom'))
      .length;

  int get totalBathrooms => buildingParts
      .where((p) =>
          p.category.toLowerCase().contains('bathroom') ||
          p.category.toLowerCase().contains('toilet') ||
          p.partName.toLowerCase().contains('bath') ||
          p.partName.toLowerCase().contains('toilet') ||
          p.partName.toLowerCase().contains('wc'))
      .length;

  factory PlanAnalysisResult.fromJson(Map<String, dynamic> json) {
    final analysis = json['analysis'] as Map<String, dynamic>? ?? {};
    final boqData = analysis['boq'] as Map<String, dynamic>? ?? {};
    final boqItems =
        List<Map<String, dynamic>>.from(boqData['items'] as List? ?? []);

    // Build a lookup: partName → list of BOQ materials
    final Map<String, List<BOQMaterialItem>> boqByPart = {};
    for (final item in boqItems) {
      final partName = item['part_name'] as String? ?? '';
      final mats = List<Map<String, dynamic>>.from(
          item['materials'] as List? ?? []);
      boqByPart[partName] =
          mats.map((m) => BOQMaterialItem.fromJson(m)).toList();
    }

    // Parse building parts and attach BOQ
    final rawParts = List<Map<String, dynamic>>.from(
        analysis['building_parts'] as List? ?? []);
    final parts = rawParts.map((p) {
      final partName = p['part_name'] as String? ?? '';
      // Attach matching BOQ items
      final enriched = Map<String, dynamic>.from(p);
      enriched['materials'] = boqByPart[partName]
              ?.map((m) => {
                    'name': m.name,
                    'quantity': m.quantity,
                    'unit': m.unit,
                    'wastage_included': m.wastageIncluded,
                  })
              .toList() ??
          [];
      return BuildingPart.fromJson(enriched);
    }).toList();

    final rawDoors =
        List<Map<String, dynamic>>.from(analysis['doors'] as List? ?? []);
    final rawWindows =
        List<Map<String, dynamic>>.from(analysis['windows'] as List? ?? []);

    return PlanAnalysisResult(
      success: json['success'] == true,
      filename: json['filename'] ?? '',
      metadata: PlanMetadata.fromJson(
          (analysis['plan_metadata'] as Map<String, dynamic>?) ?? {}),
      buildingParts: parts,
      doors: rawDoors.map((d) => DoorInfo.fromJson(d)).toList(),
      windows: rawWindows.map((w) => WindowInfo.fromJson(w)).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Final BOQ Report Entry
// ─────────────────────────────────────────────────────────────────────────────

class FinalBOQEntry {
  final String partName;
  final String materialName;
  final double quantity;
  final String unit;

  const FinalBOQEntry({
    required this.partName,
    required this.materialName,
    required this.quantity,
    required this.unit,
  });
}
