import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/notification_service.dart';
import '../../../models/notification_model.dart';
import '../../../models/user_model.dart';

const _kPrimary      = Color(0xFFC46A3D);
const _kPrimaryLight = Color(0xFFFFF1E8);
const _kTextDark     = Color(0xFF1F1A17);
const _kTextMid      = Color(0xFF6E6258);
const _kTextLight    = Color(0xFFA09489);
const _kBorder       = Color(0xFFE9E1D6);
const _kBg           = Color(0xFFFAF7F2);
const _kSurface      = Color(0xFFFFFFFF);

class AttendeeNotificationsTab extends StatefulWidget {
  final Set<String> registeredIds;
  final void Function(Map<String, dynamic>) onEventTap;

  const AttendeeNotificationsTab({
    super.key,
    required this.registeredIds,
    required this.onEventTap,
  });

  @override
  State<AttendeeNotificationsTab> createState() =>
      _AttendeeNotificationsTabState();
}

class _AttendeeNotificationsTabState
    extends State<AttendeeNotificationsTab> {
  final _auth  = AuthService();
  final _notif = NotificationService();

  @override
  void initState() {
    super.initState();
    _generateNotifications();
  }

  String get _uid => _auth.currentUser?.id ?? '';

  void _generateNotifications() {
    if (_uid.isEmpty) return;
    final now  = DateTime.now();
    final soon = now.add(const Duration(hours: 24));
    final user = _auth.currentUser!;

    for (final id in widget.registeredIds) {
      final matches = _auth.allEvents.where((e) => e['id'] == id);
      if (matches.isEmpty) continue;
      final event = matches.first;
      final start = event['start'] as DateTime?;
      if (start == null) continue;
      if (start.isAfter(now) && start.isBefore(soon)) {
        final existing = _notif.notificationsForOwner(_uid).any(
          (n) =>
              n.type == NotificationType.reminder &&
              n.message.contains(event['title'] as String),
        );
        if (!existing) {
          _notif.addNotification(
            ownerId: _uid,
            title:   'Upcoming Event Reminder',
            message:
                '"${event['title']}" starts at ${_fmtTime(start)} today — don\'t miss it!',
            type: NotificationType.reminder,
          );
        }
      }
    }

    final interests = user.interests;
    if (interests.isNotEmpty) {
      final recentCutoff = now.subtract(const Duration(days: 7));
      for (final event in _auth.allEvents) {
        if (event['status'] != 'published') continue;
        final cat     = event['category'] as String? ?? '';
        if (!interests.contains(cat)) continue;
        final created = event['createdAt'] as DateTime?;
        if (created == null || created.isBefore(recentCutoff)) continue;
        final existing = _notif.notificationsForOwner(_uid).any(
          (n) =>
              n.type == NotificationType.newEventInCategory &&
              n.message.contains(event['title'] as String),
        );
        if (!existing) {
          _notif.addNotification(
            ownerId: _uid,
            title:   'New Event in $cat',
            message:
                '"${event['title']}" was just added — it matches your interests!',
            type: NotificationType.newEventInCategory,
          );
        }
      }
    }
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _relativeTime(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData _typeIcon(NotificationType t) {
    switch (t) {
      case NotificationType.reminder:
        return Icons.alarm_outlined;
      case NotificationType.newEventInCategory:
        return Icons.fiber_new_outlined;
      case NotificationType.eventRegistered:
        return Icons.confirmation_num_outlined;
      case NotificationType.newBooking:
        return Icons.event_available_outlined;
      case NotificationType.cancellation:
        return Icons.event_busy_outlined;
      case NotificationType.bookingModified:
        return Icons.edit_calendar_outlined;
    }
  }

  Color _typeColor(NotificationType t) {
    switch (t) {
      case NotificationType.reminder:
        return const Color(0xFF2563EB);
      case NotificationType.newEventInCategory:
        return const Color(0xFF059669);
      case NotificationType.eventRegistered:
        return _kPrimary;
      default:
        return _kTextMid;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_auth.isLoggedIn) return _notLoggedIn();

    final notifications = _notif.notificationsForOwner(_uid);
    final unread        = _notif.unreadCount(_uid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.notifications_outlined,
                color: _kPrimary, size: 18),
            const SizedBox(width: 8),
            const Text('Notifications',
                style: TextStyle(
                    color: _kTextDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const Spacer(),
            if (notifications.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _notif.markAllRead(_uid);
                  setState(() {});
                },
                child: const Text('Mark all read',
                    style: TextStyle(
                        color: _kPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 16),

        if (notifications.isEmpty)
          _emptyState()
        else
          ...notifications.map((n) => _notifCard(n)),
      ],
    );
  }

  Widget _notifCard(NotificationModel n) {
    final color = _typeColor(n.type);
    return GestureDetector(
      onTap: () {
        _notif.markRead(n.id);
        setState(() {});
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead ? _kSurface : _kPrimaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: n.isRead ? _kBorder : _kPrimary.withOpacity(0.4),
            width: n.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon(n.type), size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(n.title,
                            style: TextStyle(
                                color: _kTextDark,
                                fontWeight: n.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                fontSize: 13)),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 7, height: 7,
                          decoration: const BoxDecoration(
                            color: _kPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(n.message,
                      style: const TextStyle(
                          color: _kTextMid,
                          fontSize: 12,
                          height: 1.4)),
                  const SizedBox(height: 4),
                  Text(_relativeTime(n.timestamp),
                      style: const TextStyle(
                          color: _kTextLight, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notLoggedIn() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _kPrimaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPrimary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.notifications_off_outlined,
              size: 48, color: _kPrimary),
          const SizedBox(height: 12),
          const Text(
            'Sign in to receive personalised notifications about your events and interests.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _kTextMid, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _kPrimaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPrimary.withOpacity(0.15)),
      ),
      child: Column(
        children: const [
          Icon(Icons.notifications_none_outlined,
              size: 48, color: _kPrimary),
          SizedBox(height: 12),
          Text(
            'You\'re all caught up!\nNo notifications right now.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _kTextMid, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
