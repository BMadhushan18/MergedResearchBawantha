class AppApi {
  AppApi._();

  static const String threeDFrontendUrl = String.fromEnvironment(
    'THREED_FRONTEND_URL',
    defaultValue: 'http://127.0.0.1:8014/3d/index.html',
  );
}
