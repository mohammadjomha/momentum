import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    if (!kIsWeb && Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: false, sound: true);
    }

    if (!kIsWeb && Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'momentum_maintenance',
              'Maintenance Reminders',
              importance: Importance.high,
            ),
          );
    }
  }

  static Future<void> checkAndNotifyOverdueMaintenance(String uid) async {
    final today = DateTime.now();
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('maintenance')
        .get();

    final overdue = snapshot.docs.where((doc) {
      final data = doc.data();
      final ts = data['nextDueDate'];
      if (ts == null) return false;
      final due = (ts as Timestamp).toDate();
      return due.isBefore(today);
    }).toList();

    for (int i = 0; i < overdue.length; i++) {
      final data = overdue[i].data();
      final type = data['type'] as String? ?? 'Maintenance';
      final lastTs = data['lastDoneDate'] as Timestamp?;
      final lastDone = lastTs != null
          ? DateFormat('MMM d, yyyy').format(lastTs.toDate())
          : 'unknown';

      await _plugin.show(
        i,
        'Your $type is overdue',
        'Last done: $lastDone',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'momentum_maintenance',
            'Maintenance Reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: true,
          ),
        ),
      );
    }
  }
}