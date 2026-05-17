import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';

class FirebaseDatabaseService {
  static final FirebaseDatabaseService _instance =
      FirebaseDatabaseService._internal();
  factory FirebaseDatabaseService() => _instance;
  FirebaseDatabaseService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL:
        'https://finalmad-d8a9f-default-rtdb.asia-southeast1.firebasedatabase.app/',
  );

  DatabaseReference get _root => _db.ref();

  // ── References ────────────────────────────────────────────────────────────
  DatabaseReference get usersRef => _root.child('users');
  DatabaseReference get eventsRef => _root.child('events');
  DatabaseReference get buildingsRef => _root.child('buildings');
  DatabaseReference get roomsRef => _root.child('rooms');
  DatabaseReference get bookingsRef => _root.child('bookings');
  DatabaseReference get registrationsRef => _root.child('registrations');
  DatabaseReference get paymentsRef => _root.child('payments');
  DatabaseReference get notificationsRef => _root.child('notifications');
  DatabaseReference get messagesRef => _root.child('messages');
  DatabaseReference get chatbotsRef => _root.child('chatbot_sessions');
  DatabaseReference get analyticsRef => _root.child('analytics_events');
  DatabaseReference get seedFlagRef => _root.child('_seeded');

  // ── Seed Guard ────────────────────────────────────────────────────────────
  Future<bool> isSeeded() async {
    final snap = await seedFlagRef.get();
    return snap.exists && snap.value == true;
  }

  Future<void> markSeeded() => seedFlagRef.set(true);

  // ── Helpers ───────────────────────────────────────────────────────────────
  int _toMs(dynamic v) {
    if (v is DateTime) return v.millisecondsSinceEpoch;
    if (v is int) return v;
    return 0;
  }

  Map<String, dynamic> _clean(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      if (v is DateTime) {
        out[k] = v.millisecondsSinceEpoch;
      } else if (v is List) {
        out[k] = v.map((e) => e is DateTime ? e.millisecondsSinceEpoch : e).toList();
      } else if (v is Map) {
        out[k] = _clean(Map<String, dynamic>.from(v));
      } else {
        out[k] = v;
      }
    });
    return out;
  }

  // ── Users ─────────────────────────────────────────────────────────────────
  Future<void> writeUser(UserModel u) => usersRef.child(u.id).set({
        'id': u.id,
        'fullName': u.fullName,
        'email': u.email,
        'password': u.password,
        'role': u.role.name,
        'company': u.company ?? '',
        'industry': u.industry ?? '',
        'bio': u.bio ?? '',
        'phone': u.phone ?? '',
        'interests': u.interests,
        'createdAt': u.createdAt.millisecondsSinceEpoch,
      });

  Stream<List<Map<String, dynamic>>> streamUsers() => usersRef
      .onValue
      .map((e) => _snapToList(e.snapshot));

  Future<List<Map<String, dynamic>>> getUsers() async {
    final snap = await usersRef.get();
    return _snapToList(snap);
  }

  // ── Events ────────────────────────────────────────────────────────────────
  Future<void> writeEvent(Map<String, dynamic> ev) =>
      eventsRef.child(ev['id'] as String).set(_clean(ev));

  Future<void> updateEvent(String id, Map<String, dynamic> data) =>
      eventsRef.child(id).update(_clean(data));

  Future<void> deleteEvent(String id) => eventsRef.child(id).remove();

  Stream<List<Map<String, dynamic>>> streamEvents() => eventsRef
      .onValue
      .map((e) => _snapToList(e.snapshot));

  Future<List<Map<String, dynamic>>> getEvents() async {
    final snap = await eventsRef.get();
    return _snapToList(snap);
  }

  // ── Buildings ─────────────────────────────────────────────────────────────
  Future<void> writeBuilding(Map<String, dynamic> b) =>
      buildingsRef.child(b['id'] as String).set(_clean(b));

  Future<void> updateBuilding(String id, Map<String, dynamic> data) =>
      buildingsRef.child(id).update(_clean(data));

  Future<void> deleteBuilding(String id) => buildingsRef.child(id).remove();

  Stream<List<Map<String, dynamic>>> streamBuildings() => buildingsRef
      .onValue
      .map((e) => _snapToList(e.snapshot));

  Future<List<Map<String, dynamic>>> getBuildings() async {
    final snap = await buildingsRef.get();
    return _snapToList(snap);
  }

  // ── Rooms ─────────────────────────────────────────────────────────────────
  Future<void> writeRoom(Map<String, dynamic> r) =>
      roomsRef.child(r['id'] as String).set(_clean(r));

  Future<void> deleteRoom(String id) => roomsRef.child(id).remove();

  Stream<List<Map<String, dynamic>>> streamRooms() => roomsRef
      .onValue
      .map((e) => _snapToList(e.snapshot));

  // ── Bookings ──────────────────────────────────────────────────────────────
  Future<void> writeBooking(Map<String, dynamic> b) =>
      bookingsRef.child(b['id'] as String).set(_clean(b));

  Future<void> updateBooking(String id, Map<String, dynamic> data) =>
      bookingsRef.child(id).update(_clean(data));

  Stream<List<Map<String, dynamic>>> streamBookings() => bookingsRef
      .onValue
      .map((e) => _snapToList(e.snapshot));

  Future<List<Map<String, dynamic>>> getBookings() async {
    final snap = await bookingsRef.get();
    return _snapToList(snap);
  }

  // ── Registrations ─────────────────────────────────────────────────────────
  Future<void> writeRegistration(Map<String, dynamic> r) =>
      registrationsRef.child(r['id'] as String).set(_clean(r));

  Future<void> deleteRegistration(String id) =>
      registrationsRef.child(id).remove();

  Stream<List<Map<String, dynamic>>> streamRegistrations() => registrationsRef
      .onValue
      .map((e) => _snapToList(e.snapshot));

  Future<List<Map<String, dynamic>>> getRegistrations() async {
    final snap = await registrationsRef.get();
    return _snapToList(snap);
  }

  // ── Payments ──────────────────────────────────────────────────────────────
  Future<void> writePayment(Map<String, dynamic> p) =>
      paymentsRef.child(p['id'] as String).set(_clean(p));

  Stream<List<Map<String, dynamic>>> streamPayments() => paymentsRef
      .onValue
      .map((e) => _snapToList(e.snapshot));

  Future<List<Map<String, dynamic>>> getPayments() async {
    final snap = await paymentsRef.get();
    return _snapToList(snap);
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  Future<void> writeNotification(Map<String, dynamic> n) =>
      notificationsRef
          .child(n['userId'] as String)
          .child(n['id'] as String)
          .set(_clean(n));

  Stream<List<Map<String, dynamic>>> streamNotificationsForUser(
          String userId) =>
      notificationsRef
          .child(userId)
          .onValue
          .map((e) => _snapToList(e.snapshot));

  // ── Messages ──────────────────────────────────────────────────────────────
  Future<void> writeMessage(String bookingId, Map<String, dynamic> msg) =>
      messagesRef
          .child(bookingId)
          .child(msg['id'] as String)
          .set(_clean(msg));

  Stream<List<Map<String, dynamic>>> streamMessages(String bookingId) =>
      messagesRef
          .child(bookingId)
          .onValue
          .map((e) => _snapToList(e.snapshot));

  // ── Chatbot Sessions ──────────────────────────────────────────────────────
  Future<void> writeChatMessage(String userId, Map<String, dynamic> msg) =>
      chatbotsRef.child(userId).push().set(_clean(msg));

  Stream<List<Map<String, dynamic>>> streamChatHistory(String userId) =>
      chatbotsRef
          .child(userId)
          .onValue
          .map((e) => _snapToList(e.snapshot));

  Future<List<Map<String, dynamic>>> getChatHistory(String userId) async {
    final snap = await chatbotsRef.child(userId).get();
    return _snapToList(snap);
  }

  // ── Analytics Events ──────────────────────────────────────────────────────
  Future<void> logAnalyticsEvent({
    required String eventName,
    required String userId,
    required String userRole,
    Map<String, dynamic>? params,
  }) async {
    await analyticsRef.push().set({
      'eventName': eventName,
      'userId': userId,
      'userRole': userRole,
      'params': params ?? {},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Stream<List<Map<String, dynamic>>> streamAnalyticsEvents() => analyticsRef
      .limitToLast(500)
      .onValue
      .map((e) => _snapToList(e.snapshot));

  Future<List<Map<String, dynamic>>> getAnalyticsEvents() async {
    final snap = await analyticsRef.limitToLast(500).get();
    return _snapToList(snap);
  }

  // ── Bulk seed helpers ─────────────────────────────────────────────────────
  Future<void> bulkWriteUsers(List<UserModel> users) async {
    final updates = <String, dynamic>{};
    for (final u in users) {
      updates['users/${u.id}'] = {
        'id': u.id,
        'fullName': u.fullName,
        'email': u.email,
        'password': u.password,
        'role': u.role.name,
        'company': u.company ?? '',
        'industry': u.industry ?? '',
        'bio': u.bio ?? '',
        'phone': u.phone ?? '',
        'interests': u.interests,
        'createdAt': u.createdAt.millisecondsSinceEpoch,
      };
    }
    await _root.update(updates);
  }

  Future<void> bulkWriteMap(
      String collection, List<Map<String, dynamic>> items) async {
    final updates = <String, dynamic>{};
    for (final item in items) {
      final id = item['id'] as String;
      updates['$collection/$id'] = _clean(item);
    }
    if (updates.isNotEmpty) await _root.update(updates);
  }

  // ── Ratings ───────────────────────────────────────────────────────────────
  DatabaseReference get ratingsRef => _root.child('ratings');

  Future<void> writeRating(
          String eventId, String userId, Map<String, dynamic> data) =>
      ratingsRef.child(eventId).child(userId).set(_clean(data));

  Stream<List<Map<String, dynamic>>> streamRatingsForEvent(String eventId) =>
      ratingsRef
          .child(eventId)
          .onValue
          .map((e) => _snapToList(e.snapshot));

  Stream<List<Map<String, dynamic>>> streamAllRatings() =>
      ratingsRef.onValue.map((event) {
        if (!event.snapshot.exists || event.snapshot.value == null) return [];
        final val = event.snapshot.value;
        if (val is! Map) return [];
        final result = <Map<String, dynamic>>[];
        for (final entry in val.entries) {
          final eventRatings = entry.value;
          if (eventRatings is Map) {
            for (final r in eventRatings.values) {
              if (r is Map) result.add(Map<String, dynamic>.from(r));
            }
          }
        }
        return result;
      });

  // ── Badges ────────────────────────────────────────────────────────────────
  DatabaseReference get badgesRef => _root.child('badges');

  Future<void> writeBadge(
          String userId, String badgeType, Map<String, dynamic> data) =>
      badgesRef.child(userId).child(badgeType).set(_clean(data));

  Stream<List<Map<String, dynamic>>> streamBadgesForUser(String userId) =>
      badgesRef.child(userId).onValue.map((e) => _snapToList(e.snapshot));

  Future<List<Map<String, dynamic>>> getBadgesForUser(String userId) async {
    final snap = await badgesRef.child(userId).get();
    return _snapToList(snap);
  }

  // ── Wishlists (Firebase-synced) ───────────────────────────────────────────
  DatabaseReference get wishlistsRef => _root.child('wishlists');

  Future<void> writeWishlist(String userId, List<String> eventIds) =>
      wishlistsRef.child(userId).set({'eventIds': eventIds});

  Stream<List<String>> streamWishlistForUser(String userId) =>
      wishlistsRef.child(userId).onValue.map((event) {
        if (!event.snapshot.exists || event.snapshot.value == null) return [];
        final val = event.snapshot.value;
        if (val is Map) {
          final ids = val['eventIds'];
          if (ids is List) {
            return ids.map((e) => e.toString()).toList();
          }
        }
        return <String>[];
      });

  // ── Snapshot parser ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> _snapToList(DataSnapshot snap) {
    if (!snap.exists || snap.value == null) return [];
    final val = snap.value;
    if (val is Map) {
      return val.values
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    if (val is List) {
      return val
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  // ── Date conversion helpers ───────────────────────────────────────────────
  static DateTime msToDate(dynamic v) {
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return DateTime.now();
  }

  static Map<String, dynamic> convertDates(Map<String, dynamic> raw,
      List<String> dateFields) {
    final out = Map<String, dynamic>.from(raw);
    for (final f in dateFields) {
      if (out.containsKey(f) && out[f] != null) {
        out[f] = msToDate(out[f]);
      }
    }
    return out;
  }
}
