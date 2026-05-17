import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/auth_service.dart';
import '../../../services/firebase_database_service.dart';
import '../../../services/registration_service.dart';
import '../../../services/event_rating_service.dart';
import '../../../services/gamification_service.dart';
import '../../../models/user_model.dart';

// ── Theme constants — Warm Minimal SaaS ───────────────────────────────────

const _kPrimary      = Color(0xFFC46A3D);
const _kPrimaryLight = Color(0xFFFFF1E8);
const _kTextDark     = Color(0xFF1F1A17);
const _kTextMid      = Color(0xFF6E6258);
const _kTextLight    = Color(0xFFA09489);
const _kBorder       = Color(0xFFE9E1D6);
const _kBg           = Color(0xFFFAF7F2);
const _kSurface      = Color(0xFFFFFFFF);
const _kSuccess      = Color(0xFF3D7A5A);
const _kWarning      = Color(0xFFB7791F);

// ── Category colours ──────────────────────────────────────────────────────

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

const _chartPalette = [
  Color(0xFFC46A3D), Color(0xFF5A6F8C), Color(0xFF3D7A5A),
  Color(0xFFB7791F), Color(0xFF6E6258), Color(0xFFC24A3A),
  Color(0xFF5A6F8C), Color(0xFF3D7A5A),
];

Color _catColor(String c) => _categoryColors[c] ?? _kPrimary;

// ─────────────────────────────────────────────────────────────────────────────

class AttendeeAnalyticsTab extends StatefulWidget {
  final Set<String> registeredIds;
  final String userId;

  const AttendeeAnalyticsTab({
    super.key,
    required this.registeredIds,
    this.userId = '',
  });

  @override
  State<AttendeeAnalyticsTab> createState() => _AttendeeAnalyticsTabState();
}

class _AttendeeAnalyticsTabState extends State<AttendeeAnalyticsTab> {
  final _auth         = AuthService();
  final _fdb          = FirebaseDatabaseService();
  final _reg          = RegistrationService();
  final _rating       = EventRatingService();
  final _gamification = GamificationService();

  int? _touchedPieIndex;
  int? _touchedRegPieIndex;

  StreamSubscription? _analyticsSub;
  StreamSubscription? _badgesSub;
  List<Map<String, dynamic>> _fbAnalytics = [];

  List<Map<String, dynamic>> get _allPublished => _auth.allEvents
      .where((e) => e['status'] == 'published')
      .toList();

  List<Map<String, dynamic>> get _myEvents => _allPublished
      .where((e) => widget.registeredIds.contains(e['id'] as String))
      .toList();

  String _organizerName(String orgId) {
    final match = _auth.allUsers.where((u) => u.id == orgId).toList();
    return match.isNotEmpty ? match.first.fullName : 'Unknown';
  }

  @override
  void initState() {
    super.initState();
    _subscribeAnalytics();
    _subscribeBadges();
  }

  void _subscribeAnalytics() {
    if (widget.userId.isEmpty) return;
    _analyticsSub = _fdb.streamAnalyticsEvents().listen((events) {
      if (!mounted) return;
      setState(() {
        _fbAnalytics = events
            .where((e) => e['userId'] == widget.userId)
            .toList();
      });
    });
  }

  void _subscribeBadges() {
    if (widget.userId.isEmpty) return;
    _badgesSub = _fdb.streamBadgesForUser(widget.userId).listen((list) {
      if (!mounted) return;
      _gamification.loadFromFirebase(widget.userId, list);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _analyticsSub?.cancel();
    _badgesSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all      = _allPublished;
    final my       = _myEvents;
    final now      = DateTime.now();
    final upcoming = all
        .where((e) =>
            (e['start'] as DateTime?)?.isAfter(now) ?? false)
        .length;

    // Firebase analytics breakdown
    final eventViews = _fbAnalytics
        .where((e) => e['eventName'] == 'event_view')
        .length;
    final registrationEvents = _fbAnalytics
        .where((e) => e['eventName'] == 'event_registration')
        .length;
    final searches = _fbAnalytics
        .where((e) => e['eventName'] == 'search')
        .length;
    final tabViews = _fbAnalytics
        .where((e) => e['eventName'] == 'tab_view')
        .length;

    // Participation stats
    final regs        = widget.userId.isEmpty
        ? <Map<String, dynamic>>[]
        : _reg.registrationsForAttendee(widget.userId);
    final attended    = regs.where((r) => r['attended'] == true).length;
    final catBreadth  = my
        .map((e) => e['category'] as String? ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .length;
    final reviewCount = _rating.getUserRatingCount(widget.userId);
    final badges      = _gamification.badgesFor(widget.userId);
    final points      = _gamification.totalPoints(widget.userId);
    final level       = _gamification.levelTitle(points);
    final attRate     = my.isNotEmpty
        ? (attended / my.length * 100).toStringAsFixed(0)
        : '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Firebase Analytics banner ───────────────────────
        _firebaseBanner(eventViews, registrationEvents, searches),
        const SizedBox(height: 24),

        // ── Gamification / Badges ───────────────────────────
        if (widget.userId.isNotEmpty) ...[
          _sectionLabel('My Achievements', Icons.emoji_events_outlined),
          const SizedBox(height: 12),
          _badgesSection(badges, points, level),
          const SizedBox(height: 24),
        ],

        // ── Personal Overview ───────────────────────────────
        _sectionLabel('My Event Overview', Icons.person_outline),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard(
              icon: Icons.event_available_outlined,
              value: '${all.length}',
              label: 'Total Events',
              color: _kPrimary,
            )),
            const SizedBox(width: 10),
            Expanded(child: _statCard(
              icon: Icons.confirmation_num_outlined,
              value: '${my.length}',
              label: 'Registered',
              color: _kSuccess,
            )),
            const SizedBox(width: 10),
            Expanded(child: _statCard(
              icon: Icons.upcoming_outlined,
              value: '$upcoming',
              label: 'Upcoming',
              color: _kWarning,
            )),
          ],
        ),
        const SizedBox(height: 12),
        // Participation & engagement row
        Row(
          children: [
            Expanded(child: _statCard(
              icon: Icons.check_circle_outlined,
              value: '$attended',
              label: 'Attended',
              color: _kSuccess,
            )),
            const SizedBox(width: 10),
            Expanded(child: _statCard(
              icon: Icons.trending_up_outlined,
              value: '$attRate%',
              label: 'Attend Rate',
              color: const Color(0xFF5A6F8C),
            )),
            const SizedBox(width: 10),
            Expanded(child: _statCard(
              icon: Icons.star_outline_rounded,
              value: '$reviewCount',
              label: 'Reviews',
              color: _kWarning,
            )),
          ],
        ),
        const SizedBox(height: 24),

        // ── Activity Metrics ────────────────────────────────
        _sectionLabel('Activity Metrics', Icons.analytics_outlined),
        const SizedBox(height: 12),
        _activityMetrics(eventViews, registrationEvents, searches, tabViews),
        const SizedBox(height: 24),

        // ── Registration donut ──────────────────────────────
        _sectionLabel('Registration Rate', Icons.donut_small_outlined),
        const SizedBox(height: 12),
        _registrationPie(my.length, all.length - my.length),
        const SizedBox(height: 24),

        // ── Category breakdown (my events) ──────────────────
        if (my.isNotEmpty) ...[
          _sectionLabel('My Events by Category', Icons.category_outlined),
          const SizedBox(height: 12),
          _categoryPie(my),
          const SizedBox(height: 24),
        ],

        // ── All events by category bar chart ────────────────
        if (all.isNotEmpty) ...[
          _sectionLabel('All Events by Category', Icons.bar_chart_outlined),
          const SizedBox(height: 12),
          _categoryBarChart(all),
          const SizedBox(height: 24),
        ],

        // ── Top organizers ──────────────────────────────────
        if (all.isNotEmpty) ...[
          _sectionLabel('Events by Organizer', Icons.people_outline),
          const SizedBox(height: 12),
          _organizerList(all),
          const SizedBox(height: 24),
        ],

        // ── Timeline ────────────────────────────────────────
        _sectionLabel('Events Timeline (Next 6 Months)',
            Icons.timeline_outlined),
        const SizedBox(height: 12),
        _timelineChart(all),
        const SizedBox(height: 24),

        // ── Firebase Activity Log ────────────────────────────
        if (_fbAnalytics.isNotEmpty) ...[
          _sectionLabel('Firebase Activity Log',
              Icons.cloud_outlined),
          const SizedBox(height: 8),
          ..._fbAnalytics.reversed.take(8).map(_activityLogTile),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  // ── Badges / Gamification ────────────────────────────────────────────────

  Widget _badgesSection(Set<BadgeType> earned, int points, String level) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kPrimary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_outlined,
                        color: _kPrimary, size: 13),
                    const SizedBox(width: 5),
                    Text(level,
                        style: const TextStyle(
                            color: _kPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const Spacer(),
              Text('$points pts',
                  style: const TextStyle(
                      color: _kTextDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (points % 30) / 30,
              backgroundColor: _kBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${earned.length} of ${BadgeType.values.length} badges earned',
            style: const TextStyle(color: _kTextLight, fontSize: 10),
          ),
          const SizedBox(height: 16),

          // Badge grid
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: BadgeType.values.map((b) {
              final isEarned = earned.contains(b);
              final color    = Color(_gamification.badgeColorHex(b));
              return Tooltip(
                message: isEarned
                    ? '${_gamification.badgeName(b)}: ${_gamification.badgeDescription(b)}'
                    : '${_gamification.badgeName(b)} — ${_gamification.badgeRequirement(b)}',
                child: Container(
                  width: 58,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isEarned
                        ? color.withOpacity(0.10)
                        : _kBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isEarned
                          ? color.withOpacity(0.35)
                          : _kBorder,
                      width: isEarned ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _gamification.badgeIcon(b),
                        size: 22,
                        color: isEarned ? color : _kTextLight,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _gamification.badgeName(b).split(' ').first,
                        style: TextStyle(
                            color: isEarned ? _kTextDark : _kTextLight,
                            fontSize: 7,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Firebase banner ───────────────────────────────────────────────────────

  Widget _firebaseBanner(int views, int regs, int searches) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kPrimary.withOpacity(0.2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.analytics_outlined, color: _kPrimary, size: 12),
                    SizedBox(width: 4),
                    Text('Live Analytics',
                        style: TextStyle(
                            color: _kPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                    color: Color(0xFF3D7A5A), shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              const Text('Connected',
                  style: TextStyle(
                      color: _kSuccess,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _fbStat('$views', 'Event Views', Icons.visibility_outlined),
              _fbStat('$regs', 'Registrations', Icons.confirmation_num_outlined),
              _fbStat('$searches', 'Searches', Icons.search_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fbStat(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: _kPrimary, size: 16),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: _kTextLight, fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── Activity metrics ──────────────────────────────────────────────────────

  Widget _activityMetrics(int views, int regs, int searches, int tabs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _metricRow('Event views tracked', '$views', Icons.visibility_outlined, _kPrimary),
          const Divider(height: 16, color: _kBorder),
          _metricRow('Registrations tracked', '$regs', Icons.confirmation_num_outlined, _kSuccess),
          const Divider(height: 16, color: _kBorder),
          _metricRow('Searches performed', '$searches', Icons.search_outlined, _kWarning),
          const Divider(height: 16, color: _kBorder),
          _metricRow('Tab navigation events', '$tabs', Icons.tab_outlined, _kPrimary),
          const Divider(height: 16, color: _kBorder),
          _metricRow('Total tracked events', '${_fbAnalytics.length}', Icons.analytics_outlined, _kTextMid),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: _kTextMid, fontSize: 13)),
        ),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
      ],
    );
  }

  // ── Activity log tile ─────────────────────────────────────────────────────

  Widget _activityLogTile(Map<String, dynamic> event) {
    final name = event['eventName'] as String? ?? 'event';
    final ts   = event['timestamp'] as int?;
    final time = ts != null
        ? _relativeTime(DateTime.fromMillisecondsSinceEpoch(ts))
        : 'Recently';

    final (icon, color) = switch (name) {
      'event_view'         => (Icons.visibility_outlined, _kPrimary),
      'event_registration' => (Icons.confirmation_num_outlined, _kSuccess),
      'search'             => (Icons.search_outlined, _kWarning),
      'tab_view'           => (Icons.tab_outlined, _kPrimary),
      'save_event'         => (Icons.bookmark_outline, const Color(0xFF6E6258)),
      'share_event'        => (Icons.share_outlined, const Color(0xFF6E6258)),
      _                    => (Icons.analytics_outlined, _kTextMid),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _eventNameLabel(name, event),
              style: const TextStyle(color: _kTextDark, fontSize: 12),
            ),
          ),
          Text(time,
              style: const TextStyle(
                  color: _kTextLight, fontSize: 11)),
        ],
      ),
    );
  }

  String _eventNameLabel(String name, Map<String, dynamic> event) {
    final params = event['params'] as Map?;
    switch (name) {
      case 'event_view':
        return 'Viewed: ${params?['event_title'] ?? 'an event'}';
      case 'event_registration':
        return 'Registered: ${params?['event_title'] ?? 'an event'}';
      case 'search':
        return 'Searched for: "${params?['query'] ?? ''}"';
      case 'tab_view':
        return 'Visited ${params?['tab'] ?? 'a'} tab';
      case 'save_event':
        return 'Saved: ${params?['event_title'] ?? 'an event'}';
      case 'share_event':
        return 'Shared: ${params?['event_title'] ?? 'an event'}';
      case 'screen_view':
        return 'Opened ${params?['screen_name'] ?? 'a screen'}';
      default:
        return name.replaceAll('_', ' ');
    }
  }

  String _relativeTime(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _kPrimary, size: 16),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(
                color: _kTextDark,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style:
                  const TextStyle(color: _kTextLight, fontSize: 10)),
        ],
      ),
    );
  }

  // ── Registration donut ────────────────────────────────────────────────────

  Widget _registrationPie(int registered, int available) {
    if (registered == 0 && available == 0) {
      return _chartEmpty('No events available.');
    }
    final total  = registered + available;
    final regPct = total > 0
        ? (registered / total * 100).toStringAsFixed(1)
        : '0';

    final sections = <PieChartSectionData>[
      PieChartSectionData(
        value: registered.toDouble(),
        color: _kPrimary,
        title: registered > 0 ? '$registered' : '',
        titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700),
        radius: _touchedRegPieIndex == 0 ? 64 : 56,
      ),
      PieChartSectionData(
        value: available > 0 ? available.toDouble() : 0.001,
        color: _kBorder,
        title: available > 0 ? '$available' : '',
        titleStyle: const TextStyle(
            color: _kTextMid,
            fontSize: 12,
            fontWeight: FontWeight.w700),
        radius: _touchedRegPieIndex == 1 ? 64 : 56,
      ),
    ];

    return Row(
      children: [
        SizedBox(
          width: 160, height: 160,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 44,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (evt, res) {
                  setState(() {
                    if (res?.touchedSection == null ||
                        evt is FlPointerExitEvent) {
                      _touchedRegPieIndex = null;
                    } else {
                      _touchedRegPieIndex =
                          res!.touchedSection!.touchedSectionIndex;
                    }
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$regPct%',
                  style: const TextStyle(
                      color: _kPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
              const Text('registration rate',
                  style: TextStyle(color: _kTextMid, fontSize: 12)),
              const SizedBox(height: 14),
              _legendRow(_kPrimary, 'Registered ($registered)'),
              const SizedBox(height: 6),
              _legendRow(_kBorder, 'Available ($available)',
                  border: _kBorder),
            ],
          ),
        ),
      ],
    );
  }

  // ── Category pie ──────────────────────────────────────────────────────────

  Widget _categoryPie(List<Map<String, dynamic>> events) {
    final counts = <String, int>{};
    for (final e in events) {
      final cat = (e['category'] as String? ?? 'Other');
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    if (counts.isEmpty) return _chartEmpty('No registered events yet.');

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = entries.asMap().entries.map((entry) {
      final i   = entry.key;
      final cat = entry.value.key;
      final cnt = entry.value.value;
      return PieChartSectionData(
        value: cnt.toDouble(),
        color: _catColor(cat),
        title: cnt > 0 ? '$cnt' : '',
        titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700),
        radius: _touchedPieIndex == i ? 68 : 58,
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 0,
              pieTouchData: PieTouchData(
                touchCallback: (evt, res) {
                  setState(() {
                    if (res?.touchedSection == null ||
                        evt is FlPointerExitEvent) {
                      _touchedPieIndex = null;
                    } else {
                      _touchedPieIndex =
                          res!.touchedSection!.touchedSectionIndex;
                    }
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: entries.map((e) {
            return _legendRow(_catColor(e.key), '${e.key} (${e.value})');
          }).toList(),
        ),
      ],
    );
  }

  // ── Category bar chart ────────────────────────────────────────────────────

  Widget _categoryBarChart(List<Map<String, dynamic>> events) {
    final counts = <String, int>{};
    for (final e in events) {
      final cat = (e['category'] as String? ?? 'Other');
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    if (counts.isEmpty) return _chartEmpty('No event data.');

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal =
        entries.fold<int>(0, (m, e) => e.value > m ? e.value : m).toDouble();

    final groups = entries.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.value.toDouble(),
            color: _catColor(entry.value.key),
            width: 14,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ],
      );
    }).toList();

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          barGroups: groups,
          maxY: maxVal + 1,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: _kBorder, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (v, _) => Text(
                  v.toInt() == v ? '${v.toInt()}' : '',
                  style: const TextStyle(
                      color: _kTextLight, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  final cat = entries[i].key;
                  final short =
                      cat.length > 5 ? '${cat.substring(0, 4)}.' : cat;
                  return Transform.rotate(
                    angle: -0.4,
                    child: Text(short,
                        style: const TextStyle(
                            color: _kTextMid, fontSize: 9)),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
        ),
      ),
    );
  }

  // ── Organizer list ────────────────────────────────────────────────────────

  Widget _organizerList(List<Map<String, dynamic>> events) {
    final counts = <String, int>{};
    for (final e in events) {
      final orgId = (e['organizerId'] as String? ?? '');
      if (orgId.isEmpty) continue;
      counts[orgId] = (counts[orgId] ?? 0) + 1;
    }
    if (counts.isEmpty) return _chartEmpty('No organizer data.');

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = entries.first.value;

    return Column(
      children: entries.take(5).toList().asMap().entries.map((entry) {
        final orgId = entry.value.key;
        final count = entry.value.value;
        final pct   = maxVal > 0 ? count / maxVal : 0.0;
        final name  = _organizerName(orgId);
        final color = _chartPalette[entry.key % _chartPalette.length];

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(name,
                    style: const TextStyle(
                        color: _kTextDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 10,
                    backgroundColor: _kBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                child: Text('$count',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Timeline ──────────────────────────────────────────────────────────────

  Widget _timelineChart(List<Map<String, dynamic>> events) {
    final now    = DateTime.now();
    final months = List.generate(
        6, (i) => DateTime(now.year, now.month + i, 1));

    final counts = <int, int>{};
    for (final e in events) {
      final start = e['start'] as DateTime?;
      if (start == null) continue;
      for (var i = 0; i < 6; i++) {
        final m = months[i];
        if (start.year == m.year && start.month == m.month) {
          counts[i] = (counts[i] ?? 0) + 1;
          break;
        }
      }
    }

    final maxVal = counts.values
        .fold<int>(0, (m, v) => v > m ? v : m)
        .toDouble();

    final bars = List.generate(6, (i) {
      final cnt   = counts[i] ?? 0;
      final color = cnt > 0 ? _kPrimary : _kBorder;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: cnt.toDouble(),
            color: color,
            width: 20,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    });

    const monthAbbr = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: SizedBox(
        height: 140,
        child: BarChart(
          BarChartData(
            barGroups: bars,
            maxY: maxVal < 1 ? 4 : maxVal + 1,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: _kBorder, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (v, _) => Text(
                    v.toInt() == v ? '${v.toInt()}' : '',
                    style: const TextStyle(
                        color: _kTextLight, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= 6) {
                      return const SizedBox.shrink();
                    }
                    final month = months[i];
                    return Text(monthAbbr[month.month - 1],
                        style: const TextStyle(
                            color: _kTextMid, fontSize: 10));
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
          ),
        ),
      ),
    );
  }

  // ── Legend row ────────────────────────────────────────────────────────────

  Widget _legendRow(Color color, String label, {Color? border}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: border != null
                ? Border.all(color: border, width: 1)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: _kTextMid, fontSize: 12)),
      ],
    );
  }

  Widget _chartEmpty(String msg) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Center(
        child: Text(msg,
            style: const TextStyle(
                color: _kTextLight, fontSize: 13)),
      ),
    );
  }
}
