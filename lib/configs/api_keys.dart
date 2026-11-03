class ApiKeys {
  // Free key from https://cloud.maptiler.com (you can reuse TownPost's).
  static const String mapTiler = 'YOUR_MAPTILER_KEY';

  ///Singleton factory
  static final ApiKeys _instance = ApiKeys._internal();

  factory ApiKeys() {
    return _instance;
  }

  ApiKeys._internal();
}