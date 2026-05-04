class Endpoints {
  static const paintPredict = '/paint/predict';
  static const skimcoatPredict = '/skimcoat/predict';
  static const woodPredict = '/wood/predict';
  // new endpoint for wood type classification (image upload)
  static const woodTypePredict = '/wood-type/type-predict';
  static const woodDefectPredict = '/wood-defects/predict';

  // feedback loop endpoints
  static const feedbackSyncAll = '/feedback/sync/all';
  static String feedbackSync(String dataset) => '/feedback/sync/$dataset';
}