import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/analytics_model.dart';
import '../../../services/analytics_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/registration_service.dart';
import '../../../services/payment_service.dart';
import '../../../widgets/analytics/analytics_widgets.dart';
import '../../../utils/analytics_utils.dart';

// ── Seat state enum ─────────────────────────────────────────────────────────

enum _SeatState { available, booked, reserved, blocked }

// ── Tab root ────────────────────────────────────────────────────────────────

class OrganizerAnalyticsTab extends StatefulWidget {
  final String organizerId;
  final VoidCallback? onCreateEvent;
  final VoidCallback? onViewVenues;
  final VoidCallback? onViewAttendees;

  const OrganizerAnalyticsTab({
    super.key,
    required this.organizerId,
    this.onCreateEvent,
    this.onViewVenues,
    this.onViewAttendees,
  });

  @override
  State<OrganizerAnalyticsTab> createState() =>
      _OrganizerAnalyticsTabState();
}

class _OrganizerAnalyticsTabState extends State<OrganizerAnalyticsTab> {
  late OrganizerAnalyticsSnapshot _snap;
  final _auth = AuthService();
  final _reg = RegistrationService();
  final _ps = PaymentService();

  String? _selectedSeatMapEventId;

  static const _white = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE9E1D6);
  static const _ink = Color(0xFF1F1A17);
  static const _muted = Color(0xFF6E6258);
  static const _accent = Color(0xFFC46A3D);

  @override
  void initState() {
    super.initState();
    AnalyticsService.invalidateAll();
    _snap = AnalyticsService.computeForOrganizer(widget.organizerId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  bool _isRefreshing = false;

  void _reload() {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    Future.delayed(const Duration(milliseconds: 200), () {
      AnalyticsService.invalidateAll();
      if (mounted) {
        setState(() {
          _snap = AnalyticsService.computeForOrganizer(widget.organizerId);
          _isRefreshing = false;
        });
      }
    });
  }

  // ── Derived metrics ───────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _myEvents => _auth.allEvents
      .where((e) => e['organizerId'] == widget.organizerId)
      .toList();

  int get _upcomingCount {
    final now = DateTime.now();
    return _myEvents
        .where((e) =>
            e['status'] == 'published' &&
            (e['start'] as DateTime?)?.isAfter(now) == true)
        .length;
  }

  int get _ticketsSold => _snap.totalRegistrations;

  double get _revenueEstimate => _snap.revenueEstimate;

  double get _occupancyRate => _snap.overallFillRate;

  int get _activeVenuesCount {
    final now = DateTime.now();
    return _myEvents
        .where((e) =>
            e['bookingId'] != null &&
            (e['end'] as DateTime?)?.isAfter(now) == true)
        .map((e) => e['bookingId'] as String)
        .toSet()
        .length;
  }

  int get _staffAssigned => _myEvents.fold<int>(0, (sum, e) {
        final s = e['speakers'];
        return sum + (s is List ? s.length : 0);
      });

  int get _sponsorsCount => _myEvents.fold<int>(0, (sum, e) {
        final s = e['sponsors'];
        return sum + (s is List ? s.length : 0);
      });

  // ── Events with venue for seat map ────────────────────────────────────────

  List<Map<String, dynamic>> get _eventsWithVenue {
    return _myEvents.where((e) {
      final roomId = e['venueRoomId'] as String?;
      if (roomId == null) return false;
      return _auth.allRooms.any((r) => r['id'] == roomId);
    }).toList()
      ..sort((a, b) {
        final aS = a['start'] as DateTime?;
        final bS = b['start'] as DateTime?;
        if (aS == null) return 1;
        if (bS == null) return -1;
        return bS.compareTo(aS);
      });
  }

  Map<String, dynamic>? _venueRoomFor(String eventId) {
    final ev = _myEvents.firstWhere(
      (e) => e['id'] == eventId,
      orElse: () => <String, dynamic>{},
    );
    final roomId = ev['venueRoomId'] as String?;
    if (roomId == null) return null;
    return _auth.allRooms.firstWhere(
      (r) => r['id'] == roomId,
      orElse: () => <String, dynamic>{},
    );
  }

  // ── Recent activity ────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _buildActivity() {
    final activities = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (final e in _myEvents) {
      final created = e['createdAt'] as DateTime?;
      if (created != null && now.difference(created).inDays < 30) {
        activities.add({
          'icon': Icons.event_note_outlined,
          'color': const Color(0xFF1565C0),
          'text': 'Event "${e['title']}" created',
          'dt': created,
        });
      }
    }

    for (final b in _auth.allBookings) {
      final eventId = b['eventId'] as String?;
      if (eventId == null) continue;
      final ev = _myEvents.firstWhere(
        (e) => e['id'] == eventId,
        orElse: () => <String, dynamic>{},
      );
      if (ev.isEmpty) continue;

      final created = b['createdAt'] as DateTime?;
      final status = b['status'] as String? ?? '';

      if (created != null && now.difference(created).inDays < 30) {
        activities.add({
          'icon': Icons.meeting_room_outlined,
          'color': const Color(0xFF2E7D32),
          'text': 'Venue booked for "${ev['title']}"',
          'dt': created,
        });
      }

      if (status == 'cancelled' && created != null) {
        activities.add({
          'icon': Icons.cancel_outlined,
          'color': const Color(0xFFDC2626),
          'text': 'Booking cancelled for "${ev['title']}"',
          'dt': created,
        });
      }

      final bId = b['id'] as String?;
      if (bId != null) {
        final payment = _ps.get(bId);
        if (payment != null && payment.status.toString().contains('refund')) {
          activities.add({
            'icon': Icons.currency_exchange_outlined,
            'color': const Color(0xFFD97706),
            'text': 'Refund processed for "${ev['title']}"',
            'dt': created ?? now,
          });
        }
      }
    }

    activities.sort((a, b) =>
        (b['dt'] as DateTime).compareTo(a['dt'] as DateTime));
    return activities.take(10).toList();
  }

  // ── AI insight generation ──────────────────────────────────────────────────

  List<Map<String, dynamic>> _buildInsights() {
    final insights = <Map<String, dynamic>>[];

    // Busiest booking times
    final peakHours = _snap.peakRegistrationHours;
    if (peakHours.isNotEmpty) {
      final peak = peakHours.reduce((a, b) => a.count >= b.count ? a : b);
      if (peak.count > 0) {
        final h = peak.hour;
        final label = h < 12 ? '${h}AM' : h == 12 ? '12PM' : '${h - 12}PM';
        insights.add({
          'icon': Icons.access_time_outlined,
          'title': 'Busiest Registration Time',
          'body':
              'Most registrations happen around $label. Consider sending reminders or promotions during this window.',
          'color': const Color(0xFF1565C0),
          'bg': const Color(0xFFEFF6FF),
        });
      }
    }

    // Likely sold-out events
    final nearFull = _snap.eventPerformances
        .where((e) => e.fillRate >= 0.8 && e.status == 'upcoming')
        .toList();
    if (nearFull.isNotEmpty) {
      insights.add({
        'icon': Icons.local_fire_department_outlined,
        'title': 'Events Likely to Sell Out',
        'body':
            '${nearFull.length} upcoming event${nearFull.length > 1 ? 's are' : ' is'} over 80% full. '
            'Promote "${nearFull.first.title}" now before tickets run out.',
        'color': const Color(0xFFE65100),
        'bg': const Color(0xFFFFF3E0),
      });
    }

    // Predicted no-show
    final noShowRate = _snap.overallNoShowRate;
    if (noShowRate > 10) {
      insights.add({
        'icon': Icons.person_off_outlined,
        'title': 'Predicted No-Show Rate',
        'body':
            'Historical no-show rate is ${noShowRate.toStringAsFixed(0)}%. '
            'Send reminder emails 24h before events to reduce no-shows.',
        'color': const Color(0xFF6D4C41),
        'bg': const Color(0xFFFBF7F4),
      });
    }

    // Best performing venue
    if (_snap.venueEfficiency.isNotEmpty) {
      final best = _snap.venueEfficiency.first;
      insights.add({
        'icon': Icons.star_outline_rounded,
        'title': 'Best Performing Venue',
        'body':
            '"${best.buildingName}" leads with ${best.bookingCount} booking${best.bookingCount > 1 ? 's' : ''}.'
            '${best.totalRevenuePaid > 0 ? ' Revenue: ${AnalyticsFormatters.currency(best.totalRevenuePaid)}.' : ''} '
            'Book early for future events.',
        'color': const Color(0xFF2E7D32),
        'bg': const Color(0xFFF0FAF4),
      });
    }

    // Registration velocity
    final velocity = _snap.registrationVelocity;
    if (velocity.length >= 2) {
      final recent = velocity.reversed.take(7).fold(0.0, (s, p) => s + p.value);
      final prior = velocity.reversed.skip(7).take(7).fold(0.0, (s, p) => s + p.value);
      if (prior > 0 && recent > prior * 1.2) {
        insights.add({
          'icon': Icons.trending_up_outlined,
          'title': 'Registration Spike Detected',
          'body':
              'Registrations are up ${((recent / prior - 1) * 100).toStringAsFixed(0)}% '
              'over the past week vs the week before. Momentum is growing!',
          'color': const Color(0xFF6A1B9A),
          'bg': const Color(0xFFF5F0FF),
        });
      }
    }

    // Category with highest fill rate
    final cats = _snap.categoryBreakdown;
    if (cats.isNotEmpty) {
      final top = cats.reduce((a, b) => a.avgFillRate >= b.avgFillRate ? a : b);
      if (top.avgFillRate > 50) {
        insights.add({
          'icon': Icons.category_outlined,
          'title': 'Top Category: ${top.category}',
          'body':
              '${top.category} events fill ${top.avgFillRate.toStringAsFixed(0)}% of capacity on average. '
              'Consider hosting more ${top.category} events.',
          'color': _accent,
          'bg': const Color(0xFFFDF5F0),
        });
      }
    }

    if (insights.isEmpty) {
      insights.add({
        'icon': Icons.lightbulb_outline,
        'title': 'Keep Publishing Events',
        'body':
            'Create and publish more events to unlock personalised AI-powered insights and recommendations.',
        'color': _accent,
        'bg': const Color(0xFFFDF5F0),
      });
    }

    return insights.take(4).toList();
  }

  // ── Revenue time series (from monthly registrations as proxy) ─────────────

  List<TimeSeriesPoint> get _revenueTrend {
    return _snap.monthlyRegistrations.map((p) {
      return TimeSeriesPoint(
          p.date, p.value * (_revenueEstimate / math.max(_snap.totalRegistrations, 1)));
    }).toList();
  }

  // ── Attendance trend (from monthly registrations with ~75% attendance rate) ─

  List<TimeSeriesPoint> get _attendanceTrend {
    final rate = _snap.totalRegistrations > 0
        ? _snap.totalAttended / _snap.totalRegistrations
        : 0.75;
    return _snap.monthlyRegistrations.map((p) {
      return TimeSeriesPoint(p.date, (p.value * rate));
    }).toList();
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _accent,
      onRefresh: () async => _reload(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isRefreshing)
              const LinearProgressIndicator(
                color: _accent,
                minHeight: 2.5,
                backgroundColor: Color(0xFFF0EDE8),
              ),
            _header(),
            const SizedBox(height: 16),

            // Quick Actions
            _quickActionsRow(),
            const SizedBox(height: 20),

            // Overview KPI grid
            const AnalyticsSectionLabel('Overview'),
            const SizedBox(height: 4),
            const Text(
              'Key metrics for your events and venues',
              style: TextStyle(color: Color(0xFFA09489), fontSize: 12),
            ),
            const SizedBox(height: 12),
            _overviewKpiGrid(),
            const SizedBox(height: 24),

            if (_snap.totalEvents == 0) ...[
              _emptyState(),
            ] else ...[
              // AI Insights
              const AnalyticsSectionLabel('AI Insights'),
              const SizedBox(height: 4),
              const Text(
                'Smart recommendations based on your data',
                style: TextStyle(color: Color(0xFFA09489), fontSize: 12),
              ),
              const SizedBox(height: 12),
              _aiInsightsPanel(),
              const SizedBox(height: 24),

              // Venue Occupancy
              const AnalyticsSectionLabel('Venue Occupancy'),
              const SizedBox(height: 4),
              const Text(
                'Seat map for a selected event venue',
                style: TextStyle(color: Color(0xFFA09489), fontSize: 12),
              ),
              const SizedBox(height: 12),
              _venueOccupancySection(),
              const SizedBox(height: 24),

              // Ticket Sales Trend
              const AnalyticsSectionLabel('Ticket Sales Trend'),
              const SizedBox(height: 4),
              const Text(
                'Monthly registrations — last 6 months',
                style: TextStyle(color: Color(0xFFA09489), fontSize: 12),
              ),
              const SizedBox(height: 12),
              _ticketSalesTrendChart(),
              const SizedBox(height: 24),

              // Revenue Trend
              const AnalyticsSectionLabel('Revenue Trend'),
              const SizedBox(height: 4),
              const Text(
                'Estimated monthly revenue from bookings',
                style: TextStyle(color: Color(0xFFA09489), fontSize: 12),
              ),
              const SizedBox(height: 12),
              _revenueTrendChart(),
              const SizedBox(height: 24),

              // Attendance Trend
              const AnalyticsSectionLabel('Attendance Trend'),
              const SizedBox(height: 4),
              const Text(
                'Estimated monthly attendance',
                style: TextStyle(color: Color(0xFFA09489), fontSize: 12),
              ),
              const SizedBox(height: 12),
              _attendanceTrendChart(),
              const SizedBox(height: 24),

              // Popular Ticket Types / Category Breakdown
              if (_myEvents.isNotEmpty) ...[
                const AnalyticsSectionLabel('Ticket Type Distribution'),
                const SizedBox(height: 4),
                const Text(
                  'VIP · Standard · Early Bird · Student breakdown',
                  style: TextStyle(color: Color(0xFFA09489), fontSize: 12),
                ),
                const SizedBox(height: 12),
                _popularTicketTypesChart(),
                const SizedBox(height: 24),
              ],

              // Venue Utilisation
              if (_snap.venueEfficiency.isNotEmpty) ...[
                const AnalyticsSectionLabel('Venue Utilisation'),
                const SizedBox(height: 4),
                const Text(
                  'Booking count and revenue by venue',
                  style: TextStyle(color: Color(0xFFA09489), fontSize: 12),
                ),
                const SizedBox(height: 12),
                _venueUtilisationChart(),
                const SizedBox(height: 24),
              ],

              // Recent Activity Feed
              const AnalyticsSectionLabel('Recent Activity'),
              const SizedBox(height: 4),
              const Text(
                'Bookings, refunds, event edits and venue changes',
                style: TextStyle(color: Color(0xFFA09489), fontSize: 12),
              ),
              const SizedBox(height: 12),
              _recentActivityFeed(),
              const SizedBox(height: 24),

              // Registration Funnel
              const AnalyticsSectionLabel('Registration Funnel'),
              const SizedBox(height: 12),
              _funnelSection(),
              const SizedBox(height: 24),

              if (_snap.peakRegistrationHours.isNotEmpty) ...[
                const AnalyticsSectionLabel('Peak Registration Hours'),
                const SizedBox(height: 4),
                const Text(
                  'When attendees sign up most',
                  style: TextStyle(color: Color(0xFFA09489), fontSize: 12),
                ),
                const SizedBox(height: 12),
                _peakHoursChart(),
                const SizedBox(height: 24),
              ],

              // Event Rankings
              const AnalyticsSectionLabel('Event Rankings'),
              const SizedBox(height: 4),
              const Text(
                'Sorted by total registrations',
                style: TextStyle(color: Color(0xFFA09489), fontSize: 12),
              ),
              const SizedBox(height: 12),
              _eventRankings(),

              if (_snap.categoryBreakdown.isNotEmpty) ...[
                const SizedBox(height: 24),
                const AnalyticsSectionLabel('Category Performance'),
                const SizedBox(height: 12),
                _categoryPerformance(),
              ],

              const SizedBox(height: 24),
              const AnalyticsSectionLabel('Attendee Insights'),
              const SizedBox(height: 12),
              _attendeeInsights(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analytics',
          style: TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Event performance, venue occupancy, revenue trends and AI-powered insights.',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────

  Widget _quickActionsRow() {
    final actions = [
      (Icons.add_circle_outline, 'Create Event', widget.onCreateEvent),
      (Icons.people_outline, 'Manage Tickets', widget.onViewAttendees),
      (Icons.meeting_room_outlined, 'View Venues', widget.onViewVenues),
      (Icons.bar_chart_outlined, 'Refresh Data', () => _reload()),
    ];

    return Row(
      children: actions.map((a) {
        final (icon, label, callback) = a;
        final isFirst = a == actions.first;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: isFirst ? 0 : 4,
              right: a == actions.last ? 0 : 4,
            ),
            child: _QuickActionCard(
              icon: icon,
              label: label,
              accent: isFirst ? _accent : _ink,
              onTap: callback ?? () {},
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── 8-metric KPI overview grid ────────────────────────────────────────────

  Widget _overviewKpiGrid() {
    final items = [
      (Icons.event_outlined, 'Total Events', '${_snap.totalEvents}',
          '${_snap.publishedEvents} pub · ${_snap.draftEvents} draft', null),
      (Icons.upcoming_outlined, 'Upcoming Events', '$_upcomingCount',
          'Scheduled & published', const Color(0xFF1565C0)),
      (Icons.apartment_outlined, 'Active Venues', '$_activeVenuesCount',
          'Venues with active bookings', const Color(0xFF5E35B1)),
      (Icons.confirmation_num_outlined, 'Tickets Sold', '$_ticketsSold',
          '${_snap.uniqueAttendees} unique attendees', const Color(0xFF2E7D32)),
      (Icons.attach_money_outlined, 'Revenue',
          _revenueEstimate > 0 ? AnalyticsFormatters.currency(_revenueEstimate) : '—',
          'From confirmed bookings', const Color(0xFF2E7D32)),
      (Icons.pie_chart_outline, 'Occupancy Rate',
          '${_occupancyRate.toStringAsFixed(0)}%',
          'Registered vs expected', AnalyticsColors.rateColor(_occupancyRate)),
      (Icons.mic_none_outlined, 'Staff Assigned', '$_staffAssigned',
          'Speakers across all events', const Color(0xFF6D4C41)),
      (Icons.handshake_outlined, 'Sponsors', '$_sponsorsCount',
          'Total sponsor listings', _accent),
    ];

    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      rows.add(Row(
        children: [
          Expanded(
            child: AnalyticsKpiCard(
              icon: items[i].$1,
              label: items[i].$2,
              value: items[i].$3,
              sub: items[i].$4,
              accent: items[i].$5,
            ),
          ),
          const SizedBox(width: 10),
          if (i + 1 < items.length)
            Expanded(
              child: AnalyticsKpiCard(
                icon: items[i + 1].$1,
                label: items[i + 1].$2,
                value: items[i + 1].$3,
                sub: items[i + 1].$4,
                accent: items[i + 1].$5,
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ));
    }

    return Column(children: rows);
  }

  // ── AI Insights Panel ─────────────────────────────────────────────────────

  Widget _aiInsightsPanel() {
    final insights = _buildInsights();
    return Column(
      children: insights.map((ins) => _InsightCard(insight: ins)).toList(),
    );
  }

  // ── Venue Occupancy Seat Map ───────────────────────────────────────────────

  Widget _venueOccupancySection() {
    final events = _eventsWithVenue;

    if (events.isEmpty) {
      return AnalyticsChartCard(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: AnalyticsEmptyState(
            message: 'No events with assigned venues yet.\nBook a venue for your events to see the seat map.',
          ),
        ),
      );
    }

    final Map<String, dynamic> selectedEvent = _selectedSeatMapEventId != null
        ? events.firstWhere(
            (e) => e['id'] == _selectedSeatMapEventId,
            orElse: () => events.first,
          )
        : events.first;
    final selectedId = selectedEvent['id'] as String;
    final room = _venueRoomFor(selectedId);
    final capacity = (room?['capacity'] as int?) ?? 100;
    final booked = _reg.countForEvent(selectedId);
    final reserved = (capacity * 0.05).round().clamp(0, capacity - booked);
    final blocked = (capacity * 0.03).round().clamp(0, capacity - booked - reserved);
    final available = (capacity - booked - reserved - blocked).clamp(0, capacity);
    final occupancyPct = capacity > 0 ? (booked / capacity * 100).clamp(0.0, 100.0) : 0.0;

    final roomName = (room?['name'] as String?) ?? 'Venue';
    final buildingId = room?['buildingId'] as String?;
    final building = buildingId != null
        ? _auth.allBuildings.firstWhere(
            (b) => b['id'] == buildingId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final buildingName = (building['name'] as String?) ?? '';

    return AnalyticsChartCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F3EE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedId,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: _muted, size: 18),
                style: const TextStyle(color: _ink, fontSize: 13),
                dropdownColor: _white,
                items: events.map((e) {
                  final title = e['title'] as String? ?? '';
                  final start = e['start'] as DateTime?;
                  final label = start != null
                      ? '$title  ·  ${start.day}/${start.month}/${start.year}'
                      : title;
                  return DropdownMenuItem<String>(
                    value: e['id'] as String,
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _ink, fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (v) =>
                    setState(() => _selectedSeatMapEventId = v),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Venue label
          if (roomName.isNotEmpty)
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 13, color: _muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  buildingName.isNotEmpty
                      ? '$buildingName · $roomName'
                      : roomName,
                  style: const TextStyle(color: _muted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _seatStat('$booked', 'Booked', const Color(0xFFDC2626)),
              _seatStat('$available', 'Available', const Color(0xFF2E7D32)),
              _seatStat('$reserved', 'Reserved', const Color(0xFFD97706)),
              _seatStat('$blocked', 'Blocked', const Color(0xFF9E9E9E)),
              _seatStat('$capacity', 'Total', _ink),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: occupancyPct / 100,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                occupancyPct >= 80
                    ? const Color(0xFFDC2626)
                    : occupancyPct >= 50
                        ? const Color(0xFFD97706)
                        : const Color(0xFF2E7D32),
              ),
              minHeight: 6,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${occupancyPct.toStringAsFixed(0)}% occupancy',
              style: const TextStyle(
                  color: _muted, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 14),

          // Seat map
          _SeatMapGrid(
            capacity: capacity,
            bookedCount: booked,
            reservedCount: reserved,
            blockedCount: blocked,
          ),
          const SizedBox(height: 12),

          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _legend('Booked', const Color(0xFFDC2626)),
              _legend('Available', const Color(0xFF2E7D32)),
              _legend('Reserved', const Color(0xFFD97706)),
              _legend('Blocked', const Color(0xFFBDBDBD)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seatStat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w800)),
          Text(label,
              style:
                  const TextStyle(color: _muted, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: _muted, fontSize: 11)),
      ],
    );
  }

  // ── Ticket Sales Trend Chart ───────────────────────────────────────────────

  Widget _ticketSalesTrendChart() {
    final points = _snap.monthlyRegistrations;
    if (points.isEmpty) {
      return const AnalyticsEmptyState(message: 'No ticket sales data yet');
    }

    double maxY = points.fold(0.0, (m, p) => p.value > m ? p.value : m);
    if (maxY == 0) maxY = 1;

    return AnalyticsChartCard(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: 140,
        child: LineChart(
          LineChartData(
            maxY: maxY * 1.4,
            minY: 0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: Color(0xFFE9E1D6), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}',
                    style: const TextStyle(
                        fontSize: 9, color: Color(0xFFA09489)),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 18,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _monthNames[points[idx].date.month - 1],
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFFA09489)),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: points.asMap().entries
                    .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                    .toList(),
                isCurved: true,
                color: _accent,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                    radius: 3.5,
                    color: _accent,
                    strokeWidth: 1.5,
                    strokeColor: _white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: _accent.withOpacity(0.08),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => _ink,
                getTooltipItems: (spots) => spots.map((s) {
                  final p = points[s.x.toInt()];
                  return LineTooltipItem(
                    '${s.y.toInt()} tickets\n${_monthNames[p.date.month - 1]}',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Revenue Trend Chart ───────────────────────────────────────────────────

  Widget _revenueTrendChart() {
    if (_revenueEstimate <= 0) {
      return const AnalyticsEmptyState(
          message: 'No revenue data yet.\nConfirm venue bookings to see revenue trends.');
    }
    final points = _revenueTrend;
    if (points.isEmpty) return const AnalyticsEmptyState(message: 'No revenue data');

    double maxY = points.fold(0.0, (m, p) => p.value > m ? p.value : m);
    if (maxY == 0) maxY = 1;

    return AnalyticsChartCard(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: 140,
        child: BarChart(
          BarChartData(
            maxY: maxY * 1.4,
            barGroups: points.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.value,
                    color: e.value.value > 0
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFEEEEEE),
                    width: 22,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }).toList(),
            alignment: BarChartAlignment.spaceAround,
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
                  getTitlesWidget: (v, _) => Text(
                    v >= 1000 ? '£${(v / 1000).toStringAsFixed(0)}k' : '£${v.toInt()}',
                    style: const TextStyle(
                        fontSize: 8, color: Color(0xFFA09489)),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 18,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _monthNames[points[idx].date.month - 1],
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFFA09489)),
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: Color(0xFFE9E1D6), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => _ink,
                getTooltipItem: (group, _, rod, __) {
                  final p = points[group.x];
                  return BarTooltipItem(
                    '${AnalyticsFormatters.currency(rod.toY)}\n${_monthNames[p.date.month - 1]}',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Attendance Trend Chart ────────────────────────────────────────────────

  Widget _attendanceTrendChart() {
    final points = _attendanceTrend;
    if (points.isEmpty || points.every((p) => p.value == 0)) {
      return const AnalyticsEmptyState(message: 'No attendance data yet');
    }

    double maxY = points.fold(0.0, (m, p) => p.value > m ? p.value : m);
    if (maxY == 0) maxY = 1;

    return AnalyticsChartCard(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: 140,
        child: LineChart(
          LineChartData(
            maxY: maxY * 1.4,
            minY: 0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: Color(0xFFE9E1D6), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}',
                    style: const TextStyle(
                        fontSize: 9, color: Color(0xFFA09489)),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 18,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _monthNames[points[idx].date.month - 1],
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFFA09489)),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: points.asMap().entries
                    .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                    .toList(),
                isCurved: true,
                color: const Color(0xFF2E7D32),
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                    radius: 3.5,
                    color: const Color(0xFF2E7D32),
                    strokeWidth: 1.5,
                    strokeColor: _white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF2E7D32).withOpacity(0.07),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => _ink,
                getTooltipItems: (spots) => spots.map((s) {
                  final p = points[s.x.toInt()];
                  return LineTooltipItem(
                    '${s.y.toInt()} attended\n${_monthNames[p.date.month - 1]}',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Popular Ticket Types (Category Breakdown horizontal bar) ──────────────

  Widget _popularTicketTypesChart() {
    // Derive ticket-tier distribution from real registration + event data.
    // VIP  = small-capacity exclusive events (cap ≤ 60)
    // Student = education/academic category events
    // Early Bird = estimated 20 % of any event's registrations (signed up early)
    // Standard  = remainder
    int vip = 0, standard = 0, student = 0, earlyBird = 0;

    for (final ev in _myEvents) {
      final id = ev['id'] as String? ?? '';
      final category = (ev['category'] as String? ?? '').toLowerCase();
      final cap = ev['expectedAttendees'] as int? ?? 100;
      final count = _reg.countForEvent(id);
      if (count == 0) continue;

      final eb = (count * 0.20).round().clamp(0, count);
      final rem = count - eb;
      earlyBird += eb;

      if (category.contains('student') ||
          category.contains('education') ||
          category.contains('academic') ||
          category.contains('school') ||
          category.contains('university')) {
        student += rem;
      } else if (cap <= 60) {
        vip += rem; // small-capacity = exclusive/VIP
      } else {
        standard += rem;
      }
    }

    final total = vip + standard + student + earlyBird;
    if (total == 0) {
      return const AnalyticsEmptyState(
          message: 'No ticket sales data yet.\nCreate and publish events to see ticket distribution.');
    }

    // Use positional record access ($1,$2,$3) — safe for SDK ≥3.2.3
    final types = <(String, int, Color)>[
      ('VIP', vip, _accent),
      ('Standard', standard, const Color(0xFF1565C0)),
      ('Early Bird', earlyBird, const Color(0xFF2E7D32)),
      ('Student', student, const Color(0xFF6A1B9A)),
    ];

    return AnalyticsChartCard(
      child: Column(
        children: types.map((t) {
          final label = t.$1;
          final cnt = t.$2;
          final color = t.$3;
          if (cnt == 0) return const SizedBox.shrink();
          final fraction = (cnt / total).clamp(0.0, 1.0);
          final pct = (fraction * 100).toStringAsFixed(0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 6),
                      Text(label,
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                    Text('$cnt tickets · $pct%',
                        style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fraction,
                    backgroundColor: const Color(0xFFF0F0F0),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 7,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label == 'Early Bird'
                      ? 'Estimated early registrations (>7 days before event)'
                      : label == 'VIP'
                          ? 'Exclusive events (capacity ≤ 60)'
                          : label == 'Student'
                              ? 'Education / academic events'
                              : 'Standard capacity events',
                  style: const TextStyle(
                      color: Color(0xFFA09489), fontSize: 10),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Venue Utilisation Chart ───────────────────────────────────────────────

  Widget _venueUtilisationChart() {
    final venues = _snap.venueEfficiency;
    final maxBookings = venues.isEmpty
        ? 1
        : venues.fold(0, (m, v) => v.bookingCount > m ? v.bookingCount : m);

    return AnalyticsChartCard(
      child: Column(
        children: venues.asMap().entries.map((entry) {
          final v = entry.value;
          final fraction =
              (v.bookingCount / maxBookings).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9E1D6),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(Icons.apartment_outlined,
                                size: 14, color: Color(0xFF555555)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              v.buildingName,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${v.bookingCount} booking${v.bookingCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                        if (v.totalRevenuePaid > 0)
                          Text(
                            AnalyticsFormatters.currency(v.totalRevenuePaid),
                            style: const TextStyle(
                                color: Color(0xFFA09489), fontSize: 10),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fraction,
                    backgroundColor: const Color(0xFFF0F0F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        fraction >= 0.8 ? const Color(0xFFDC2626) : _accent),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Recent Activity Feed ──────────────────────────────────────────────────

  Widget _recentActivityFeed() {
    final activities = _buildActivity();
    if (activities.isEmpty) {
      return const AnalyticsEmptyState(
          message: 'No recent activity in the last 30 days');
    }

    return AnalyticsChartCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: activities.map((item) {
          final dt = item['dt'] as DateTime;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    size: 15,
                    color: item['color'] as Color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['text'] as String,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeAgo(dt),
                        style: const TextStyle(
                            color: Color(0xFFA09489), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Funnel ────────────────────────────────────────────────────────────────

  Widget _funnelSection() {
    final totalExpected =
        _snap.eventPerformances.fold<int>(0, (s, e) => s + e.expected);
    final registered = _snap.totalRegistrations;
    final attended = _snap.totalAttended;
    final maxVal = totalExpected > 0 ? totalExpected.toDouble() : 1.0;

    return AnalyticsChartCard(
      child: Column(
        children: [
          AnalyticsFunnelRow(
            label: 'Expected',
            count: totalExpected,
            fraction: 1.0,
            color: const Color(0xFFDDDDDD),
          ),
          const SizedBox(height: 10),
          AnalyticsFunnelRow(
            label: 'Registered',
            count: registered,
            fraction: maxVal > 0 ? (registered / maxVal).clamp(0.0, 1.0) : 0,
            color: const Color(0xFF5A6F8C),
            showRate: '${_snap.overallFillRate.toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 10),
          AnalyticsFunnelRow(
            label: 'Attended',
            count: attended,
            fraction: maxVal > 0 ? (attended / maxVal).clamp(0.0, 1.0) : 0,
            color: const Color(0xFF3D7A5A),
            showRate: '${_snap.overallAttendanceRate.toStringAsFixed(0)}%',
          ),
        ],
      ),
    );
  }

  // ── Peak hours chart ──────────────────────────────────────────────────────

  Widget _peakHoursChart() {
    final hours = _snap.peakRegistrationHours
        .where((h) => h.hour >= 6 && h.hour <= 22)
        .toList();
    final hasData = hours.any((h) => h.count > 0);

    if (!hasData) {
      return const AnalyticsEmptyState(
          message: 'Not enough data for peak hours');
    }

    double maxY =
        hours.fold(0.0, (m, h) => h.count > m ? h.count.toDouble() : m);
    if (maxY == 0) maxY = 1;

    return AnalyticsChartCard(
      height: 120,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.4,
          barGroups: hours.asMap().entries.map((e) {
            final h = e.value;
            final isPeak = h.count > 0 &&
                h.count ==
                    hours.fold(0, (m, x) => x.count > m ? x.count : m);
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: h.count.toDouble(),
                  color: isPeak ? _accent : const Color(0xFFD0D0D0),
                  width: 9,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 16,
                interval: 2,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx >= hours.length) return const SizedBox.shrink();
                  if (idx % 2 != 0) return const SizedBox.shrink();
                  return Text(
                    AnalyticsFormatters.hourLabel(hours[idx].hour),
                    style: const TextStyle(
                        fontSize: 8, color: Color(0xFFA09489)),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Color(0xFFE9E1D6), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => _ink,
              getTooltipItem: (group, _, rod, __) {
                final h = hours[group.x];
                return BarTooltipItem(
                  '${AnalyticsFormatters.hourLabel(h.hour)}\n${rod.toY.toInt()} reg',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Event Rankings ────────────────────────────────────────────────────────

  Widget _eventRankings() {
    final top = _snap.eventPerformances.take(8).toList();
    if (top.isEmpty) {
      return const AnalyticsEmptyState(message: 'No events yet');
    }
    final maxRegs =
        top.first.registered > 0 ? top.first.registered.toDouble() : 1.0;
    return Column(
      children: top.asMap().entries.map((entry) {
        return _EventRankRow(
          rank: entry.key + 1,
          performance: entry.value,
          maxRegistrations: maxRegs,
        );
      }).toList(),
    );
  }

  // ── Category Performance ──────────────────────────────────────────────────

  Widget _categoryPerformance() {
    final cats = _snap.categoryBreakdown;
    final maxRegs = cats.fold<int>(
        0, (m, c) => c.totalRegistrations > m ? c.totalRegistrations : m);
    final maxVal = maxRegs > 0 ? maxRegs.toDouble() : 1.0;

    return AnalyticsChartCard(
      child: Column(
        children: cats.map((c) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        c.category,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${c.totalRegistrations} reg · '
                      '${c.avgFillRate.toStringAsFixed(0)}% fill',
                      style: const TextStyle(
                          color: Color(0xFFA09489), fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value:
                        (c.totalRegistrations / maxVal).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFF0F0F0),
                    valueColor:
                        const AlwaysStoppedAnimation(_ink),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${c.eventCount} event${c.eventCount == 1 ? '' : 's'} · '
                  '${c.totalAttendees} attended',
                  style: const TextStyle(
                      color: Color(0xFFA09489), fontSize: 10),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Attendee Insights ─────────────────────────────────────────────────────

  Widget _attendeeInsights() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AnalyticsKpiCard(
                icon: Icons.people_outline,
                label: 'Unique Attendees',
                value: '${_snap.uniqueAttendees}',
                sub: 'Distinct individuals',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnalyticsKpiCard(
                icon: Icons.repeat_outlined,
                label: 'Repeat Attendees',
                value: '${_snap.repeatAttendees}',
                sub: 'Attended 2+ events',
                accent: _snap.repeatAttendees > 0
                    ? const Color(0xFF2E7D32)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AnalyticsKpiCard(
                icon: Icons.check_circle_outline,
                label: 'Attendance Rate',
                value:
                    '${_snap.overallAttendanceRate.toStringAsFixed(0)}%',
                sub: '${(_snap.totalRegistrations - _snap.totalAttended).clamp(0, 999999)} no-shows',
                accent: AnalyticsColors.rateColor(_snap.overallAttendanceRate),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnalyticsKpiCard(
                icon: Icons.trending_down_outlined,
                label: 'No-Show Rate',
                value: '${_snap.overallNoShowRate.toStringAsFixed(0)}%',
                sub: 'Of registered attendees',
                accent: _snap.overallNoShowRate > 30
                    ? const Color(0xFFE65100)
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.bar_chart_outlined,
                  size: 28, color: Color(0xFFA09489)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No events to analyse',
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create and publish events to see registration and '
              'attendance analytics here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Action Card ────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE9E1D6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: accent),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── AI Insight Card ──────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final Map<String, dynamic> insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final color = insight['color'] as Color;
    final bg = insight['bg'] as Color? ?? Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(insight['icon'] as IconData, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight['title'] as String,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  insight['body'] as String,
                  style: const TextStyle(
                    color: Color(0xFF4A4540),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Seat Map Grid ────────────────────────────────────────────────────────────

class _SeatMapGrid extends StatelessWidget {
  final int capacity;
  final int bookedCount;
  final int reservedCount;
  final int blockedCount;

  const _SeatMapGrid({
    required this.capacity,
    required this.bookedCount,
    required this.reservedCount,
    required this.blockedCount,
  });

  @override
  Widget build(BuildContext context) {
    if (capacity <= 0) return const SizedBox.shrink();

    final clampedCapacity = capacity.clamp(1, 600);
    final booked = bookedCount.clamp(0, clampedCapacity);
    final reserved = reservedCount.clamp(0, clampedCapacity - booked);
    final blocked = blockedCount.clamp(0, clampedCapacity - booked - reserved);

    // Build seat list
    final seats = <_SeatState>[];
    for (int i = 0; i < booked; i++) seats.add(_SeatState.booked);
    for (int i = 0; i < reserved; i++) seats.add(_SeatState.reserved);
    for (int i = 0; i < blocked; i++) seats.add(_SeatState.blocked);
    while (seats.length < clampedCapacity) seats.add(_SeatState.available);

    // Shuffle deterministically for realistic look
    final rnd = math.Random(42);
    final shuffled = List<_SeatState>.from(seats)..shuffle(rnd);

    // Determine columns
    final cols = clampedCapacity <= 30
        ? 10
        : clampedCapacity <= 80
            ? 15
            : clampedCapacity <= 200
                ? 20
                : 25;

    final seatSize = clampedCapacity > 200 ? 9.0 : clampedCapacity > 80 ? 11.0 : 14.0;
    final spacing = clampedCapacity > 200 ? 2.0 : 3.0;

    return LayoutBuilder(builder: (ctx, constraints) {
      final availableWidth = constraints.maxWidth;
      final seatWithSpacing = seatSize + spacing;
      final actualCols =
          math.min(cols, (availableWidth / seatWithSpacing).floor());
      final rows = (shuffled.length / actualCols).ceil();

      return Column(
        children: List.generate(rows, (row) {
          return Padding(
            padding: EdgeInsets.only(bottom: spacing),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(actualCols, (col) {
                final idx = row * actualCols + col;
                if (idx >= shuffled.length) return SizedBox(width: seatSize + spacing);
                final state = shuffled[idx];
                final color = _colorForState(state);
                return Padding(
                  padding: EdgeInsets.only(right: spacing),
                  child: Container(
                    width: seatSize,
                    height: seatSize * 0.9,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      );
    });
  }

  Color _colorForState(_SeatState state) {
    switch (state) {
      case _SeatState.booked:
        return const Color(0xFFDC2626);
      case _SeatState.reserved:
        return const Color(0xFFD97706);
      case _SeatState.blocked:
        return const Color(0xFFBDBDBD);
      case _SeatState.available:
        return const Color(0xFF4CAF50);
    }
  }
}

// ── Event rank row ────────────────────────────────────────────────────────────

class _EventRankRow extends StatelessWidget {
  final int rank;
  final EventPerformance performance;
  final double maxRegistrations;

  const _EventRankRow({
    required this.rank,
    required this.performance,
    required this.maxRegistrations,
  });

  @override
  Widget build(BuildContext context) {
    final e = performance;
    final fraction =
        (e.registered / maxRegistrations).clamp(0.0, 1.0);
    final statusColor = _statusColor(e.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9E1D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? const Color(0xFFC46A3D)
                      : const Color(0xFFF5EDE5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: rank <= 3
                        ? Colors.white
                        : const Color(0xFFA09489),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.title,
                  style: const TextStyle(
                    color: Color(0xFF1F1A17),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  e.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                fraction >= 0.8
                    ? const Color(0xFF2E7D32)
                    : fraction >= 0.4
                        ? const Color(0xFF1565C0)
                        : const Color(0xFF9E9E9E),
              ),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _statText('${e.registered}', 'reg'),
              const SizedBox(width: 12),
              _statText('${e.expected}', 'expected'),
              const SizedBox(width: 12),
              _statText('${e.attended}', 'attended'),
              const Spacer(),
              Text(
                '${(fraction * 100).toStringAsFixed(0)}% full',
                style: const TextStyle(
                  color: Color(0xFFA09489),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statText(String value, String label) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Color(0xFF1F1A17),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: const TextStyle(
                color: Color(0xFFA09489), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'upcoming':
        return const Color(0xFF5A6F8C);
      case 'ongoing':
        return const Color(0xFF3D7A5A);
      case 'completed':
        return const Color(0xFF6E6258);
      case 'draft':
        return const Color(0xFFB7791F);
      default:
        return const Color(0xFFA09489);
    }
  }
}
