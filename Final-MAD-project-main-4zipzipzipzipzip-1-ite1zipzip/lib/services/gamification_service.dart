import 'package:flutter/material.dart';
import 'firebase_database_service.dart';

enum BadgeType {
  firstTimer,
  eventExplorer,
  enthusiast,
  superFan,
  loyalAttendee,
  reviewer,
  wishlistKeeper,
  earlyBird,
}

const _kBadgeMeta = <BadgeType, Map<String, dynamic>>{
  BadgeType.firstTimer: {
    'name': 'First Timer',
    'description': 'Registered for your very first event',
    'emoji': '🎟️',
    'colorHex': 0xFFC46A3D,
    'requirement': 'Register for 1 event',
  },
  BadgeType.enthusiast: {
    'name': 'Event Enthusiast',
    'description': 'Registered for 5 or more events',
    'emoji': '⭐',
    'colorHex': 0xFFD97706,
    'requirement': '5+ registrations',
  },
  BadgeType.superFan: {
    'name': 'Super Fan',
    'description': 'Registered for 10 or more events!',
    'emoji': '🏆',
    'colorHex': 0xFFDC2626,
    'requirement': '10+ registrations',
  },
  BadgeType.eventExplorer: {
    'name': 'Event Explorer',
    'description': 'Attended events across 3+ categories',
    'emoji': '🧭',
    'colorHex': 0xFF0891B2,
    'requirement': '3+ different categories',
  },
  BadgeType.loyalAttendee: {
    'name': 'Loyal Attendee',
    'description': 'Physically attended 3 or more events',
    'emoji': '✅',
    'colorHex': 0xFF059669,
    'requirement': '3+ attended events',
  },
  BadgeType.reviewer: {
    'name': 'Critic',
    'description': 'Submitted detailed reviews for 3+ events',
    'emoji': '📝',
    'colorHex': 0xFF7C3AED,
    'requirement': '3+ event reviews',
  },
  BadgeType.wishlistKeeper: {
    'name': 'Wishlist Keeper',
    'description': 'Saved 5 or more events to your wishlist',
    'emoji': '🔖',
    'colorHex': 0xFFEC4899,
    'requirement': '5+ saved events',
  },
  BadgeType.earlyBird: {
    'name': 'Early Bird',
    'description': 'Registered 7+ days before an event starts',
    'emoji': '🐦',
    'colorHex': 0xFF16A34A,
    'requirement': 'Register 7+ days early',
  },
};

class GamificationService {
  static final GamificationService _i = GamificationService._internal();
  factory GamificationService() => _i;
  GamificationService._internal();

  final _db = FirebaseDatabaseService();
  final Map<String, Set<BadgeType>> _userBadges = {};
  final Map<String, Map<BadgeType, DateTime>> _badgeDates = {};

  Set<BadgeType> badgesFor(String userId) =>
      Set.unmodifiable(_userBadges[userId] ?? {});

  DateTime? badgeEarnedAt(String userId, BadgeType t) =>
      _badgeDates[userId]?[t];

  String badgeName(BadgeType t) => _kBadgeMeta[t]!['name'] as String;
  String badgeDescription(BadgeType t) =>
      _kBadgeMeta[t]!['description'] as String;
  String badgeEmoji(BadgeType t) => _kBadgeMeta[t]!['emoji'] as String;
  int badgeColorHex(BadgeType t) => _kBadgeMeta[t]!['colorHex'] as int;
  String badgeRequirement(BadgeType t) =>
      _kBadgeMeta[t]!['requirement'] as String;

  IconData badgeIcon(BadgeType t) {
    switch (t) {
      case BadgeType.firstTimer:      return Icons.confirmation_number_outlined;
      case BadgeType.eventExplorer:   return Icons.explore_outlined;
      case BadgeType.enthusiast:      return Icons.star_outline_rounded;
      case BadgeType.superFan:        return Icons.emoji_events_outlined;
      case BadgeType.loyalAttendee:   return Icons.verified_outlined;
      case BadgeType.reviewer:        return Icons.rate_review_outlined;
      case BadgeType.wishlistKeeper:  return Icons.bookmark_outline;
      case BadgeType.earlyBird:       return Icons.alarm_outlined;
    }
  }

  List<BadgeType> get allBadgeTypes => BadgeType.values;

  int totalPoints(String userId) {
    final pts = {
      BadgeType.firstTimer: 10,
      BadgeType.enthusiast: 25,
      BadgeType.superFan: 50,
      BadgeType.eventExplorer: 20,
      BadgeType.loyalAttendee: 30,
      BadgeType.reviewer: 15,
      BadgeType.wishlistKeeper: 10,
      BadgeType.earlyBird: 15,
    };
    return badgesFor(userId).fold(0, (sum, b) => sum + (pts[b] ?? 0));
  }

  String levelTitle(int points) {
    if (points >= 100) return 'Event Legend';
    if (points >= 60) return 'Event Champion';
    if (points >= 30) return 'Event Regular';
    if (points >= 10) return 'Event Newcomer';
    return 'Getting Started';
  }

  /// Returns newly earned badges so the UI can show toasts/dialogs.
  Future<List<BadgeType>> checkAndAward({
    required String userId,
    required int registrationCount,
    required int attendedCount,
    required int categoryCount,
    required int reviewCount,
    required int wishlistCount,
    required bool isEarlyBird,
  }) async {
    final existing = _userBadges[userId] ?? {};
    final earned = <BadgeType>{};

    if (registrationCount >= 1) earned.add(BadgeType.firstTimer);
    if (registrationCount >= 5) earned.add(BadgeType.enthusiast);
    if (registrationCount >= 10) earned.add(BadgeType.superFan);
    if (attendedCount >= 3) earned.add(BadgeType.loyalAttendee);
    if (categoryCount >= 3) earned.add(BadgeType.eventExplorer);
    if (reviewCount >= 3) earned.add(BadgeType.reviewer);
    if (wishlistCount >= 5) earned.add(BadgeType.wishlistKeeper);
    if (isEarlyBird) earned.add(BadgeType.earlyBird);

    final newlyEarned = earned.difference(existing);
    _userBadges[userId] = earned;

    final dates = _badgeDates.putIfAbsent(userId, () => {});
    for (final b in newlyEarned) {
      final now = DateTime.now();
      dates[b] = now;
      try {
        await _db.writeBadge(userId, b.name, {
          'type': b.name,
          'earnedAt': now.millisecondsSinceEpoch,
        });
      } catch (_) {}
    }

    return newlyEarned.toList();
  }

  void loadFromFirebase(String userId, List<Map<String, dynamic>> badgeList) {
    final types = <BadgeType>{};
    final dates = <BadgeType, DateTime>{};
    for (final b in badgeList) {
      final typeName = b['type'] as String? ?? '';
      try {
        final t = BadgeType.values.firstWhere((bt) => bt.name == typeName);
        types.add(t);
        final ms = b['earnedAt'] as int?;
        if (ms != null) dates[t] = DateTime.fromMillisecondsSinceEpoch(ms);
      } catch (_) {}
    }
    _userBadges[userId] = types;
    _badgeDates[userId] = dates;
  }
}
