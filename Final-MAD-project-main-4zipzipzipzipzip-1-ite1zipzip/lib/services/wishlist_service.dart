class WishlistService {
  static final WishlistService _i = WishlistService._internal();
  factory WishlistService() => _i;
  WishlistService._internal();

  final Map<String, Set<String>> _savedByUser = {};

  Set<String> savedFor(String userId) =>
      Set.unmodifiable(_savedByUser[userId] ?? {});

  bool isSaved(String userId, String eventId) =>
      (_savedByUser[userId] ?? {}).contains(eventId);

  void toggle(String userId, String eventId) {
    _savedByUser.putIfAbsent(userId, () => {});
    if (_savedByUser[userId]!.contains(eventId)) {
      _savedByUser[userId]!.remove(eventId);
    } else {
      _savedByUser[userId]!.add(eventId);
    }
  }

  void save(String userId, String eventId) {
    _savedByUser.putIfAbsent(userId, () => {});
    _savedByUser[userId]!.add(eventId);
  }

  void remove(String userId, String eventId) {
    _savedByUser[userId]?.remove(eventId);
  }

  int countFor(String userId) => (_savedByUser[userId] ?? {}).length;
}
