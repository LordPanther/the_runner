import 'package:the_runner/data/repositories/auth/firebase_auth_repository.dart';
import 'package:the_runner/data/repositories/errand/firebase_errand_repository.dart';
import 'package:the_runner/data/repositories/location/firebase_location_repository.dart';
import 'package:the_runner/data/repositories/notification/firebase_notification_repository.dart';

class AppRepository {
  static final authRepository = FirebaseAuthRepository();
  static final errandRepository = FirebaseErrandRepository();
  static final locationRepository = FirebaseLocationRepository();
  static final notificationRepository = FirebaseNotificationRepository();

  static final AppRepository _instance = AppRepository._internal();

  factory AppRepository() {
    return _instance;
  }

  AppRepository._internal();
}
