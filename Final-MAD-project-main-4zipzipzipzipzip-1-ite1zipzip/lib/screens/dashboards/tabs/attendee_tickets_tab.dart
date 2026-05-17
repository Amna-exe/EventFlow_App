import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/registration_service.dart';
import '../../../services/event_rating_service.dart';

const _kPrimary      = Color(0xFFC46A3D);
const _kPrimaryLight = Color(0xFFFFF1E8);
const _kTextDark     = Color(0xFF1F1A17);
const _kTextMid      = Color(0xFF6E6258);
const _kTextLight    = Color(0xFFA09489);
const _kBorder       = Color(0xFFE9E1D6);
const _kSuccess      = Color(0xFF3D7A5A);
const _kSuccessLight = Color(0xFFD1FAE5);
const _kWarning      = Color(0xFFB7791F);
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

// ── Status ─────────────────────────────────────────────────────────────────

enum _TicketStatus { live, upcoming, ended }

_TicketStatus _statusOf(DateTime? start, DateTime? end) {
  final now = DateTime.now();
  if (start == null) return _TicketStatus.ended;
  if (start.isBefore(now) && (end == null || end.isAfter(now))) {
    return _TicketStatus.live;
  }
  if (start.isAfter(now)) return _TicketStatus.upcoming;
  return _TicketStatus.ended;
}

// ── Widget ─────────────────────────────────────────────────────────────────

class AttendeeTicketsTab extends StatefulWidget {
  final Set<String> registeredIds;
  final void Function(Map<String, dynamic>) onEventTap;
  final String Function(Map<String, dynamic>) locationLabel;
  final String Function(Map<String, dynamic>) organizerName;

  const AttendeeTicketsTab({
    super.key,
    required this.registeredIds,
    required this.onEventTap,
    required this.locationLabel,
    required this.organizerName,
  });

  @override
  State<AttendeeTicketsTab> createState() => _AttendeeTicketsTabState();
}

class _AttendeeTicketsTabState extends State<AttendeeTicketsTab> {
  final _auth   = AuthService();
  final _reg    = RegistrationService();
  final _rating = EventRatingService();

  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Tick every second for live countdown
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_auth.isLoggedIn) return _notLoggedIn();

    final userId   = _auth.currentUser!.id;
    final myEvents = _auth.allEvents
        .where((e) => widget.registeredIds.contains(e['id'] as String))
        .toList()
      ..sort((a, b) {
        final sa = a['start'] as DateTime?;
        final sb = b['start'] as DateTime?;
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sa.compareTo(sb);
      });

    final live = myEvents.where((e) {
      final s = e['start'] as DateTime?;
      final en = e['end'] as DateTime?;
      return _statusOf(s, en) == _TicketStatus.live;
    }).toList();

    final upcoming = myEvents.where((e) {
      final s = e['start'] as DateTime?;
      final en = e['end'] as DateTime?;
      return _statusOf(s, en) == _TicketStatus.upcoming;
    }).toList();

    final ended = myEvents.where((e) {
      final s = e['start'] as DateTime?;
      final en = e['end'] as DateTime?;
      return _statusOf(s, en) == _TicketStatus.ended;
    }).toList();

    if (myEvents.isEmpty) return _emptyState();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Row(
            children: [
              _statBadge('${myEvents.length}', 'Total',
                  Icons.confirmation_num_outlined, _kPrimary),
              const SizedBox(width: 8),
              _statBadge('${live.length}', 'Live Now',
                  Icons.fiber_manual_record, _kLive),
              const SizedBox(width: 8),
              _statBadge('${upcoming.length}', 'Upcoming',
                  Icons.upcoming_outlined, _kSuccess),
              const SizedBox(width: 8),
              _statBadge('${ended.length}', 'Past',
                  Icons.history_outlined, _kTextMid),
            ],
          ),
          const SizedBox(height: 24),

          if (live.isNotEmpty) ...[
            _sectionLabel('Live Now', live.length, color: _kLive),
            const SizedBox(height: 12),
            ...live.map((e) =>
                _ticketCard(e, userId, isLive: true)),
            const SizedBox(height: 24),
          ],

          if (upcoming.isNotEmpty) ...[
            _sectionLabel('Upcoming Events', upcoming.length),
            const SizedBox(height: 12),
            ...upcoming.map((e) =>
                _ticketCard(e, userId, isUpcoming: true)),
            const SizedBox(height: 24),
          ],

          if (ended.isNotEmpty) ...[
            _sectionLabel('Past Events', ended.length, muted: true),
            const SizedBox(height: 12),
            ...ended.map((e) => _ticketCard(e, userId)),
          ],
        ],
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────

  Widget _sectionLabel(String title, int count,
      {Color? color, bool muted = false}) {
    final c = color ?? (muted ? _kTextMid : _kTextDark);
    return Row(
      children: [
        if (color == _kLive) ...[
          Container(
            width: 8, height: 8,
            decoration:
                const BoxDecoration(color: _kLive, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Text(title,
            style: TextStyle(
                color: c, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color != null
                ? color.withOpacity(0.1)
                : _kPrimaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count',
              style: TextStyle(
                  color: color ?? _kPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _statBadge(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color == _kLive ? _kLive.withOpacity(0.3) : _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style:
                    const TextStyle(color: _kTextLight, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  // ── Ticket card ────────────────────────────────────────────────────────

  Widget _ticketCard(Map<String, dynamic> e, String userId,
      {bool isUpcoming = false, bool isLive = false}) {
    final category = (e['category'] as String? ?? '');
    final color    = _catColor(category);
    final start    = e['start'] as DateTime?;
    final end      = e['end']   as DateTime?;
    final loc      = widget.locationLabel(e);
    final org      = widget.organizerName(e);
    final eventId  = e['id'] as String? ?? '';
    final regs     = _reg.registrationsForAttendee(userId);
    final isAttended = regs.any((r) =>
        r['eventId'] == eventId && (r['attended'] as bool? ?? false));
    final avgRating   = _rating.getAverageRating(eventId);
    final userRating  = _rating.getUserRating(eventId, userId);
    final ratingCount = _rating.getRatingCount(eventId);

    final borderColor = isLive
        ? _kLive
        : isUpcoming
            ? color.withOpacity(0.3)
            : _kBorder;

    return GestureDetector(
      onTap: () => widget.onEventTap(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: isLive ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: (isLive ? _kLive : color).withOpacity(0.1),
              blurRadius: isLive ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header gradient strip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isLive
                      ? [_kLive, _kLive.withOpacity(0.75)]
                      : [color, color.withOpacity(0.7)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(17)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category.isEmpty ? 'Event' : category,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  if (isLive)
                    _liveBadge()
                  else if (isAttended)
                    _statusChip('✓ Attended', _kSuccessLight, _kSuccess)
                  else if (isUpcoming)
                    _statusChip('Confirmed', Colors.white.withOpacity(0.2),
                        Colors.white),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e['title'] as String? ?? 'Untitled Event',
                          style: const TextStyle(
                              color: _kTextDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              height: 1.2),
                        ),
                        const SizedBox(height: 8),
                        if (start != null) ...[
                          _infoRow(Icons.calendar_today_outlined,
                              _fmtDate(start)),
                          const SizedBox(height: 3),
                          _infoRow(Icons.access_time_outlined,
                              '${_fmtTime(start)}${end != null ? ' – ${_fmtTime(end)}' : ''}'),
                        ],
                        if (loc.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          _infoRow(Icons.location_on_outlined, loc),
                        ],
                        if (org.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          _infoRow(Icons.person_outline, 'By $org'),
                        ],

                        // Ratings row for past events
                        if (!isLive && !isUpcoming) ...[
                          const SizedBox(height: 8),
                          if (avgRating > 0)
                            _ratingDisplay(avgRating, ratingCount, userRating),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // QR code placeholder
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: (isLive ? _kLive : color).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              (isLive ? _kLive : color).withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2_rounded,
                            color: isLive ? _kLive : color, size: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Dashed divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _dashedDivider(),
            ),

            // Ticket footer
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.confirmation_num_outlined,
                      size: 13, color: _kTextLight),
                  const SizedBox(width: 4),
                  Text(
                    'Ticket #${eventId.length >= 8 ? eventId.substring(0, 8).toUpperCase() : eventId.toUpperCase()}',
                    style: const TextStyle(
                        color: _kTextLight,
                        fontSize: 10,
                        fontFamily: 'monospace'),
                  ),
                  const Spacer(),
                  // Live countdown or days until
                  if (isLive && end != null)
                    _liveCountdown(end)
                  else if (isLive)
                    _liveNowPill()
                  else if (isUpcoming && start != null)
                    _countdownChip(start, color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Live components ────────────────────────────────────────────────────

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
                color: _kLive, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          const Text('LIVE NOW',
              style: TextStyle(
                  color: _kLive,
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _liveNowPill() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kLiveLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: const BoxDecoration(
                color: _kLive, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          const Text('Happening now',
              style: TextStyle(
                  color: _kLive,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _liveCountdown(DateTime end) {
    final diff = end.difference(_now);
    if (diff.isNegative) return _liveNowPill();
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kLiveLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: const BoxDecoration(
                color: _kLive, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text('Ends $h:$m:$s',
              style: const TextStyle(
                  color: _kLive,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _countdownChip(DateTime start, Color color) {
    final diff = start.difference(_now);
    String label;
    if (diff.inSeconds <= 0) {
      label = 'Starting soon';
    } else if (diff.inDays == 0) {
      final h = diff.inHours.toString().padLeft(2, '0');
      final m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
      label = '$h:$m:$s';
    } else if (diff.inDays == 1) {
      label = 'Tomorrow';
    } else if (diff.inDays < 7) {
      label = 'In ${diff.inDays}d';
    } else if (diff.inDays < 30) {
      label = 'In ${(diff.inDays / 7).round()}w';
    } else {
      label = 'In ${(diff.inDays / 30).round()}mo';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_outlined, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: diff.inDays == 0 ? 'monospace' : null)),
        ],
      ),
    );
  }

  // ── Rating display ────────────────────────────────────────────────────

  Widget _ratingDisplay(double avg, int count, double? userRating) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          final isFull = i < avg.floor();
          final isHalf = !isFull && i < avg;
          return Icon(
            isFull
                ? Icons.star_rounded
                : isHalf
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: 13,
            color: _kWarning,
          );
        }),
        const SizedBox(width: 4),
        Text('${avg.toStringAsFixed(1)} ($count)',
            style: const TextStyle(color: _kTextMid, fontSize: 11)),
        if (userRating != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _kPrimaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('You: ${userRating.toInt()}★',
                style: const TextStyle(
                    color: _kPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Widget _statusChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: _kTextLight),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: _kTextMid, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _dashedDivider() {
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final count = (constraints.maxWidth / 8).floor();
          return Row(
            children: List.generate(
              count,
              (i) => Expanded(
                child: Container(
                  height: 1,
                  color: i.isEven ? _kBorder : Colors.transparent,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    const w = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${w[dt.weekday - 1]}, ${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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
              child: const Icon(Icons.confirmation_num_outlined,
                  size: 36, color: _kPrimary),
            ),
            const SizedBox(height: 20),
            const Text('No tickets yet',
                style: TextStyle(
                    color: _kTextDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Register for events to see your digital tickets here.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: _kTextMid, fontSize: 13, height: 1.5),
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
            const Text('Sign in to view tickets',
                style: TextStyle(
                    color: _kTextDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Log in to access your registered event tickets.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: _kTextMid, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
