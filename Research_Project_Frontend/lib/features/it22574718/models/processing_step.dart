enum ProcessingStepType {
  createProject,
  captureVideo,
  extractFrames,
  featureMatching,
  pointCloudGeneration,
  meshCreation,
  completed,
}

class ProcessingStep {
  final ProcessingStepType type;
  final String title;
  final String description;
  final ProcessingStepStatus status;
  final double progress;
  final String? outputPath;
  final String? outputUrl;
  final String? errorMessage;

  ProcessingStep({
    required this.type,
    required this.title,
    required this.description,
    this.status = ProcessingStepStatus.pending,
    this.progress = 0.0,
    this.outputPath,
    this.outputUrl,
    this.errorMessage,
  });

  ProcessingStep copyWith({
    ProcessingStepType? type,
    String? title,
    String? description,
    ProcessingStepStatus? status,
    double? progress,
    String? outputPath,
    String? outputUrl,
    String? errorMessage,
  }) {
    return ProcessingStep(
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      outputPath: outputPath ?? this.outputPath,
      outputUrl: outputUrl ?? this.outputUrl,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  static List<ProcessingStep> getDefaultSteps() {
    return [
      ProcessingStep(
        type: ProcessingStepType.createProject,
        title: 'Create Project',
        description: 'Set up a new 3D scanning project',
      ),
      ProcessingStep(
        type: ProcessingStepType.captureVideo,
        title: 'Capture Video',
        description: 'Record a 360° video of your object',
      ),
      ProcessingStep(
        type: ProcessingStepType.extractFrames,
        title: 'Extract Frames',
        description: 'Extract images from your video',
      ),
      ProcessingStep(
        type: ProcessingStepType.featureMatching,
        title: 'Feature Matching',
        description: 'Identify and match features across images',
      ),
      ProcessingStep(
        type: ProcessingStepType.pointCloudGeneration,
        title: 'Point Cloud',
        description: 'Generate 3D point cloud from matched features',
      ),
      ProcessingStep(
        type: ProcessingStepType.meshCreation,
        title: 'Create Mesh',
        description: 'Create final 3D mesh model',
      ),
    ];
  }
}

enum ProcessingStepStatus {
  pending,
  inProgress,
  completed,
  failed,
}
