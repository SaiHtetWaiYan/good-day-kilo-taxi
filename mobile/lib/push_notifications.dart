import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api.dart';

const _firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
const _firebaseSenderId = String.fromEnvironment(
  'FIREBASE_MESSAGING_SENDER_ID',
);
const _firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

class PushNotifications {
  static final _local = FlutterLocalNotificationsPlugin();
  static StreamSubscription<String>? _tokenRefresh;
  static bool _initialized = false;

  static bool get configured =>
      _firebaseApiKey.isNotEmpty &&
      _firebaseAppId.isNotEmpty &&
      _firebaseSenderId.isNotEmpty &&
      _firebaseProjectId.isNotEmpty;

  static Future<void> initialize() async {
    if (!configured || _initialized) return;
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: _firebaseApiKey,
        appId: _firebaseAppId,
        messagingSenderId: _firebaseSenderId,
        projectId: _firebaseProjectId,
      ),
    );
    const channel = AndroidNotificationChannel(
      'taxi_bookings',
      'Taxi booking updates',
      description: 'New ride requests and booking status updates',
      importance: Importance.max,
      playSound: true,
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    FirebaseMessaging.onMessage.listen(_showForegroundMessage);
    _initialized = true;
  }

  static Future<void> register(Api api) async {
    if (!configured) return;
    try {
      await initialize();
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _sendToken(api, token);
      await _tokenRefresh?.cancel();
      _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen(
        (value) => _sendToken(api, value),
      );
    } catch (_) {
      // Booking remains usable if Firebase or Google Play Services is offline.
    }
  }

  static Future<void> unregister(Api api) async {
    if (!configured) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await api.delete('/device-tokens', {'token': token});
      await _tokenRefresh?.cancel();
      _tokenRefresh = null;
    } catch (_) {}
  }

  static Future<void> _sendToken(Api api, String token) =>
      api.post('/device-tokens', {'token': token, 'platform': 'android'});

  static Future<void> _showForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    final notificationId =
        (message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString())
            .hashCode &
        0x7fffffff;
    await _local.show(
      id: notificationId,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'taxi_bookings',
          'Taxi booking updates',
          channelDescription: 'New ride requests and booking status updates',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data['booking_id'],
    );
  }
}
