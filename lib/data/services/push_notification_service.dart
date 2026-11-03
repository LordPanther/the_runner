// lib/data/services/push_notification_service.dart

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:the_runner/app_view.dart';
import 'package:the_runner/configs/router.dart';
import 'package:the_runner/data/repositories/repository.dart';

/// Handles the full push notification lifecycle: permission request,
/// obtaining and saving the FCM token (plus keeping it current if it
/// refreshes), and tap-to-navigate across all three states a
/// notification can arrive in:
///   - foreground (app open) - FCM delivers this as silent data only,
///     so a local notification is shown manually to make it visible
///   - backgrounded (app open but not focused) - OS shows it
///     automatically, tapping it fires onMessageOpenedApp
///   - terminated (app fully closed) - OS shows it automatically,
///     tapping it launches the app fresh; getInitialMessage() is the
///     only way to learn that's how the app was opened
class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'runner_default';
  static const _channelName = 'The Runner Notifications';

  static bool _oneTimeSetupDone = false;

  /// Call after every successful login, not just the first one - a
  /// device that switches between accounts (logout/login, without the
  /// app process restarting) needs to save a FRESH token for WHICHEVER
  /// account just authenticated, not only the first one ever seen this
  /// session.
  ///
  /// NOTE: this used to guard the entire method body (including the
  /// token save) behind a single static flag - correct for preventing
  /// duplicate stream listener registration, but wrong for the token
  /// save specifically. On a single device switching between accounts,
  /// this meant only the FIRST account to ever log in during that app
  /// process got a token saved at all - every account after that
  /// silently got nothing, since the guard made initialize() return
  /// immediately without ever reaching _saveCurrentToken(). Split below
  /// so the one-time setup (listeners, local notifications plugin)
  /// stays guarded, but the token save runs on every call.
  Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    if (!_oneTimeSetupDone) {
      _oneTimeSetupDone = true;
      await _setupLocalNotifications();
      _registerListeners();
      await _checkInitialMessage();
    }

    // Runs on every call, deliberately outside the one-time guard above -
    // this is the specific line that needs to fire for every account
    // that logs in, not just the first one.
    await _saveCurrentToken();
  }

  void _registerListeners() {
    // FCM tokens can change (app reinstall, data clear, etc.) - without
    // this, a stale token would silently stop receiving pushes with no
    // visible error anywhere.
    _messaging.onTokenRefresh.listen((newToken) {
      AppRepository.notificationRepository.saveFcmToken(newToken);
    });

    // Foreground: FCM delivers silently, no OS banner - show one
    // manually so a push arriving while the app's open looks the same
    // as one arriving while it's closed.
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Tapped while backgrounded (app was open, just not focused).
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data);
    });
  }

  Future<void> _checkInitialMessage() async {
    // App was fully closed and got launched BY tapping a notification -
    // this is the only way to detect that specific launch path.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage.data);
    }
  }

  Future<void> _saveCurrentToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await AppRepository.notificationRepository.saveFcmToken(token);
    }
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('ic_notification');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotifications.initialize(
      initSettings,
      // Tapped while the app was in the foreground - this is a
      // DIFFERENT tap path than onMessageOpenedApp above, since this
      // notification was shown by flutter_local_notifications, not the
      // OS directly.
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null) return;
        final data = Map<String, dynamic>.from(jsonDecode(response.payload!));
        _handleNotificationTap(data);
      },
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? message.data['title'],
      message.notification?.body ?? message.data['body'],
      details,
      // FCM data payload values are always strings at the wire level -
      // jsonEncode/decode round-trips this cleanly through
      // flutter_local_notifications' String-only payload field.
      payload: jsonEncode(message.data),
    );
  }

  /// Every errand notification carries an errand_id and opens that
  /// errand. Anything else (or a missing id) falls back to the
  /// notifications list.
  void _handleNotificationTap(Map<String, dynamic> data) {
    final navigator = AppView.navigatorKey.currentState;
    if (navigator == null) return;

    final errandId = data['errand_id'];
    if (errandId != null) {
      navigator.pushNamed(AppRouter.errandDetail, arguments: errandId);
    } else {
      navigator.pushNamed(AppRouter.notifications);
    }
  }
}