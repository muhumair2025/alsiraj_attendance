import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize notifications
  Future<void> initialize() async {
    // Request permission for notifications
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
      
      // Get FCM token and save to Firestore
      await _saveFCMToken();
      
      // Listen to token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen(_updateFCMToken);
      
      // Subscribe to topic based on user role
      await _subscribeToTopics();
    } else {
      print('User denied notification permission');
    }

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Notification tapped: ${response.payload}');
      },
    );

    // Create Android notification channel (required for Android 8.0+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'class_notifications',
      'Class Notifications',
      description: 'Notifications for class attendance and announcements',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    print('✅ Notification channel created');

    // Handle foreground messages (when app is open)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages (when app is in background, user taps notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Check if app was opened from a terminated state via notification
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  // Subscribe to topics based on user role
  Future<void> _subscribeToTopics() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final role = userDoc.data()?['role'] ?? 'student';
          
          // Subscribe to role-based topic
          await _fcm.subscribeToTopic(role);
          print('Subscribed to topic: $role');
          
          // All users subscribe to 'all' topic
          await _fcm.subscribeToTopic('all');
          print('Subscribed to topic: all');
        }
      }
    } catch (e) {
      print('Error subscribing to topics: $e');
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await _fcm.getToken();
        if (token != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'fcmToken': token,
          });
          print('FCM Token saved: $token');
        }
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Update FCM token when it refreshes
  Future<void> _updateFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
        });
        print('FCM Token updated: $token');
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  // Handle foreground messages (when app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('==========================================');
    print('📱 FOREGROUND MESSAGE RECEIVED');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');
    print('==========================================');
    
    try {
      // Show local notification when app is in foreground
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'class_notifications',
        'Class Notifications',
        channelDescription: 'Notifications for class attendance and announcements',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        showWhen: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      print('🔔 Showing local notification with ID: $notificationId');

      await _localNotifications.show(
        notificationId,
        message.notification?.title ?? 'Al-Siraj Attendance',
        message.notification?.body ?? 'You have a new notification',
        notificationDetails,
        payload: message.data['type'] ?? message.data['classId'],
      );
      
      print('✅ Local notification shown successfully');
    } catch (e) {
      print('❌ Error showing foreground notification: $e');
    }
  }

  // Handle notification tap when app was in background or terminated
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('🔔 Notification opened app');
    print('Title: ${message.notification?.title}');
    print('Data: ${message.data}');
    
    // Handle different notification types
    if (message.data.containsKey('type')) {
      final type = message.data['type'];
      switch (type) {
        case 'class_reminder':
          print('Navigate to class: ${message.data['classId']}');
          // TODO: Navigate to specific class
          break;
        case 'announcement':
          print('Show announcement');
          // TODO: Navigate to announcements
          break;
        default:
          print('Unknown notification type: $type');
      }
    }
  }

  // Send notification to all students for a class
  Future<void> sendClassNotification({
    required String courseId,
    required String classId,
    required String courseName,
    required DateTime startTime,
  }) async {
    try {
      // Get all active students
      final studentsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('isActive', isEqualTo: true)
          .get();

      // Prepare notification data
      final String title = 'Class Starting Soon!';
      final String body = '$courseName class is starting. Mark your attendance now!';

      // Save notification to schedule
      await _firestore.collection('scheduled_notifications').add({
        'courseId': courseId,
        'classId': classId,
        'courseName': courseName,
        'title': title,
        'body': body,
        'scheduledTime': startTime,
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
        'studentTokens': studentsSnapshot.docs
            .map((doc) => doc.data()['fcmToken'])
            .where((token) => token != null)
            .toList(),
      });

      print('Notification scheduled for ${studentsSnapshot.docs.length} students');
    } catch (e) {
      print('Error sending class notification: $e');
    }
  }

  // Send immediate notification (for testing)
  Future<void> sendImmediateNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'class_notifications',
      'Class Notifications',
      channelDescription: 'Notifications for class attendance',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );
  }


}

