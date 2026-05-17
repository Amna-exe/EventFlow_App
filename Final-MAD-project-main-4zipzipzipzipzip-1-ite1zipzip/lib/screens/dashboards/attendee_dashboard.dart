import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/registration_service.dart';
import '../../services/notification_service.dart';
import '../../services/firebase_database_service.dart';
import '../../services/firebase_analytics_service.dart';
import '../../services/wishlist_service.dart';
import '../../services/event_rating_service.dart';
import '../../services/gamification_service.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../profile_screen.dart';
import '../unified_auth_sheet.dart';
import '../landing_screen.dart';
import 'organizer_dashboard.dart';
import 'staff_dashboard.dart';
import 'super_admin_dashboard.dart';
import 'tabs/attendee_calendar_tab.dart';
import 'tabs/attendee_map_tab.dart';
import 'tabs/attendee_notifications_tab.dart';
import 'tabs/attendee_analytics_tab.dart';
import 'tabs/attendee_tickets_tab.dart';
import 'tabs/attendee_wishlist_tab.dart';
import 'tabs/attendee_history_tab.dart';
import '../../widgets/ai_chatbot_widget.dart';

// ── Theme constants ───────────────────────────────────────────────────────────

const _kPrimary      = Color(0xFFC46A3D);
const _kPrimaryDark  = Color(0xFF9E4E27);
const _kPrimaryLight = Color(0xFFFFF1E8);
const _kBg           = Color(0xFFFAF7F2);
const _kSurface      = Color(0xFFFFFFFF);
const _kTextDark     = Color(0xFF1F1A17);
const _kTextMid      = Color(0xFF6E6258);
const _kTextLight    = Color(0xFFA09489);
const _kBorder       = Color(0xFFE9E1D6);
const _kSuccess      = Color(0xFF3D7A5A);
const _kSuccessLight = Color(0xFFE6F4ED);
const _kWarning      = Color(0xFFB7791F);

// ── Category colours ─────────────────────────────────────────────────────────

const _categoryColors = <String, Color>{
  'Technology':     Color(0xFF5A6F8C),
  'Business':       Color(0xFF3D7A5A),
  'Arts & Culture': Color(0xFFC46A3D),
  'Education':      Color(0xFFB7791F),
  'Workshop':       Color(0xFF5A6F8C),
  'Seminar':        Color(0xFF6E6258),
  'Conference':     Color(0xFF5A6F8C),
  'Networking':     Color(0xFF6E6258),
  'Health':         Color(0xFFC24A3A),
  'Finance':        Color(0xFF3D7A5A),
};

Color _categoryColor(String cat) =>
    _categoryColors[cat] ?? _kPrimary;

// ── Time filter ───────────────────────────────────────────────────────────────

enum _TimeFilter { all, today, thisWeek, thisMonth }

const _timeFilterLabels = {
  _TimeFilter.all:       'All Time',
  _TimeFilter.today:     'Today',
  _TimeFilter.thisWeek:  'This Week',
  _TimeFilter.thisMonth: 'This Month',
};

// ── Dashboard ─────────────────────────────────────────────────────────────────

class AttendeeDashboard extends StatefulWidget {
  const AttendeeDashboard({super.key});

  @override
  State<AttendeeDashboard> createState() => _AttendeeDashboardState();
}

class _AttendeeDashboardState extends State<AttendeeDashboard>
    with SingleTickerProviderStateMixin {
  final _auth         = AuthService();
  final _reg          = RegistrationService();
  final _notif        = NotificationService();
  final _fdb          = FirebaseDatabaseService();
  final _fa           = FirebaseAnalyticsService();
  final _wish         = WishlistService();
  final _rating       = EventRatingService();
  final _gamification = GamificationService();

  StreamSubscription? _eventsSub;
  Map<String, dynamic>? _pendingRegistrationEvent;

  // Events tab filters
  final _searchCtrl  = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedOrganizerId;
  _TimeFilter _timeFilter = _TimeFilter.all;

  late final TabController _tabCtrl;

  static const _tabs = [
    'Events', 'Tickets', 'Saved', 'Calendar', 'Map', 'Alerts', 'Analytics', 'History'
  ];
  static const _tabIcons = [
    Icons.event_outlined,
    Icons.confirmation_num_outlined,
    Icons.bookmark_outline,
    Icons.calendar_month_outlined,
    Icons.map_outlined,
    Icons.notifications_outlined,
    Icons.bar_chart_outlined,
    Icons.history_outlined,
  ];

  // ── Getters ──────────────────────────────────────────────────────────────

  Set<String> get _registeredIds {
    if (!_auth.isLoggedIn) return {};
    return _reg
        .registrationsForAttendee(_auth.currentUser!.id)
        .map((r) => r['eventId'] as String)
        .toSet();
  }

  String get _userId => _auth.currentUser?.id ?? '';

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(_onTabChange);
    _searchCtrl.addListener(
        () => setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase()));
    _subscribeFirebase();
    // Log screen view
    _fa.logScreenView('attendee_dashboard',
        userId: _userId, role: 'attendee');
    if (_auth.isLoggedIn) {
      _fa.setUser(_userId, 'attendee');
    }
  }

  void _onTabChange() {
    setState(() {});
    if (_tabCtrl.indexIsChanging) {
      _fa.logTabView(_tabs[_tabCtrl.index], _userId);
    }
  }

  void _subscribeFirebase() {
    _eventsSub = _fdb.streamEvents().listen((fbEvents) {
      if (!mounted) return;
      for (final ev in fbEvents) {
        final exists = _auth.allEvents.any((e) => e['id'] == ev['id']);
        if (!exists) {
          final out = Map<String, dynamic>.from(ev);
          for (final k in ['start', 'end', 'createdAt']) {
            if (out[k] is int) {
              out[k] = DateTime.fromMillisecondsSinceEpoch(out[k] as int);
            }
          }
          _auth.seedEvents([out]);
        }
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _tabCtrl.removeListener(_onTabChange);
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data helpers ─────────────────────────────────────────────────────────

  String _organizerName(Map<String, dynamic> event) {
    final orgId = event['organizerId'] as String? ?? '';
    final match = _auth.allUsers.where((u) => u.id == orgId).toList();
    return match.isNotEmpty ? match.first.fullName : '';
  }

  String _locationLabel(Map<String, dynamic> event) {
    final bookingId = event['bookingId'] as String?;
    if (bookingId == null) return '';
    final booking =
        _auth.allBookings.where((b) => b['id'] == bookingId).toList();
    if (booking.isEmpty) return '';
    final roomId = booking.first['roomId'] as String? ?? '';
    final rooms = _auth.allRooms.where((r) => r['id'] == roomId).toList();
    if (rooms.isEmpty) return '';
    final room = rooms.first;
    final buildingId = room['buildingId'] as String? ?? '';
    final buildings =
        _auth.allBuildings.where((b) => b['id'] == buildingId).toList();
    final buildingName =
        buildings.isNotEmpty ? buildings.first['name'] as String : '';
    final roomName = room['name'] as String? ?? '';
    if (buildingName.isEmpty && roomName.isEmpty) return '';
    if (buildingName.isEmpty) return roomName;
    if (roomName.isEmpty) return buildingName;
    return '$buildingName · $roomName';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // ── Filtering ────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> events) {
    final now = DateTime.now();
    return events.where((e) {
      if ((e['status'] as String? ?? '') != 'published') return false;
      final title = (e['title'] as String? ?? '').toLowerCase();
      if (_searchQuery.isNotEmpty && !title.contains(_searchQuery)) return false;
      final cat = (e['category'] as String? ?? '');
      if (_selectedCategory != null && _selectedCategory != cat) return false;
      final orgId = (e['organizerId'] as String? ?? '');
      if (_selectedOrganizerId != null && _selectedOrganizerId != orgId) return false;
      final start = e['start'] as DateTime?;
      if (start != null) {
        switch (_timeFilter) {
          case _TimeFilter.today:
            if (start.day != now.day || start.month != now.month ||
                start.year != now.year) return false;
            break;
          case _TimeFilter.thisWeek:
            final weekEnd = now.add(const Duration(days: 7));
            if (start.isBefore(now) || start.isAfter(weekEnd)) return false;
            break;
          case _TimeFilter.thisMonth:
            if (start.month != now.month || start.year != now.year) return false;
            break;
          case _TimeFilter.all:
            break;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final sa = a['start'] as DateTime?;
        final sb = b['start'] as DateTime?;
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sa.compareTo(sb);
      });
  }

  List<Map<String, dynamic>> _getRecommendedEvents() {
    if (!_auth.isLoggedIn) return [];
    final now = DateTime.now();

    // Build weighted interest profile from registration history
    final myRegistered = _auth.allEvents
        .where((e) => _registeredIds.contains(e['id'] as String))
        .toList();

    final catWeights = <String, int>{};
    final orgWeights = <String, int>{};
    for (final e in myRegistered) {
      final cat = e['category'] as String? ?? '';
      if (cat.isNotEmpty) catWeights[cat] = (catWeights[cat] ?? 0) + 3;
      final org = e['organizerId'] as String? ?? '';
      if (org.isNotEmpty) orgWeights[org] = (orgWeights[org] ?? 0) + 2;
    }

    // Also boost from wishlist
    if (_auth.isLoggedIn) {
      for (final eid in _wish.savedFor(_userId)) {
        final ev = _auth.allEvents.where((e) => e['id'] == eid).toList();
        if (ev.isNotEmpty) {
          final cat = ev.first['category'] as String? ?? '';
          if (cat.isNotEmpty) catWeights[cat] = (catWeights[cat] ?? 0) + 1;
        }
      }
    }

    // Score every unregistered future published event
    final candidates = _auth.allEvents.where((e) =>
        e['status'] == 'published' &&
        !_registeredIds.contains(e['id'] as String) &&
        ((e['start'] as DateTime?)?.isAfter(now) ?? false));

    final scored = candidates.map((e) {
      final cat   = e['category']    as String? ?? '';
      final org   = e['organizerId'] as String? ?? '';
      final start = e['start']       as DateTime?;
      double score = 0;
      score += (catWeights[cat] ?? 0).toDouble();
      score += (orgWeights[org] ?? 0).toDouble();
      // Trending events get a small boost
      final regCount = _reg.countForEvent(e['id'] as String? ?? '');
      score += regCount * 0.4;
      // Events within the next 30 days get a recency boost
      if (start != null) {
        final days = start.difference(now).inDays;
        if (days <= 7)  score += 2.5;
        else if (days <= 30) score += 1.0;
      }
      return (event: e, score: score);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Max 2 per category for variety, cap at 6
    final result   = <Map<String, dynamic>>[];
    final catCount = <String, int>{};
    for (final item in scored) {
      final cat   = item.event['category'] as String? ?? '';
      final count = catCount[cat] ?? 0;
      if (count < 2) {
        result.add(item.event);
        catCount[cat] = count + 1;
        if (result.length >= 6) break;
      }
    }
    return result;
  }

  // ── Conflict check ───────────────────────────────────────────────────────

  Map<String, dynamic>? _conflictingEvent(Map<String, dynamic> newEvent) {
    final newStart = newEvent['start'] as DateTime?;
    final newEnd   = newEvent['end']   as DateTime?;
    if (newStart == null || newEnd == null) return null;
    for (final regId in _registeredIds) {
      final regEvents = _auth.allEvents.where((e) => e['id'] == regId).toList();
      if (regEvents.isEmpty) continue;
      final reg = regEvents.first;
      final regStart = reg['start'] as DateTime?;
      final regEnd   = reg['end']   as DateTime?;
      if (regStart == null || regEnd == null) continue;
      if (newStart.isBefore(regEnd) && newEnd.isAfter(regStart)) return reg;
    }
    return null;
  }

  // ── Registration ─────────────────────────────────────────────────────────

  Future<void> _toggleRegistration(Map<String, dynamic> event) async {
    if (!_auth.isLoggedIn) {
      _pendingRegistrationEvent = event;
      final ok = await UnifiedAuthSheet.show(
        context,
        intent: AuthIntent.attendeeRegister,
        defaultRole: UserRole.attendee,
      );
      if (!ok || !_auth.isLoggedIn) return;
      final pending = _pendingRegistrationEvent;
      _pendingRegistrationEvent = null;
      if (pending != null) _doRegister(pending);
      return;
    }
    _doRegister(event);
  }

  Future<void> _doRegister(Map<String, dynamic> event) async {
    final id   = event['id'] as String;
    final user = _auth.currentUser!;
    if (_reg.isRegistered(eventId: id, attendeeId: user.id)) {
      _reg.unregister(eventId: id, attendeeId: user.id);
      setState(() {});
      _showSnack('Unregistered from "${event['title']}".');
      _fa.logEventUnregistration(id, event['title'] as String? ?? '', user.id);
      return;
    }
    final conflict = _conflictingEvent(event);
    if (conflict != null) {
      _showConflictDialog(event, conflict);
      return;
    }
    _reg.register(
      eventId:       id,
      attendeeId:    user.id,
      attendeeName:  user.fullName,
      attendeeEmail: user.email,
    );
    setState(() {});
    _showSnack('Registered for "${event['title']}"!');
    _fa.logEventRegistration(id, event['title'] as String? ?? '', user.id, 'attendee');

    // Confirmation notification
    final start = event['start'] as DateTime?;
    _notif.addNotification(
      ownerId: user.id,
      title:   'Registration Confirmed',
      message: 'You\'re registered for "${event['title']}"'
          '${start != null ? ' on ${_formatDate(start)} at ${_formatTime(start)}' : ''}.',
      type: NotificationType.eventRegistered,
    );

    // ── Gamification ─────────────────────────────────────────────────────
    final regs        = _reg.registrationsForAttendee(user.id);
    final regCount    = regs.length;
    final attended    = regs.where((r) => r['attended'] == true).length;
    final myEvts      = _auth.allEvents
        .where((e) => regs.any((r) => r['eventId'] == e['id']))
        .toList();
    final catCount    = myEvts
        .map((e) => e['category'] as String? ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .length;
    final reviewCount = _rating.getUserRatingCount(user.id);
    final wishCount   = _wish.countFor(user.id);
    final isEarlyBird = start != null &&
        start.difference(DateTime.now()).inDays >= 7;

    final newBadges = await _gamification.checkAndAward(
      userId:            user.id,
      registrationCount: regCount,
      attendedCount:     attended,
      categoryCount:     catCount,
      reviewCount:       reviewCount,
      wishlistCount:     wishCount,
      isEarlyBird:       isEarlyBird,
    );

    if (newBadges.isNotEmpty && mounted) {
      final badge = newBadges.first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _gamification.badgeIcon(badge),
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Badge Earned: ${_gamification.badgeName(badge)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    Text(_gamification.badgeDescription(badge),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Color(_gamification.badgeColorHex(badge)),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showConflictDialog(
      Map<String, dynamic> newEvent, Map<String, dynamic> existing) {
    final existingStart = existing['start'] as DateTime?;
    final existingEnd   = existing['end']   as DateTime?;
    final timeStr = existingStart != null && existingEnd != null
        ? '${_formatTime(existingStart)} – ${_formatTime(existingEnd)} on ${_formatDate(existingStart)}'
        : '';

    // Find alternatives: same category, future, no conflict, not registered
    final category = newEvent['category'] as String? ?? '';
    final now      = DateTime.now();
    final alternatives = _auth.allEvents.where((e) {
      if (e['status'] != 'published') return false;
      if (_registeredIds.contains(e['id'])) return false;
      if (e['id'] == newEvent['id']) return false;
      if (e['id'] == existing['id']) return false;
      if ((e['category'] as String? ?? '') != category) return false;
      final s = e['start'] as DateTime?;
      if (s == null || s.isBefore(now)) return false;
      if (_conflictingEvent(e) != null) return false;
      return true;
    }).take(3).toList();

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _kWarning, size: 22),
            SizedBox(width: 8),
            Text('Schedule Conflict',
                style: TextStyle(
                    color: _kTextDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You already have another event at this time:',
                style: TextStyle(color: _kTextMid, height: 1.5),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kWarning.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(existing['title'] as String? ?? '',
                        style: const TextStyle(
                            color: _kTextDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.schedule_outlined,
                              size: 13, color: _kTextLight),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(timeStr,
                                style: const TextStyle(
                                    color: _kTextMid, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (alternatives.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 14, color: _kPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'Similar ${category.isNotEmpty ? category : "events"} you can attend:',
                      style: const TextStyle(
                          color: _kTextDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...alternatives.map((alt) {
                  final altStart = alt['start'] as DateTime?;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showEventDetail(alt);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kPrimaryLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _kPrimary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(alt['title'] as String? ?? '',
                                    style: const TextStyle(
                                        color: _kTextDark,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12),
                                    overflow: TextOverflow.ellipsis),
                                if (altStart != null)
                                  Text(
                                    '${_formatDate(altStart)} · ${_formatTime(altStart)}',
                                    style: const TextStyle(
                                        color: _kTextMid, fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              size: 16, color: _kPrimary),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(color: _kTextMid)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Event detail sheet ───────────────────────────────────────────────────

  void _showEventDetail(Map<String, dynamic> e) {
    final category    = (e['category']    as String? ?? '');
    final catColor    = _categoryColor(category);
    final start       = e['start']        as DateTime?;
    final end         = e['end']          as DateTime?;
    final location    = _locationLabel(e);
    final organizer   = _organizerName(e);
    final description = (e['description'] as String? ?? '');
    final capacity    = e['expectedAttendees'] as int? ?? 0;
    final eventId     = e['id']           as String? ?? '';

    _fa.logEventView(eventId, e['title'] as String? ?? '', _userId);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final isReg     = _registeredIds.contains(eventId);
          final isSaved   = _auth.isLoggedIn &&
              _wish.isSaved(_userId, eventId);

          return DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, ctrl) => SingleChildScrollView(
              controller: ctrl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Flat header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 44, height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                category.isEmpty ? 'Event' : category,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Spacer(),
                            // Save button
                            if (_auth.isLoggedIn)
                              GestureDetector(
                                onTap: () {
                                  _wish.toggle(_userId, eventId);
                                  if (!isSaved) {
                                    _fa.logSaveEvent(
                                        eventId,
                                        e['title'] as String? ?? '',
                                        _userId);
                                  }
                                  setS(() {});
                                  setState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isSaved
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            // Share button
                            GestureDetector(
                              onTap: () {
                                final title = e['title'] as String? ?? '';
                                final dateStr = start != null
                                    ? ' on ${_formatDate(start)}'
                                    : '';
                                Clipboard.setData(ClipboardData(
                                    text: '$title$dateStr'));
                                _showSnack('Event details copied!');
                                _fa.logShareEvent(
                                    eventId, title, _userId);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.share_outlined,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          e['title'] as String? ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Detail body
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (start != null)
                          _detailRow(Icons.schedule_outlined,
                              '${_formatDate(start)}${end != null ? ', ${_formatTime(start)} – ${_formatTime(end)}' : ''}'),
                        if (location.isNotEmpty)
                          _detailRow(Icons.location_on_outlined, location),
                        if (organizer.isNotEmpty)
                          _detailRow(Icons.person_outline,
                              'Organised by $organizer'),
                        if (capacity > 0)
                          _detailRow(Icons.people_outline,
                              '$capacity expected attendees'),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('About this event',
                              style: TextStyle(
                                  color: _kTextDark,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(description,
                              style: const TextStyle(
                                  color: _kTextMid,
                                  height: 1.6,
                                  fontSize: 14)),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _toggleRegistration(e);
                              setS(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isReg ? const Color(0xFFF1F5F9) : catColor,
                              foregroundColor:
                                  isReg ? _kTextDark : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: isReg
                                    ? const BorderSide(color: _kBorder)
                                    : BorderSide.none,
                              ),
                            ),
                            child: Text(
                              isReg
                                  ? 'Unregister from this event'
                                  : 'Register for this event',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),

                        // ── Rating section (past + registered) ───────────
                        if (_auth.isLoggedIn &&
                            isReg &&
                            start != null &&
                            start.isBefore(DateTime.now())) ...[
                          const SizedBox(height: 20),
                          _buildRatingSection(ctx, setS, eventId, catColor),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kPrimary, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: _kTextMid, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Rating section (inside event detail) ─────────────────────────────────

  Widget _buildRatingSection(
      BuildContext ctx, StateSetter setS, String eventId, Color catColor) {
    final userRating    = _rating.getUserRating(eventId, _userId);
    final hasRated      = _rating.hasRated(eventId, _userId);
    final avgRating     = _rating.getAverageRating(eventId);
    final ratingCount   = _rating.getRatingCount(eventId);
    final existingReview = _rating.getUserReview(eventId, _userId);
    final reviewCtrl    = TextEditingController(text: existingReview);
    double pickedRating = userRating?.toDouble() ?? 0;

    return StatefulBuilder(
      builder: (_, setR) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kPrimaryLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kPrimary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: _kWarning, size: 18),
                  const SizedBox(width: 6),
                  const Text('Rate this event',
                      style: TextStyle(
                          color: _kTextDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const Spacer(),
                  if (avgRating > 0) ...[
                    Text('${avgRating.toStringAsFixed(1)}',
                        style: const TextStyle(
                            color: _kTextDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    const Icon(Icons.star_rounded,
                        color: _kWarning, size: 13),
                    Text(' ($ratingCount)',
                        style: const TextStyle(
                            color: _kTextLight, fontSize: 11)),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Star picker
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final isFilled = i < pickedRating;
                  return GestureDetector(
                    onTap: () => setR(() => pickedRating = (i + 1).toDouble()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        isFilled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: isFilled ? _kWarning : _kTextLight,
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
              if (pickedRating > 0) ...[
                const SizedBox(height: 12),
                Text(
                  ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent!']
                      [pickedRating.toInt()],
                  style: TextStyle(
                      color: catColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 12),

              // Optional review text
              TextField(
                controller: reviewCtrl,
                maxLines: 2,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Write a short review (optional)…',
                  hintStyle: const TextStyle(
                      color: _kTextLight, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: _kPrimary.withOpacity(0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: _kPrimary.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: _kPrimary, width: 1.5),
                  ),
                  counterStyle: const TextStyle(
                      color: _kTextLight, fontSize: 10),
                ),
                style: const TextStyle(
                    color: _kTextDark, fontSize: 13),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(
                    hasRated
                        ? Icons.edit_outlined
                        : Icons.star_outline_rounded,
                    size: 16),
                  label: Text(hasRated ? 'Update rating' : 'Submit rating'),
                  onPressed: pickedRating == 0
                      ? null
                      : () async {
                          final user = _auth.currentUser!;
                          final sm = ScaffoldMessenger.of(context);
                          await _rating.submitRating(
                            eventId:  eventId,
                            userId:   user.id,
                            userName: user.fullName,
                            rating:   pickedRating,
                            review:   reviewCtrl.text.trim(),
                          );
                          // Gamification: check reviewer badge
                          final reviewCount =
                              _rating.getUserRatingCount(user.id);
                          if (reviewCount >= 3) {
                            await _gamification.checkAndAward(
                              userId: user.id,
                              registrationCount: _reg
                                  .registrationsForAttendee(user.id)
                                  .length,
                              attendedCount: 0,
                              categoryCount: 0,
                              reviewCount: reviewCount,
                              wishlistCount: 0,
                              isEarlyBird: false,
                            );
                          }
                          if (!mounted) return;
                          setR(() {});
                          setS(() {});
                          sm.showSnackBar(
                            SnackBar(
                              content: Text(hasRated
                                  ? 'Rating updated!'
                                  : 'Thanks for your rating!'),
                              backgroundColor: _kSuccess,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pickedRating == 0
                        ? _kBorder
                        : catColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _goToMyDashboard() {
    final u = _auth.currentUser;
    if (u == null) return;
    Widget screen;
    switch (u.role) {
      case UserRole.attendee:
        screen = const AttendeeDashboard();
        break;
      case UserRole.organizer:
        screen = const OrganizerDashboard();
        break;
      case UserRole.staff:
        screen = const StaffDashboard();
        break;
      case UserRole.superAdmin:
        screen = const SuperAdminDashboard();
        break;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => screen),
      (r) => false,
    );
  }

  Future<void> _handleAuthFromLanding() async {
    if (!_auth.isLoggedIn) return;
    final u = _auth.currentUser;
    if (u == null) return;
    if (u.role == UserRole.attendee) {
      _fa.setUser(u.id, 'attendee');
      setState(() {});
      return;
    }
    _goToMyDashboard();
  }

  // ── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unreadCount = _auth.isLoggedIn
        ? _notif.unreadCount(_auth.currentUser!.id)
        : 0;
    final savedCount = _auth.isLoggedIn
        ? _wish.countFor(_userId)
        : 0;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Tab bar ────────────────────────────────
              Container(
                color: _kSurface,
                child: TabBar(
                  controller: _tabCtrl,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: _kPrimary,
                  unselectedLabelColor: _kTextLight,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 12),
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(color: _kPrimary, width: 2.5),
                  ),
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: List.generate(_tabs.length, (i) {
                    final badge = _tabBadge(i, unreadCount, savedCount);
                    return Tab(
                      height: 44,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_tabIcons[i], size: 14),
                          const SizedBox(width: 5),
                          Text(_tabs[i]),
                          if (badge > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(
                                  color: _kPrimary, shape: BoxShape.circle),
                              child: Center(
                                child: Text(
                                  badge > 9 ? '9+' : '$badge',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ),
              ),

              // ── Tab views ──────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // 0 — Events
                    _eventsTab(),

                    // 1 — Tickets
                    AttendeeTicketsTab(
                      registeredIds: _registeredIds,
                      onEventTap: _showEventDetail,
                      locationLabel: _locationLabel,
                      organizerName: _organizerName,
                    ),

                    // 2 — Saved
                    AttendeeWishlistTab(
                      userId: _userId,
                      registeredIds: _registeredIds,
                      onEventTap: _showEventDetail,
                      onToggleRegistration: _toggleRegistration,
                      locationLabel: _locationLabel,
                      organizerName: _organizerName,
                    ),

                    // 3 — Calendar
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: AttendeeCalendarTab(
                        registeredIds: _registeredIds,
                        onToggleRegistration: _toggleRegistration,
                        onEventTap: _showEventDetail,
                        locationLabel: _locationLabel,
                        organizerName: _organizerName,
                      ),
                    ),

                    // 4 — Map
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: AttendeeMapTab(
                        registeredIds: _registeredIds,
                        onToggleRegistration: _toggleRegistration,
                        onEventTap: _showEventDetail,
                        locationLabel: _locationLabel,
                        organizerName: _organizerName,
                      ),
                    ),

                    // 5 — Alerts
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: AttendeeNotificationsTab(
                        registeredIds: _registeredIds,
                        onEventTap: _showEventDetail,
                      ),
                    ),

                    // 6 — Analytics
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: AttendeeAnalyticsTab(
                        registeredIds: _registeredIds,
                        userId: _userId,
                      ),
                    ),

                    // 7 — History
                    AttendeeHistoryTab(
                      registeredIds: _registeredIds,
                      onEventTap: _showEventDetail,
                      locationLabel: _locationLabel,
                      organizerName: _organizerName,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const AiChatbotWidget(),
        ],
      ),
    );
  }

  int _tabBadge(int i, int unread, int saved) {
    if (i == 5) return unread;   // Alerts
    if (i == 2) return saved;    // Saved
    return 0;
  }

  // ── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kSurface,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kPrimary, Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.event_outlined,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('EventFlow',
              style: TextStyle(
                  color: _kTextDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
        ],
      ),
      actions: [
        if (!_auth.isLoggedIn) ...[
          TextButton(
            onPressed: () async {
              final ok = await UnifiedAuthSheet.show(
                context,
                intent: AuthIntent.generic,
                defaultRole: UserRole.attendee,
              );
              if (!ok) return;
              await _handleAuthFromLanding();
            },
            child: const Text('Login',
                style: TextStyle(
                    color: _kPrimary, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: () async {
                final ok = await UnifiedAuthSheet.show(
                  context,
                  intent: AuthIntent.attendeeRegister,
                  defaultRole: UserRole.attendee,
                );
                if (!ok) return;
                await _handleAuthFromLanding();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
              ),
              child: const Text('Sign up'),
            ),
          ),
        ] else ...[
          TextButton(
            onPressed: _goToMyDashboard,
            child: const Text('Dashboard',
                style: TextStyle(
                    color: _kPrimary, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: _kTextDark),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ProfileScreen()),
            ).then((_) => setState(() {})),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: _kTextDark),
            tooltip: 'Logout',
            onPressed: () {
              _auth.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => const LandingScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ],
    );
  }

  // ── Events Tab ───────────────────────────────────────────────────────────

  Widget _eventsTab() {
    final allEvents      = _auth.allEvents;
    final filteredEvents = _applyFilters(allEvents);
    final now            = DateTime.now();
    final upcomingEvents = filteredEvents
        .where((e) => (e['start'] as DateTime?)?.isAfter(now) ?? false)
        .take(5)
        .toList();
    final myEvents = allEvents
        .where((e) => _registeredIds.contains(e['id'] as String))
        .toList()
      ..sort((a, b) {
        final sa = a['start'] as DateTime?;
        final sb = b['start'] as DateTime?;
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sa.compareTo(sb);
      });

    final categories = allEvents
        .map((e) => e['category'] as String? ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final organizers = _auth.allUsers
        .where((u) => u.role == UserRole.organizer)
        .toList();
    final recommended = _getRecommendedEvents();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome banner
          _welcomeBanner(),
          const SizedBox(height: 20),

          // Stats row
          _statsRow(allEvents.length),
          const SizedBox(height: 24),

          // Recommended for you
          if (recommended.isNotEmpty) ...[
            _sectionHeader('Recommended for You',
                Icons.auto_awesome_outlined),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recommended.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) =>
                    _upcomingEventCard(recommended[i]),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // My Schedule
          if (myEvents.isNotEmpty) ...[
            _sectionHeader('My Schedule', Icons.calendar_today_outlined),
            const SizedBox(height: 10),
            ...myEvents.take(3).map((e) => _myScheduleTile(e)),
            if (myEvents.length > 3)
              GestureDetector(
                onTap: () => _tabCtrl.animateTo(1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('View all ${myEvents.length} tickets',
                          style: const TextStyle(
                              color: _kPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios,
                          size: 12, color: _kPrimary),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],

          // Upcoming Events carousel
          _sectionHeader('Upcoming Events', Icons.upcoming_outlined),
          const SizedBox(height: 10),
          if (upcomingEvents.isEmpty)
            _emptyState('No upcoming events right now.')
          else
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: upcomingEvents.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) =>
                    _upcomingEventCard(upcomingEvents[i]),
              ),
            ),
          const SizedBox(height: 24),

          // Search + filters
          _sectionHeader('Browse All Events', Icons.search_outlined),
          const SizedBox(height: 10),
          _searchBar(),
          const SizedBox(height: 8),
          _filterRow(categories, organizers),
          const SizedBox(height: 12),

          // Events list
          if (filteredEvents.isEmpty)
            _emptyState(
              _searchQuery.isNotEmpty
                  ? 'No events match "$_searchQuery".'
                  : 'No events found for the selected filters.',
            )
          else
            ...filteredEvents.map((e) => _eventCard(e)),

          const SizedBox(height: 20),
          _venueOwnerBanner(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Section header ───────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _kPrimary, size: 17),
        const SizedBox(width: 7),
        Text(title,
            style: const TextStyle(
                color: _kTextDark,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ── Welcome banner ───────────────────────────────────────────────────────

  Widget _welcomeBanner() {
    final user = _auth.currentUser;
    final greeting = user != null
        ? 'Welcome back, ${user.fullName.split(' ').first}!'
        : 'Discover Events Near You';
    final subtitle = user != null
        ? 'Browse, register, and manage your event schedule.'
        : 'Sign in to register for events and build your personal schedule.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC46A3D), Color(0xFFB85E2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.2)),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        height: 1.4)),
                if (!_auth.isLoggedIn) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () async {
                        final ok = await UnifiedAuthSheet.show(
                          context,
                          intent: AuthIntent.attendeeRegister,
                          defaultRole: UserRole.attendee,
                        );
                        if (!ok) return;
                        await _handleAuthFromLanding();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _kPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Get Started Free'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _heroBadge(
                          '${_registeredIds.length}', 'Registered'),
                      const SizedBox(width: 10),
                      _heroBadge(
                          '${_wish.countFor(_userId)}', 'Saved'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.event_outlined,
                color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _heroBadge(String value, String label) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$value $label',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }

  // ── Stats row ────────────────────────────────────────────────────────────

  Widget _statsRow(int totalEvents) {
    final upcomingCount = _auth.allEvents.where((e) {
      final start = e['start'] as DateTime?;
      return start != null &&
          start.isAfter(DateTime.now()) &&
          e['status'] == 'published';
    }).length;

    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Available',
            value: '$totalEvents',
            icon: Icons.event_available_outlined,
            color: _kPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'Registered',
            value: '${_registeredIds.length}',
            icon: Icons.confirmation_num_outlined,
            color: _kSuccess,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'Upcoming',
            value: '$upcomingCount',
            icon: Icons.schedule_outlined,
            color: _kWarning,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label,
              style:
                  const TextStyle(color: _kTextLight, fontSize: 11)),
        ],
      ),
    );
  }

  // ── My Schedule tile ─────────────────────────────────────────────────────

  Widget _myScheduleTile(Map<String, dynamic> e) {
    final start    = e['start']    as DateTime?;
    final end      = e['end']      as DateTime?;
    final location = _locationLabel(e);
    final category = (e['category'] as String? ?? '');
    final catColor = _categoryColor(category);

    return GestureDetector(
      onTap: () => _showEventDetail(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            // Date badge
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: catColor.withOpacity(0.3)),
              ),
              child: start != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${start.day}',
                            style: TextStyle(
                                color: catColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        Text(_formatDate(start).split(' ')[1],
                            style: TextStyle(
                                color: catColor.withOpacity(0.7),
                                fontSize: 10)),
                      ],
                    )
                  : Icon(Icons.event, color: catColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e['title'] as String? ?? '',
                      style: const TextStyle(
                          color: _kTextDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  if (start != null)
                    Text(
                      '${_formatTime(start)}${end != null ? ' – ${_formatTime(end)}' : ''}',
                      style: const TextStyle(
                          color: _kTextMid, fontSize: 12),
                    ),
                  if (location.isNotEmpty)
                    Text(location,
                        style: const TextStyle(
                            color: _kTextLight, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                category.isEmpty ? 'Event' : category,
                style: TextStyle(
                    color: catColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Upcoming event card (horizontal) ─────────────────────────────────────

  Widget _upcomingEventCard(Map<String, dynamic> e) {
    final category  = (e['category'] as String? ?? '');
    final catColor  = _categoryColor(category);
    final start     = e['start'] as DateTime?;
    final end       = e['end']   as DateTime?;
    final location  = _locationLabel(e);
    final organizer = _organizerName(e);
    final registered = _registeredIds.contains(e['id'] as String);
    final isSaved = _auth.isLoggedIn &&
        _wish.isSaved(_userId, e['id'] as String? ?? '');

    return GestureDetector(
      onTap: () => _showEventDetail(e),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: registered ? _kSuccess : _kBorder,
            width: registered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: catColor.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header strip
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                border: Border(
                    bottom: BorderSide(
                        color: catColor.withOpacity(0.2))),
              ),
              child: Row(
                children: [
                  Text(
                    category.isEmpty ? 'Event' : category,
                    style: TextStyle(
                        color: catColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (registered)
                    Icon(Icons.check_circle, color: _kSuccess, size: 14)
                  else if (_auth.isLoggedIn)
                    GestureDetector(
                      onTap: () {
                        _wish.toggle(
                            _userId, e['id'] as String? ?? '');
                        setState(() {});
                      },
                      child: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: isSaved ? _kPrimary : _kTextLight,
                        size: 14,
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e['title'] as String? ?? '',
                      style: const TextStyle(
                          color: _kTextDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (start != null)
                      _miniChip(Icons.schedule_outlined,
                          '${_formatDate(start)}, ${_formatTime(start)}${end != null ? '–${_formatTime(end)}' : ''}'),
                    if (location.isNotEmpty)
                      _miniChip(Icons.location_on_outlined, location),
                    const Spacer(),
                    Row(
                      children: [
                        if (organizer.isNotEmpty)
                          Expanded(
                            child: Text('By $organizer',
                                style: const TextStyle(
                                    color: _kTextLight, fontSize: 10),
                                overflow: TextOverflow.ellipsis),
                          ),
                        GestureDetector(
                          onTap: () => _toggleRegistration(e),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: registered
                                  ? _kSuccessLight
                                  : _kPrimary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              registered ? 'Going ✓' : 'Register',
                              style: TextStyle(
                                color: registered
                                    ? _kSuccess
                                    : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, color: _kTextLight, size: 11),
          const SizedBox(width: 3),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: _kTextMid, fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ── Event list card ──────────────────────────────────────────────────────

  Widget _eventCard(Map<String, dynamic> e) {
    final registered  = _registeredIds.contains(e['id'] as String);
    final category    = (e['category'] as String? ?? '');
    final catColor    = _categoryColor(category);
    final start       = e['start']        as DateTime?;
    final end         = e['end']          as DateTime?;
    final location    = _locationLabel(e);
    final organizer   = _organizerName(e);
    final description = (e['description'] as String? ?? '');
    final capacity    = e['expectedAttendees'] as int? ?? 0;
    final eventId     = e['id'] as String? ?? '';
    final isSaved     = _auth.isLoggedIn && _wish.isSaved(_userId, eventId);

    return GestureDetector(
      onTap: () => _showEventDetail(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: registered ? _kSuccess : _kBorder,
            width: registered ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left accent strip
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: catColor,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(13)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category.isEmpty ? 'Event' : category,
                            style: TextStyle(
                                color: catColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Spacer(),
                        if (registered)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _kSuccessLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle,
                                    color: _kSuccess, size: 10),
                                SizedBox(width: 3),
                                Text('Registered',
                                    style: TextStyle(
                                        color: _kSuccess,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        const SizedBox(width: 6),
                        // Save button
                        if (_auth.isLoggedIn)
                          GestureDetector(
                            onTap: () {
                              _wish.toggle(_userId, eventId);
                              if (!isSaved) {
                                _fa.logSaveEvent(
                                    eventId,
                                    e['title'] as String? ?? '',
                                    _userId);
                              }
                              setState(() {});
                            },
                            child: Icon(
                              isSaved
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: isSaved ? _kPrimary : _kTextLight,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e['title'] as String? ?? '',
                      style: const TextStyle(
                          color: _kTextDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                            color: _kTextMid,
                            fontSize: 12,
                            height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (start != null)
                          _metaChip(Icons.schedule_outlined,
                              '${_formatDate(start)}  ${_formatTime(start)}${end != null ? '–${_formatTime(end)}' : ''}'),
                        if (location.isNotEmpty)
                          _metaChip(Icons.location_on_outlined, location),
                        if (organizer.isNotEmpty)
                          _metaChip(Icons.person_outline, organizer),
                        if (capacity > 0)
                          _metaChip(
                              Icons.people_outline, '$capacity expected'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () => _toggleRegistration(e),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              registered ? _kSuccessLight : _kPrimary,
                          foregroundColor:
                              registered ? _kSuccess : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: registered
                                ? const BorderSide(
                                    color: _kSuccess, width: 1)
                                : BorderSide.none,
                          ),
                          textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        child: Text(registered
                            ? '✓ Registered — Tap to unregister'
                            : 'Register for this event'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _kTextLight, size: 12),
        const SizedBox(width: 4),
        Text(text,
            style:
                const TextStyle(color: _kTextMid, fontSize: 12)),
      ],
    );
  }

  // ── Search bar ───────────────────────────────────────────────────────────

  Widget _searchBar() {
    return TextField(
      controller: _searchCtrl,
      style: const TextStyle(color: _kTextDark),
      onSubmitted: (q) {
        if (q.trim().isNotEmpty) _fa.logSearch(q.trim(), userId: _userId);
      },
      decoration: InputDecoration(
        hintText: 'Search events by name…',
        hintStyle: const TextStyle(color: _kTextLight),
        prefixIcon:
            const Icon(Icons.search, color: _kPrimary, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close,
                    color: _kTextMid, size: 18),
                onPressed: _searchCtrl.clear,
              )
            : null,
        filled: true,
        fillColor: _kSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  // ── Filter row ───────────────────────────────────────────────────────────

  Widget _filterRow(
      List<String> categories, List<UserModel> organizers) {
    final hasFilter = _selectedCategory != null ||
        _selectedOrganizerId != null ||
        _timeFilter != _TimeFilter.all ||
        _searchQuery.isNotEmpty;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterDropdown<_TimeFilter>(
            icon: Icons.schedule_outlined,
            label: _timeFilterLabels[_timeFilter]!,
            value: _timeFilter,
            items: _TimeFilter.values
                .map((f) => DropdownMenuItem(
                    value: f, child: Text(_timeFilterLabels[f]!)))
                .toList(),
            onChanged: (v) => setState(() => _timeFilter = v!),
          ),
          const SizedBox(width: 8),
          _FilterDropdown<String?>(
            icon: Icons.category_outlined,
            label: _selectedCategory ?? 'Category',
            value: _selectedCategory,
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('All Categories')),
              ...categories.map(
                (c) => DropdownMenuItem<String?>(
                    value: c, child: Text(c)),
              ),
            ],
            onChanged: (v) =>
                setState(() => _selectedCategory = v),
          ),
          const SizedBox(width: 8),
          _FilterDropdown<String?>(
            icon: Icons.person_outline,
            label: _selectedOrganizerId != null
                ? organizers
                        .where((o) => o.id == _selectedOrganizerId)
                        .map((o) => o.fullName.split(' ').first)
                        .firstOrNull ??
                    'Organizer'
                : 'Organizer',
            value: _selectedOrganizerId,
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('All Organizers')),
              ...organizers.map(
                (o) => DropdownMenuItem<String?>(
                    value: o.id, child: Text(o.fullName)),
              ),
            ],
            onChanged: (v) =>
                setState(() => _selectedOrganizerId = v),
          ),
          if (hasFilter) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() {
                  _selectedCategory    = null;
                  _selectedOrganizerId = null;
                  _timeFilter          = _TimeFilter.all;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _kPrimary.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.close, color: _kPrimary, size: 13),
                    SizedBox(width: 4),
                    Text('Clear',
                        style: TextStyle(
                            color: _kPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Venue owner promo ────────────────────────────────────────────────────

  Widget _venueOwnerBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kPrimaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPrimary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Own a venue?',
                    style: TextStyle(
                        color: _kPrimaryDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                SizedBox(height: 4),
                Text('List your space and get booked by organizers.',
                    style:
                        TextStyle(color: _kTextMid, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () async {
              if (!_auth.isLoggedIn) {
                final ok = await UnifiedAuthSheet.show(
                  context,
                  intent: AuthIntent.ownerListVenue,
                  defaultRole: UserRole.staff,
                );
                if (!ok) return;
              }
              if (!_auth.isLoggedIn) return;
              final u = _auth.currentUser!;
              if (u.role != UserRole.staff) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => const StaffDashboard()),
                (r) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              textStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: Size.zero,
            ),
            child: const Text('List Venue'),
          ),
        ],
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────

  Widget _emptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_outlined,
              size: 40, color: _kTextLight),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _kTextMid, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Filter Dropdown widget ────────────────────────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: _kTextMid),
          style: const TextStyle(
              color: _kTextDark, fontSize: 12),
          isDense: true,
          hint: Row(
            children: [
              Icon(icon, size: 13, color: _kPrimary),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      color: _kTextDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          selectedItemBuilder: (_) => items.map((item) {
            return Row(
              children: [
                Icon(icon, size: 13, color: _kPrimary),
                const SizedBox(width: 5),
                Text(label,
                    style: const TextStyle(
                        color: _kTextDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
