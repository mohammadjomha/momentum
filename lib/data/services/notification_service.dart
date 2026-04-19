import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/profile/models/maintenance_entry.dart';

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'momentum_maintenance';
  static const _channelName = 'Maintenance Reminders';

  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
    } else if (Platform.isIOS) {
      final status = await Permission.notification.status;
      if (status.isDenied) await Permission.notification.request();
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
  }

  static Future<void> checkAndNotifyOverdueMaintenance(String uid) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('maintenance')
        .get();

    final overdue = snapshot.docs
        .map((d) => MaintenanceEntry.fromDoc(d))
        .where((e) =>
            e.nextDueDate != null &&
            e.nextDueDate!.isBefore(today))
        .toList();

    final formatter = DateFormat('MMM d, yyyy');

    for (var i = 0; i < overdue.length; i++) {
      final entry = overdue[i];
      await _plugin.show(
        i,
        'Your ${entry.type} is overdue',
        'Last done: ${formatter.format(entry.lastDoneDate)}',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    }
  }
}