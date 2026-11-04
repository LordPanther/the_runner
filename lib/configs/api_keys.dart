class ApiKeys {
  // Free key from https://cloud.maptiler.com (you can reuse TownPost's).
  static const String mapTiler = 'wncLv8VDJKwGmEJE2EsC';

  ///Singleton factory
  static final ApiKeys _instance = ApiKeys._internal();

  factory ApiKeys() {
    return _instance;
  }

  ApiKeys._internal();
}