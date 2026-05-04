class Recon3DJobStatus {
  final String jobId;
  final String status;
  final String stage;
  final int progress;
  final String message;
  final String error;
  final int frameCount;
  final String profile;
  final String artifactType;
  final String modelUrl;
  final String downloadUrl;
  final String viewerUrl;
  final String pointCloudUrl;

  const Recon3DJobStatus({
    required this.jobId,
    required this.status,
    required this.stage,
    required this.progress,
    required this.message,
    required this.error,
    required this.frameCount,
    required this.profile,
    required this.artifactType,
    required this.modelUrl,
    required this.downloadUrl,
    required this.viewerUrl,
    required this.pointCloudUrl,
  });

  factory Recon3DJobStatus.fromJson(Map<String, dynamic> j) => Recon3DJobStatus(
        jobId:        j['job_id']        as String? ?? '',
        status:       j['status']        as String? ?? '',
        stage:        j['stage']         as String? ?? '',
        progress:     (j['progress']     as num?)?.toInt() ?? 0,
        message:      j['message']       as String? ?? '',
        error:        j['error']         as String? ?? '',
        frameCount:   (j['frame_count']  as num?)?.toInt() ?? 0,
        profile:      j['profile']       as String? ?? 'fast',
        artifactType: j['artifact_type'] as String? ?? '',
        modelUrl:     j['model_url']     as String? ?? '',
        downloadUrl:  j['download_url']  as String? ?? '',
        viewerUrl:    j['viewer_url']    as String? ?? '',
        pointCloudUrl: j['point_cloud_url'] as String? ?? '',
      );

  bool get isCompleted => status == 'completed';
  bool get isFailed    => status == 'failed';
  bool get isRunning   => !isCompleted && !isFailed;
}
