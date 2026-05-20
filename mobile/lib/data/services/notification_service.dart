import 'dart:async';
import 'package:flutter/material.dart';

/// In-app notification service that schedules reminders.
/// Works on Flutter Web (no native notification plugins needed).
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<ScheduledNotification> _scheduled = [];
  final List<AppNotification> _history = [];
  Timer? _checker;

  List<AppNotification> get history => List.unmodifiable(_history);
  int get unreadCount => _history.where((n) => !n.read).length;

  void init() {
    _checker?.cancel();
    _checker = Timer.periodic(const Duration(seconds: 30), (_) => _checkScheduled());
  }

  void dispose() {
    _checker?.cancel();
  }

  /// Schedule a notification to fire at [fireAt].
  void schedule({
    required String title,
    required String body,
    required DateTime fireAt,
    String? bookingId,
  }) {
    _scheduled.add(ScheduledNotification(
      title: title,
      body: body,
      fireAt: fireAt,
      bookingId: bookingId,
    ));
  }

  /// Add an immediate notification (e.g. booking confirmed).
  void addImmediate({
    required String title,
    required String body,
    String? bookingId,
    NotificationType type = NotificationType.info,
  }) {
    _history.insert(0, AppNotification(
      title: title,
      body: body,
      time: DateTime.now(),
      bookingId: bookingId,
      type: type,
    ));
  }

  /// Cancel all scheduled notifications for a booking.
  void cancelForBooking(String bookingId) {
    _scheduled.removeWhere((n) => n.bookingId == bookingId);
    addImmediate(
      title: "Reminder Cancelled",
      body: "Booking reminder has been cancelled.",
      bookingId: bookingId,
      type: NotificationType.cancelled,
    );
  }

  void markAllRead() {
    for (var n in _history) {
      n.read = true;
    }
  }

  void _checkScheduled() {
    final now = DateTime.now();
    final toFire = _scheduled.where((n) => n.fireAt.isBefore(now)).toList();
    for (var n in toFire) {
      _history.insert(0, AppNotification(
        title: n.title,
        body: n.body,
        time: now,
        bookingId: n.bookingId,
        type: NotificationType.reminder,
      ));
      _scheduled.remove(n);
    }
  }
}

class ScheduledNotification {
  final String title;
  final String body;
  final DateTime fireAt;
  final String? bookingId;

  ScheduledNotification({
    required this.title,
    required this.body,
    required this.fireAt,
    this.bookingId,
  });
}

enum NotificationType { info, reminder, confirmed, completed, cancelled }

class AppNotification {
  final String title;
  final String body;
  final DateTime time;
  final String? bookingId;
  final NotificationType type;
  bool read;

  AppNotification({
    required this.title,
    required this.body,
    required this.time,
    this.bookingId,
    this.type = NotificationType.info,
    this.read = false,
  });

  IconData get icon {
    switch (type) {
      case NotificationType.reminder: return Icons.alarm;
      case NotificationType.confirmed: return Icons.check_circle;
      case NotificationType.completed: return Icons.star;
      case NotificationType.cancelled: return Icons.cancel;
      default: return Icons.notifications;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.reminder: return Colors.orange;
      case NotificationType.confirmed: return Colors.green;
      case NotificationType.completed: return const Color(0xFF1a56db);
      case NotificationType.cancelled: return Colors.red;
      default: return Colors.grey;
    }
  }
}
