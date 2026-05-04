class Recon3DProgressPlan {
  final String taskName;
  final String taskType;
  final String description;
  final double plannedLengthM;
  final double plannedHeightM;
  final double plannedThicknessM;
  final double plannedAreaM2;
  final double plannedVolumeM3;
  final String humanSummary;

  const Recon3DProgressPlan({
    required this.taskName,
    required this.taskType,
    required this.description,
    required this.plannedLengthM,
    required this.plannedHeightM,
    required this.plannedThicknessM,
    required this.plannedAreaM2,
    required this.plannedVolumeM3,
    required this.humanSummary,
  });

  factory Recon3DProgressPlan.fromJson(Map<String, dynamic> json) =>
      Recon3DProgressPlan(
        taskName:          json['task_name']           as String? ?? '',
        taskType:          json['task_type']           as String? ?? '',
        description:       json['description']         as String? ?? '',
        plannedLengthM:    (json['planned_length_m']    as num?)?.toDouble() ?? 0,
        plannedHeightM:    (json['planned_height_m']    as num?)?.toDouble() ?? 0,
        plannedThicknessM: (json['planned_thickness_m'] as num?)?.toDouble() ?? 0,
        plannedAreaM2:     (json['planned_area_m2']     as num?)?.toDouble() ?? 0,
        plannedVolumeM3:   (json['planned_volume_m3']   as num?)?.toDouble() ?? 0,
        humanSummary:      json['human_summary']        as String? ?? '',
      );
}

class Recon3DProgressSnapshot {
  final String fileName;
  final double progressPercent;
  final double volumeProgressPercent;
  final double builtFaceAreaM2;
  final double builtVolumeM3;
  final String progressBand;
  final double confidence;
  final Map<String, dynamic> estimatedDimensionsM;
  final Map<String, dynamic> rawExtentsM;

  const Recon3DProgressSnapshot({
    required this.fileName,
    required this.progressPercent,
    required this.volumeProgressPercent,
    required this.builtFaceAreaM2,
    required this.builtVolumeM3,
    required this.progressBand,
    required this.confidence,
    required this.estimatedDimensionsM,
    required this.rawExtentsM,
  });

  factory Recon3DProgressSnapshot.fromJson(Map<String, dynamic> json) =>
      Recon3DProgressSnapshot(
        fileName:              json['file_name']              as String? ?? '',
        progressPercent:       (json['progress_percent']      as num?)?.toDouble() ?? 0,
        volumeProgressPercent: (json['volume_progress_percent'] as num?)?.toDouble() ?? 0,
        builtFaceAreaM2:       (json['built_face_area_m2']    as num?)?.toDouble() ?? 0,
        builtVolumeM3:         (json['built_volume_m3']       as num?)?.toDouble() ?? 0,
        progressBand:          json['progress_band']          as String? ?? '',
        confidence:            (json['confidence']            as num?)?.toDouble() ?? 0,
        estimatedDimensionsM:  (json['estimated_dimensions_m'] as Map?)?.cast<String, dynamic>() ?? const {},
        rawExtentsM:           (json['raw_extents_m']         as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

class Recon3DProgressDelta {
  final double progressPercentPoints;
  final double addedAreaM2;
  final double addedVolumeM3;
  final double remainingAreaM2;
  final double remainingVolumeM3;

  const Recon3DProgressDelta({
    required this.progressPercentPoints,
    required this.addedAreaM2,
    required this.addedVolumeM3,
    required this.remainingAreaM2,
    required this.remainingVolumeM3,
  });

  factory Recon3DProgressDelta.fromJson(Map<String, dynamic> json) =>
      Recon3DProgressDelta(
        progressPercentPoints: (json['progress_percent_points'] as num?)?.toDouble() ?? 0,
        addedAreaM2:           (json['added_area_m2']           as num?)?.toDouble() ?? 0,
        addedVolumeM3:         (json['added_volume_m3']         as num?)?.toDouble() ?? 0,
        remainingAreaM2:       (json['remaining_area_m2']       as num?)?.toDouble() ?? 0,
        remainingVolumeM3:     (json['remaining_volume_m3']     as num?)?.toDouble() ?? 0,
      );
}

class Recon3DProgressSummary {
  final String headline;
  final double completionPercent;
  final double confidence;
  final List<String> humanReadable;

  const Recon3DProgressSummary({
    required this.headline,
    required this.completionPercent,
    required this.confidence,
    required this.humanReadable,
  });

  factory Recon3DProgressSummary.fromJson(Map<String, dynamic> json) =>
      Recon3DProgressSummary(
        headline:          json['headline']           as String? ?? '',
        completionPercent: (json['completion_percent'] as num?)?.toDouble() ?? 0,
        confidence:        (json['confidence']         as num?)?.toDouble() ?? 0,
        humanReadable:     (json['human_readable'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

class Recon3DProgressComparison {
  final String taskName;
  final String taskType;
  final Recon3DProgressPlan plan;
  final Recon3DProgressSnapshot yesterday;
  final Recon3DProgressSnapshot today;
  final Recon3DProgressDelta delta;
  final Recon3DProgressSummary summary;

  const Recon3DProgressComparison({
    required this.taskName,
    required this.taskType,
    required this.plan,
    required this.yesterday,
    required this.today,
    required this.delta,
    required this.summary,
  });

  factory Recon3DProgressComparison.fromJson(Map<String, dynamic> json) =>
      Recon3DProgressComparison(
        taskName:  json['task_name']  as String? ?? '',
        taskType:  json['task_type']  as String? ?? '',
        plan:      Recon3DProgressPlan.fromJson((json['plan'] as Map?)?.cast<String, dynamic>() ?? {}),
        yesterday: Recon3DProgressSnapshot.fromJson((json['yesterday'] as Map?)?.cast<String, dynamic>() ?? {}),
        today:     Recon3DProgressSnapshot.fromJson((json['today'] as Map?)?.cast<String, dynamic>() ?? {}),
        delta:     Recon3DProgressDelta.fromJson((json['delta'] as Map?)?.cast<String, dynamic>() ?? {}),
        summary:   Recon3DProgressSummary.fromJson((json['summary'] as Map?)?.cast<String, dynamic>() ?? {}),
      );
}
