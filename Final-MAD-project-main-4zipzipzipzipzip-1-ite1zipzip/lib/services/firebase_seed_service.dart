import 'firebase_database_service.dart';
import 'auth_service.dart';
import 'venue_service.dart';
import 'registration_service.dart';
import 'payment_service.dart';
import 'chat_service.dart';
import 'notification_service.dart';

class FirebaseSeedService {
  static final FirebaseSeedService _instance = FirebaseSeedService._internal();
  factory FirebaseSeedService() => _instance;
  FirebaseSeedService._internal();

  final _db = FirebaseDatabaseService();
  final _auth = AuthService();
  final _venue = VenueService();
  final _reg = RegistrationService();
  final _pay = PaymentService();
  final _chat = ChatService();
  final _notif = NotificationService();

  Future<void> seedIfNeeded() async {
    try {
      final seeded = await _db.isSeeded();
      if (seeded) return;
      await _seedAll();
      await _db.markSeeded();
    } catch (_) {
      // Seed errors don't crash the app – in-memory data still works
    }
  }

  Future<void> _seedAll() async {
    await _seedUsers();
    await _seedBuildings();
    await _seedRooms();
    await _seedEvents();
    await _seedBookings();
    await _seedRegistrations();
    await _seedPayments();
    await _seedNotifications();
    await _seedMessages();
  }

  Future<void> _seedUsers() async {
    await _db.bulkWriteUsers(_auth.allUsers);
  }

  Future<void> _seedBuildings() async {
    final maps = _venue.allBuildings.map((b) => {
          'id': b.id,
          'ownerId': b.ownerId,
          'name': b.name,
          'address': b.address,
          'description': b.description,
          'latitude': b.latitude ?? 0.0,
          'longitude': b.longitude ?? 0.0,
          'termsAndConditions': b.termsAndConditions,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        }).toList();
    await _db.bulkWriteMap('buildings', maps);
  }

  Future<void> _seedRooms() async {
    final allRooms = <Map<String, dynamic>>[];
    for (final b in _venue.allBuildings) {
      for (final r in _venue.roomsForBuilding(b.id)) {
        allRooms.add({
          'id': r.id,
          'buildingId': r.buildingId,
          'name': r.name,
          'capacity': r.capacity,
          'type': r.type.name,
          'floor': r.floor ?? '',
          'description': r.description ?? '',
          'amenities': r.amenities,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
    await _db.bulkWriteMap('rooms', allRooms);
  }

  Future<void> _seedEvents() async {
    final maps = _auth.allEvents.map((e) {
      final out = Map<String, dynamic>.from(e);
      _convertDates(out, ['start', 'end', 'createdAt']);
      return out;
    }).toList();
    await _db.bulkWriteMap('events', maps);
  }

  Future<void> _seedBookings() async {
    final maps = _auth.allBookings.map((b) {
      final out = Map<String, dynamic>.from(b);
      _convertDates(out, ['start', 'end', 'createdAt']);
      return out;
    }).toList();
    await _db.bulkWriteMap('bookings', maps);
  }

  Future<void> _seedRegistrations() async {
    final allRegs = <Map<String, dynamic>>[];
    for (final u in _auth.allUsers) {
      for (final r in _reg.registrationsForAttendee(u.id)) {
        final out = Map<String, dynamic>.from(r);
        _convertDates(out, ['registeredAt']);
        allRegs.add(out);
      }
    }
    if (allRegs.isNotEmpty) await _db.bulkWriteMap('registrations', allRegs);
  }

  Future<void> _seedPayments() async {
    final allPayments = <Map<String, dynamic>>[];
    for (final b in _auth.allBookings) {
      final p = _pay.get(b['id'] as String);
      if (p != null) {
        allPayments.add({
          'id': 'pay_${p.bookingId}',
          'bookingId': p.bookingId,
          'amount': p.amount,
          'status': p.status.name,
          'paidAt': p.paidAt?.millisecondsSinceEpoch,
          'refundedAt': p.refundedAt?.millisecondsSinceEpoch,
        });
      }
    }
    if (allPayments.isNotEmpty) await _db.bulkWriteMap('payments', allPayments);
  }

  Future<void> _seedNotifications() async {
    for (final u in _auth.allUsers) {
      final notifs = _notif.notificationsForOwner(u.id);
      for (final n in notifs) {
        try {
          await _db.writeNotification({
            'id': n.id,
            'userId': u.id,
            'ownerId': n.ownerId,
            'title': n.title,
            'message': n.message,
            'type': n.type.name,
            'bookingId': n.bookingId ?? '',
            'isRead': n.isRead,
            'createdAt': n.timestamp.millisecondsSinceEpoch,
          });
        } catch (_) {}
      }
    }
  }

  Future<void> _seedMessages() async {
    for (final b in _auth.allBookings) {
      final bid = b['id'] as String;
      final msgs = _chat.messagesForBooking(bid);
      for (final m in msgs) {
        try {
          await _db.writeMessage(bid, {
            'id': m.id,
            'bookingId': m.bookingId,
            'senderId': m.senderId,
            'senderName': m.senderName,
            'isOwner': m.isOwner,
            'text': m.text,
            'sentAt': m.timestamp.millisecondsSinceEpoch,
          });
        } catch (_) {}
      }
    }
  }

  void _convertDates(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      if (map[k] is DateTime) {
        map[k] = (map[k] as DateTime).millisecondsSinceEpoch;
      }
    }
  }
}
