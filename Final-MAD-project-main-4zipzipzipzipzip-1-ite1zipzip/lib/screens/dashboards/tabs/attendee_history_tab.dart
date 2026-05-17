import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/registration_service.dart';
import '../../../services/firebase_database_service.dart';
import '../../../services/event_rating_service.dart';

// ── Theme ──────────────────────────────────────────────────────────────────

const _kPrimary      = Color(0xFFC46A3D);
const _kPrimaryDark  = Color(0xFFB05530);
const _kPrimaryLight = Color(0xFFFFF1E8);
const _kBg           = Color(0xFFFAF7F2);
const _kSurface      = Color(0xFFFFFFFF);
const _kTextDark     = Color(0xFF1F1A17);
const _kTextMid      = Color(0xFF6E6258);
const _kTextLight    = Color(0xFFA09489);
const _kBorder       = Color(0xFFE9E1D6);
const _kSuccess      = Color(0xFF3D7A5A);
const _kSuccessLight = Color(0xFFD1FAE5);
const _kWarning      = Color(0xFFB7791F);
const _kWarningLight = Color(0xFFFEF3C7);
const _kError        = Color(0xFFC24A3A);
const _kErrorLight   = Color(0xFFFEE2E2);
const _kLive         = Color(0xFF3D7A5A);
const _kLiveLight    = Color(0xFFD1FAE5);

const _catColors = <String, Color>{
  'Technology':     Color(0xFFC46A3D),
  'Business':       Color(0xFF3D7A5A),
  'Arts & Culture': Color(0xFF8B5E52),
  'Education':      Color(0xFFB7791F),
  'Workshop':       Color(0xFF5A8C6F),
  'Seminar':        Color(0xFF8B5E52),
  'Conference':     Color(0xFF5A6F8C),
  'Networking':     Color(0xFF6E6258),
  'Health':         Color(0xFFC24A3A),
  'Finance':        Color(0xFF3D7A5A),
};
Color _catColor(String c) => _catColors[c] ?? _kPrimary;

// ── Status helpers ─────────────────────────────────────────────────────────

enum _EventStatus { live, upcoming, attended, missed }

_EventStatus _statusOf(Map<String, dynamic> e, bool isAttended) {
  final now   = DateTime.now();
  final start = e['start'] as DateTime?;
  final end   = e['end']   as DateTime?;
  if (start == null) return _EventStatus.missed;
  if (start.isBefore(now) && (end == null || end.isAfter(now))) {
    return _EventStatus.live;
  }
  if (start.isAfter(now)) return _EventStatus.upcoming;
  if (isAttended) return _EventStatus.attended;
  return _EventStatus.missed;
}

// ── Widget ─────────────────────────────────────────────────────────────────

class AttendeeHistoryTab extends StatefulWidget {
  final Set<String> registeredIds;
  final void Function(Map<String, dynamic>) onEventTap;
  final String Function(Map<String, dynamic>) locationLabel;
  final String Function(Map<String, dynamic>) organizerName;

  const AttendeeHistoryTab({
    super.key,
    required this.registeredIds,
    required this.onEventTap,
    required this.locationLabel,
    required this.organizerName,
  });

  @override
  State<AttendeeHistoryTab> createState() => _AttendeeHistoryTabState();
}

class _AttendeeHistoryTabState extends State<AttendeeHistoryTab> {
  final _auth   = AuthService();
  final _reg    = RegistrationService();
  final _fdb    = FirebaseDatabaseService();
  final _rating = EventRatingService();

  StreamSubscription? _regSub;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _subscribeFB();
    // Tick every minute to update live countdowns
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _subscribeFB() {
    _regSub = _fdb.streamRegistrations().listen((list) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _regSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  String get _uid => _auth.currentUser?.id ?? '';

  bool _isAttended(String eventId) {
    if (_uid.isEmpty) return false;
    final regs = _reg.registrationsForAttendee(_uid);
    return regs.any(
        (r) => r['eventId'] == eventId && (r['attended'] as bool? ?? false));
  }

  // Group registered events into sections
  Map<String, List<Map<String, dynamic>>> _grouped() {
    final now    = DateTime.now();
    final events = _auth.allEvents
        .where((e) => widget.registeredIds.contains(e['id'] as String))
        .toList()
      ..sort((a, b) {
        final sa = a['start'] as DateTime?;
        final sb = b['start'] as DateTime?;
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sb.compareTo(sa); // newest first
      });

    final live      = <Map<String, dynamic>>[];
    final upcoming  = <Map<String, dynamic>>[];
    final pastYears = <String, List<Map<String, dynamic>>>{};

    for (final e in events) {
      final start  = e['start'] as DateTime?;
      final end    = e['end']   as DateTime?;
      final status = _statusOf(e, _isAttended(e['id'] as String? ?? ''));

      if (status == _EventStatus.live) {
        live.add(e);
      } else if (status == _EventStatus.upcoming) {
        upcoming.add(e);
      } else {
        final year = start != null ? '${start.year}' : 'Earlier';
        pastYears.putIfAbsent(year, () => []).add(e);
      }
    }

    final result = <String, List<Map<String, dynamic>>>{};
    if (live.isNotEmpty) result['Live Now'] = live;
    if (upcoming.isNotEmpty) {
      upcoming.sort((a, b) {
        final sa = a['start'] as DateTime?;
        final sb = b['start'] as DateTime?;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sa.compareTo(sb);
      });
      result['Upcoming'] = upcoming;
    }
    // Sort year keys descending
    final sortedYears = pastYears.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final year in sortedYears) {
      result[year] = pastYears[year]!;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (!_auth.isLoggedIn) return _notLoggedIn();
    if (widget.registeredIds.isEmpty) return _emptyState();

    final grouped = _grouped();
    final totalEvents  = widget.registeredIds.length;
    final attendedCount = widget.registeredIds.where(_isAttended).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryHeader(totalEvents, attendedCount),
          const SizedBox(height: 24),
          ...grouped.entries.map((entry) => _section(entry.key, entry.value)),
        ],
      ),
    );
  }

  // ── Summary header ─────────────────────────────────────────────────────

  Widget _summaryHeader(int total, int attended) {
    final pct = total > 0
        ? (attended / total * 100).toStringAsFixed(0)
        : '0';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_outlined, color: Colors.white, size: 12),
                    SizedBox(width: 5),
                    Text('Attendance History',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroBadge('$total', 'Registered'),
              const SizedBox(width: 14),
              _heroBadge('$attended', 'Attended'),
              const SizedBox(width: 14),
              _heroBadge('$pct%', 'Attendance Rate'),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total > 0 ? attended / total : 0,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBadge(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 10)),
        ],
      ),
    );
  }

  // ── Section ────────────────────────────────────────────────────────────

  Widget _section(String title, List<Map<String, dynamic>> events) {
    final isLive     = title == 'Live Now';
    final isUpcoming = title == 'Upcoming';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isLive) ...[
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: _kLive, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ] else if (isUpcoming) ...[
              const Icon(Icons.upcoming_outlined,
                  color: _kPrimary, size: 16),
              const SizedBox(width: 6),
            ] else ...[
              const Icon(Icons.calendar_month_outlined,
                  color: _kTextMid, size: 15),
              const SizedBox(width: 6),
            ],
            Text(
              title,
              style: TextStyle(
                color: isLive ? _kLive : isUpcoming ? _kPrimary : _kTextDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isLive
                    ? _kLiveLight
                    : isUpcoming
                        ? _kPrimaryLight
                        : _kBorder.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${events.length}',
                style: TextStyle(
                  color: isLive
                      ? _kLive
                      : isUpcoming
                          ? _kPrimary
                          : _kTextMid,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...events.map((e) => _timelineCard(e)),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Timeline card ──────────────────────────────────────────────────────

  Widget _timelineCard(Map<String, dynamic> e) {
    final eventId  = e['id'] as String? ?? '';
    final category = e['category'] as String? ?? '';
    final color    = _catColor(category);
    final start    = e['start'] as DateTime?;
    final end      = e['end']   as DateTime?;
    final location = widget.locationLabel(e);
    final attended = _isAttended(eventId);
    final status   = _statusOf(e, attended);
    final avgRating = _rating.getAverageRating(eventId);
    final ratingCount = _rating.getRatingCount(eventId);

    return GestureDetector(
      onTap: () => widget.onEventTap(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: status == _EventStatus.live
                ? _kLive
                : status == _EventStatus.upcoming
                    ? _kPrimary.withOpacity(0.3)
                    : _kBorder,
            width: status == _EventStatus.live ? 1.5 : 1,
          ),
          boxShadow: status == _EventStatus.live
              ? [
                  BoxShadow(
                    color: _kLive.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left timeline line + dot
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 14, bottom: 4),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _statusBgColor(status),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _statusColor(status).withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Text(
                        _statusIcon(status),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category.isEmpty ? 'Event' : category,
                            style: TextStyle(
                                color: color,
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Spacer(),
                        _statusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      e['title'] as String? ?? 'Untitled',
                      style: const TextStyle(
                          color: _kTextDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.2),
                    ),
                    const SizedBox(height: 6),
                    if (start != null)
                      _infoRow(Icons.calendar_today_outlined,
                          _fmtDateTime(start, end)),
                    if (location.isNotEmpty)
                      _infoRow(Icons.location_on_outlined, location),

                    // Status-specific footer
                    const SizedBox(height: 8),
                    if (status == _EventStatus.live)
                      _liveFooter(start, end)
                    else if (status == _EventStatus.upcoming && start != null)
                      _upcomingFooter(start)
                    else if (status == _EventStatus.attended && avgRating > 0)
                      _ratingRow(avgRating, ratingCount),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveFooter(DateTime? start, DateTime? end) {
    final now = DateTime.now();
    final remaining = end != null ? end.difference(now) : null;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kLiveLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(
                color: _kLive, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            remaining != null
                ? 'Ends in ${_fmtDuration(remaining)}'
                : 'Happening now!',
            style: const TextStyle(
                color: _kLive,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _upcomingFooter(DateTime start) {
    final diff = start.difference(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kPrimaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_outlined, size: 12, color: _kPrimary),
          const SizedBox(width: 5),
          Text(
            _countdownLabel(diff),
            style: const TextStyle(
                color: _kPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _ratingRow(double avg, int count) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          final full = i < avg.floor();
          final half = !full && i < avg;
          return Icon(
            full
                ? Icons.star_rounded
                : half
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: 14,
            color: _kWarning,
          );
        }),
        const SizedBox(width: 5),
        Text(
          '${avg.toStringAsFixed(1)} ($count)',
          style: const TextStyle(color: _kTextMid, fontSize: 11),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 12, color: _kTextLight),
          const SizedBox(width: 5),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: _kTextMid, fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ── Status helpers ────────────────────────────────────────────────────

  Color _statusColor(_EventStatus s) {
    switch (s) {
      case _EventStatus.live:     return _kLive;
      case _EventStatus.upcoming: return _kPrimary;
      case _EventStatus.attended: return _kSuccess;
      case _EventStatus.missed:   return _kTextLight;
    }
  }

  Color _statusBgColor(_EventStatus s) {
    switch (s) {
      case _EventStatus.live:     return _kLiveLight;
      case _EventStatus.upcoming: return _kPrimaryLight;
      case _EventStatus.attended: return _kSuccessLight;
      case _EventStatus.missed:   return const Color(0xFFF1F5F9);
    }
  }

  String _statusIcon(_EventStatus s) {
    switch (s) {
      case _EventStatus.live:     return '🔴';
      case _EventStatus.upcoming: return '📅';
      case _EventStatus.attended: return '✅';
      case _EventStatus.missed:   return '⏭️';
    }
  }

  Widget _statusBadge(_EventStatus s) {
    final (label, color, bg) = switch (s) {
      _EventStatus.live     => ('LIVE', _kLive, _kLiveLight),
      _EventStatus.upcoming => ('UPCOMING', _kPrimary, _kPrimaryLight),
      _EventStatus.attended => ('ATTENDED', _kSuccess, _kSuccessLight),
      _EventStatus.missed   => ('MISSED', _kTextLight, _kBorder.withOpacity(0.4)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }

  // ── Formatters ────────────────────────────────────────────────────────

  String _fmtDateTime(DateTime start, DateTime? end) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final date = '${start.day} ${months[start.month - 1]} ${start.year}';
    final t1   = _fmtTime(start);
    final t2   = end != null ? ' – ${_fmtTime(end)}' : '';
    return '$date  $t1$t2';
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _fmtDuration(Duration d) {
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }

  String _countdownLabel(Duration d) {
    if (d.inDays >= 30) return 'In ${(d.inDays / 30).round()} months';
    if (d.inDays >= 7) return 'In ${(d.inDays / 7).round()} weeks';
    if (d.inDays >= 1) return 'In ${d.inDays}d ${d.inHours.remainder(24)}h';
    if (d.inHours >= 1) return 'In ${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return 'Starting soon';
  }

  // ── Empty states ──────────────────────────────────────────────────────

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                  color: _kPrimaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.history_outlined,
                  size: 36, color: _kPrimary),
            ),
            const SizedBox(height: 20),
            const Text('No history yet',
                style: TextStyle(
                    color: _kTextDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Register for events to build your attendance history timeline.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kTextMid, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notLoggedIn() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                  color: _kPrimaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline,
                  size: 36, color: _kPrimary),
            ),
            const SizedBox(height: 20),
            const Text('Sign in to see your history',
                style: TextStyle(
                    color: _kTextDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
