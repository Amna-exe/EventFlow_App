import 'dart:math';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_database_service.dart';

class FirebaseAnalyticsService {
  static final FirebaseAnalyticsService _i =
      FirebaseAnalyticsService._internal();
  factory FirebaseAnalyticsService() => _i;
  FirebaseAnalyticsService._internal();

  final FirebaseAnalytics _fa = FirebaseAnalytics.instance;
  final FirebaseDatabaseService _fdb = FirebaseDatabaseService();

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _fa);

  Future<void> _log(String name,
      {Map<String, Object>? params,
      String userId = 'anon',
      String role = 'unknown'}) async {
    try {
      await _fa.logEvent(name: name, parameters: params);
    } catch (_) {}
    try {
      await _fdb.analyticsRef.push().set({
        'eventName': name,
        'params': params?.map((k, v) => MapEntry(k, v.toString())),
        'userId': userId,
        'userRole': role,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  // ── Screen / navigation ───────────────────────────────────────────────────

  Future<void> logScreenView(String screen,
      {String userId = 'anon', String role = 'unknown'}) async {
    try {
      await _fa.logScreenView(screenName: screen);
    } catch (_) {}
    await _log('screen_view',
        params: {'screen_name': screen}, userId: userId, role: role);
  }

  Future<void> logTabView(String tab, String userId) async {
    await _log('tab_view', params: {'tab': tab}, userId: userId);
  }

  // ── Event lifecycle ───────────────────────────────────────────────────────

  Future<void> logEventCreated(
      String eventId, String eventTitle, String organizerId,
      {String category = ''}) async {
    await _log(
      'event_created',
      params: {
        'event_id': eventId,
        'event_title': _trim(eventTitle),
        'category': category,
      },
      userId: organizerId,
      role: 'organizer',
    );
  }

  Future<void> logEventView(
      String eventId, String eventTitle, String userId) async {
    try {
      await _fa.logViewItem(
        currency: 'GBP',
        value: 0,
        items: [
          AnalyticsEventItem(
            itemId: eventId,
            itemName: _trim(eventTitle),
            itemCategory: 'event',
          )
        ],
      );
    } catch (_) {}
    await _log('event_view',
        params: {'event_id': eventId, 'event_title': _trim(eventTitle)},
        userId: userId);
  }

  Future<void> logVenueViewed(
      String buildingId, String buildingName, String userId) async {
    await _log(
      'venue_viewed',
      params: {
        'building_id': buildingId,
        'building_name': _trim(buildingName),
      },
      userId: userId,
    );
  }

  // ── Registration & attendance ─────────────────────────────────────────────

  Future<void> logEventRegistration(
      String eventId, String eventTitle, String userId, String role) async {
    try {
      await _fa.logEvent(
        name: 'event_registration',
        parameters: {
          'event_id': eventId,
          'event_title': _trim(eventTitle),
        },
      );
    } catch (_) {}
    await _log('event_registration',
        params: {
          'event_id': eventId,
          'event_title': _trim(eventTitle),
        },
        userId: userId,
        role: role);
  }

  Future<void> logRegistrationCompleted(
      String eventId, String eventTitle, String attendeeId) async {
    await _log(
      'registration_completed',
      params: {
        'event_id': eventId,
        'event_title': _trim(eventTitle),
      },
      userId: attendeeId,
      role: 'attendee',
    );
  }

  Future<void> logEventUnregistration(
      String eventId, String eventTitle, String userId) async {
    await _log('event_unregistration',
        params: {'event_id': eventId, 'event_title': _trim(eventTitle)},
        userId: userId);
  }

  Future<void> logAttendanceMarked(
      String eventId, String eventTitle, String attendeeId,
      {bool attended = true}) async {
    await _log(
      'attendance_marked',
      params: {
        'event_id': eventId,
        'event_title': _trim(eventTitle),
        'attended': attended.toString(),
      },
      userId: attendeeId,
      role: 'attendee',
    );
  }

  // ── Bookings ──────────────────────────────────────────────────────────────

  Future<void> logBookingRequested(
      String bookingId, String roomId, String organizerId,
      {double amount = 0}) async {
    await _log(
      'booking_requested',
      params: {
        'booking_id': bookingId,
        'room_id': roomId,
        'amount': amount.toStringAsFixed(0),
      },
      userId: organizerId,
      role: 'organizer',
    );
  }

  Future<void> logBookingApproved(
      String bookingId, String roomId, String ownerId) async {
    await _log(
      'booking_approved',
      params: {
        'booking_id': bookingId,
        'room_id': roomId,
      },
      userId: ownerId,
      role: 'staff',
    );
  }

  Future<void> logBookingRejected(
      String bookingId, String ownerId) async {
    await _log(
      'booking_rejected',
      params: {'booking_id': bookingId},
      userId: ownerId,
      role: 'staff',
    );
  }

  // ── Payments ──────────────────────────────────────────────────────────────

  Future<void> logPaymentCompleted(
      String bookingId, double amount, String userId) async {
    try {
      await _fa.logEvent(
        name: 'payment_completed',
        parameters: {
          'booking_id': bookingId,
          'amount': amount.toStringAsFixed(0),
          'currency': 'GBP',
        },
      );
    } catch (_) {}
    await _log(
      'payment_completed',
      params: {
        'booking_id': bookingId,
        'amount': amount.toStringAsFixed(0),
      },
      userId: userId,
    );
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<void> logNotificationOpened(
      String notificationId, String type, String userId) async {
    await _log(
      'notification_opened',
      params: {
        'notification_id': notificationId,
        'notification_type': type,
      },
      userId: userId,
    );
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<void> logSearch(String query, {String userId = 'anon'}) async {
    try {
      await _fa.logSearch(searchTerm: query);
    } catch (_) {}
    await _log('search', params: {'query': _trim(query)}, userId: userId);
  }

  Future<void> logSearchPerformed(
      String query, int resultCount, String userId) async {
    await _log(
      'search_performed',
      params: {
        'query': _trim(query),
        'result_count': resultCount.toString(),
      },
      userId: userId,
    );
  }

  // ── Wishlist / Social ─────────────────────────────────────────────────────

  Future<void> logSaveEvent(
      String eventId, String eventTitle, String userId) async {
    await _log('save_event',
        params: {'event_id': eventId, 'event_title': _trim(eventTitle)},
        userId: userId);
  }

  Future<void> logShareEvent(
      String eventId, String eventTitle, String userId) async {
    try {
      await _fa.logShare(
          contentType: 'event', itemId: eventId, method: 'clipboard');
    } catch (_) {}
    await _log('share_event',
        params: {'event_id': eventId, 'event_title': _trim(eventTitle)},
        userId: userId);
  }

  // ── User identity ─────────────────────────────────────────────────────────

  Future<void> setUser(String userId, String role) async {
    try {
      await _fa.setUserId(id: userId);
      await _fa.setUserProperty(name: 'user_role', value: role);
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _trim(String s) => s.substring(0, min(100, s.length));
}
