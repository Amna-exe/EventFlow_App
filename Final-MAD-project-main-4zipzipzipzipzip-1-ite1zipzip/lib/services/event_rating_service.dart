import 'dart:async';
import 'firebase_database_service.dart';

class EventRatingService {
  static final EventRatingService _i = EventRatingService._internal();
  factory EventRatingService() => _i;
  EventRatingService._internal();

  final _db = FirebaseDatabaseService();

  // In-memory cache:  'eventId__userId' → rating map
  final Map<String, Map<String, dynamic>> _cache = {};
  StreamSubscription? _globalSub;

  void subscribeAll() {
    _globalSub = _db.streamAllRatings().listen((list) {
      for (final r in list) {
        final eid = r['eventId'] as String? ?? '';
        final uid = r['userId'] as String? ?? '';
        if (eid.isNotEmpty && uid.isNotEmpty) {
          _cache['${eid}__$uid'] = r;
        }
      }
    });
  }

  void disposeSubscription() => _globalSub?.cancel();

  Future<void> submitRating({
    required String eventId,
    required String userId,
    required String userName,
    required double rating,
    String review = '',
  }) async {
    final data = {
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'review': review,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _cache['${eventId}__$userId'] = data;
    try {
      await _db.writeRating(eventId, userId, data);
    } catch (_) {}
  }

  double? getUserRating(String eventId, String userId) =>
      (_cache['${eventId}__$userId']?['rating'] as num?)?.toDouble();

  String getUserReview(String eventId, String userId) =>
      _cache['${eventId}__$userId']?['review'] as String? ?? '';

  bool hasRated(String eventId, String userId) =>
      _cache.containsKey('${eventId}__$userId');

  double getAverageRating(String eventId) {
    final ratings = _cache.values
        .where((r) => r['eventId'] == eventId)
        .map((r) => (r['rating'] as num).toDouble())
        .toList();
    if (ratings.isEmpty) return 0.0;
    return ratings.reduce((a, b) => a + b) / ratings.length;
  }

  int getRatingCount(String eventId) =>
      _cache.values.where((r) => r['eventId'] == eventId).length;

  int getUserRatingCount(String userId) =>
      _cache.values.where((r) => r['userId'] == userId).length;

  List<Map<String, dynamic>> getReviewsForEvent(String eventId) {
    return _cache.values
        .where((r) =>
            r['eventId'] == eventId &&
            (r['review'] as String? ?? '').trim().isNotEmpty)
        .toList()
      ..sort((a, b) =>
          (b['timestamp'] as int).compareTo(a['timestamp'] as int));
  }

  Stream<List<Map<String, dynamic>>> streamRatingsForEvent(String eventId) =>
      _db.streamRatingsForEvent(eventId).map((list) {
        for (final r in list) {
          final uid = r['userId'] as String? ?? '';
          if (uid.isNotEmpty) _cache['${eventId}__$uid'] = r;
        }
        return list;
      });
}
