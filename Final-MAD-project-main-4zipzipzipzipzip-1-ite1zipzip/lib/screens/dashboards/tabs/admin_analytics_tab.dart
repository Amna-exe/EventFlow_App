import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/analytics_model.dart';
import '../../../services/analytics_service.dart';
import '../../../widgets/analytics/analytics_widgets.dart';
import '../../../utils/analytics_utils.dart';

class AdminAnalyticsTab extends StatefulWidget {
  const AdminAnalyticsTab({super.key});

  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
  late AdminAnalyticsSnapshot _snap;

  @override
  void initState() {
    super.initState();
    _snap = AnalyticsService.computePlatformWide();
  }

  void _reload() {
    AnalyticsService.invalidateAll();
    setState(() => _snap = AnalyticsService.computePlatformWide());
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFFC46A3D),
      onRefresh: () async => _reload(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 20),

            const AnalyticsSectionLabel('Platform KPIs'),
            const SizedBox(height: 12),
            _kpiGrid(),
            const SizedBox(height: 24),

            const AnalyticsSectionLabel('Monthly Activity'),
            const SizedBox(height: 4),
            const Text(
              'Bookings and registrations — last 6 months',
              style: TextStyle(color: Color(0xFF9B9B9B), fontSize: 12),
            ),
            const SizedBox(height: 12),
            _monthlyActivityChart(),
            const SizedBox(height: 24),

            const AnalyticsSectionLabel('User Growth'),
            const SizedBox(height: 4),
            const Text(
              'Cumulative user base — last 6 months',
              style: TextStyle(color: Color(0xFF9B9B9B), fontSize: 12),
            ),
            const SizedBox(height: 12),
            _userGrowthChart(),
            const SizedBox(height: 24),

            const AnalyticsSectionLabel('Booking Conversion'),
            const SizedBox(height: 12),
            _bookingFunnel(),
            const SizedBox(height: 24),

            const AnalyticsSectionLabel('User Distribution'),
            const SizedBox(height: 12),
            _userDistribution(),
            const SizedBox(height: 24),

            if (_snap.topOrganizers.isNotEmpty) ...[
              const AnalyticsSectionLabel('Top Organisers'),
              const SizedBox(height: 4),
              const Text(
                'Ranked by total registrations',
                style: TextStyle(color: Color(0xFF9B9B9B), fontSize: 12),
              ),
              const SizedBox(height: 12),
              _topOrganizers(),
              const SizedBox(height: 24),
            ],

            if (_snap.topVenues.isNotEmpty) ...[
              const AnalyticsSectionLabel('Top Venues'),
              const SizedBox(height: 4),
              const Text(
                'Ranked by total revenue',
                style: TextStyle(color: Color(0xFF9B9B9B), fontSize: 12),
              ),
              const SizedBox(height: 12),
              _topVenues(),
              const SizedBox(height: 24),
            ],

            if (_snap.eventsByCategory.isNotEmpty) ...[
              const AnalyticsSectionLabel('Events by Category'),
              const SizedBox(height: 12),
              _categoryBreakdown(),
              const SizedBox(height: 24),
            ],

            const AnalyticsSectionLabel('Event Health'),
            const SizedBox(height: 12),
            _eventHealth(),
            const SizedBox(height: 24),

            if (_snap.bottlenecks.isNotEmpty) ...[
              const AnalyticsSectionLabel('Operational Bottlenecks'),
              const SizedBox(height: 4),
              const Text(
                'Issues requiring attention',
                style: TextStyle(color: Color(0xFF9B9B9B), fontSize: 12),
              ),
              const SizedBox(height: 12),
              _bottlenecks(),
              const SizedBox(height: 24),
            ],

            if (_snap.riskIndicators.isNotEmpty) ...[
              const AnalyticsSectionLabel('Risk Indicators'),
              const SizedBox(height: 4),
              const Text(
                'Signals that may affect platform health',
                style: TextStyle(color: Color(0xFF9B9B9B), fontSize: 12),
              ),
              const SizedBox(height: 12),
              _riskIndicators(),
              const SizedBox(height: 24),
            ],

            const AnalyticsSectionLabel('System Utilisation'),
            const SizedBox(height: 12),
            _systemUtilization(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Platform Analytics',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'System-wide performance, growth, and health metrics.',
          style: TextStyle(
              color: Color(0xFF6B6B6B), fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  // ── KPI grid ──────────────────────────────────────────────────────────────

  Widget _kpiGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AnalyticsKpiCard(
                icon: Icons.people_outline,
                label: 'Total Users',
                value: '${_snap.totalUsers}',
                sub: '${_snap.organizers} org · '
                    '${_snap.venueOwners} venues · '
                    '${_snap.attendees} att',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnalyticsKpiCard(
                icon: Icons.event_outlined,
                label: 'Total Events',
                value: '${_snap.totalEvents}',
                sub: '${_snap.publishedEvents} published',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AnalyticsKpiCard(
                icon: Icons.meeting_room_outlined,
                label: 'Bookings',
                value: '${_snap.totalBookings}',
                sub:
                    '${_snap.bookingConversionRate.toStringAsFixed(0)}% conversion',
                accent: _snap.bookingConversionRate >= 50
                    ? const Color(0xFF2E7D32)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnalyticsKpiCard(
                icon: Icons.how_to_reg_outlined,
                label: 'Registrations',
                value: '${_snap.totalRegistrations}',
                sub:
                    '${_snap.avgRegistrationsPerEvent.toStringAsFixed(1)} avg per event',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnalyticsKpiCard(
          icon: Icons.speed_outlined,
          label: 'System Utilisation',
          value:
              '${_snap.systemUtilizationRate.toStringAsFixed(1)}%',
          sub: 'Confirmed bookings vs total capacity',
          accent: AnalyticsColors.utilColor(_snap.systemUtilizationRate),
        ),
      ],
    );
  }

  // ── Monthly activity chart ─────────────────────────────────────────────────

  Widget _monthlyActivityChart() {
    final bookings = _snap.monthlyBookings;
    final regs = _snap.monthlyRegistrations;

    if (bookings.isEmpty && regs.isEmpty) {
      return const AnalyticsEmptyState(message: 'No activity data yet');
    }

    final allVals = [
      ...bookings.map((p) => p.value),
      ...regs.map((p) => p.value),
    ];
    double maxY = allVals.fold(0.0, (m, v) => v > m ? v : m);
    if (maxY == 0) maxY = 1;

    final bkGroups = bookings.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barsSpace: 3,
        barRods: [
          BarChartRodData(
            toY: e.value.value,
            color: const Color(0xFF1A1A1A),
            width: 11,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(3)),
          ),
          if (e.key < regs.length)
            BarChartRodData(
              toY: regs[e.key].value,
              color: const Color(0xFFD0D0D0),
              width: 11,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(3)),
            ),
        ],
      );
    }).toList();

    return AnalyticsChartCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _legend(const Color(0xFF1A1A1A), 'Bookings'),
              const SizedBox(width: 16),
              _legend(const Color(0xFFD0D0D0), 'Registrations'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.3,
                barGroups: bkGroups,
                alignment: BarChartAlignment.spaceAround,
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFF9B9B9B)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 18,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= bookings.length) {
                          return const SizedBox.shrink();
                        }
                        final month = bookings[i].date.month;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _monthNames[month - 1],
                            style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF9B9B9B)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                      color: Color(0xFFEEEEEE), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1A1A1A),
                    getTooltipItem: (group, _, rod, rodIndex) {
                      final label =
                          rodIndex == 0 ? 'Bookings' : 'Regs';
                      return BarTooltipItem(
                        '$label\n${rod.toY.toInt()}',
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
        ],
      ),
    );
  }

  // ── User growth chart ──────────────────────────────────────────────────────

  Widget _userGrowthChart() {
    final points = _snap.userGrowthTrend;
    if (points.isEmpty) {
      return const AnalyticsEmptyState(message: 'No user growth data');
    }

    double maxY = points.fold(0.0, (m, p) => p.value > m ? p.value : m);
    if (maxY == 0) maxY = 1;

    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    return AnalyticsChartCard(
      height: 140,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: 0,
          maxY: maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Color(0xFFEEEEEE), strokeWidth: 1),
          ),
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
                      fontSize: 9, color: Color(0xFF9B9B9B)),
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
                          fontSize: 9, color: Color(0xFF9B9B9B)),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: const Color(0xFF1A1A1A),
              barWidth: 2,
              isCurved: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: const Color(0xFF1A1A1A),
                  strokeColor: Colors.white,
                  strokeWidth: 1.5,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF1A1A1A).withAlpha(18),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1A1A1A),
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toInt()} users',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF6B6B6B), fontSize: 11)),
      ],
    );
  }

  // ── Booking funnel ────────────────────────────────────────────────────────

  Widget _bookingFunnel() {
    final total = _snap.totalBookings;
    return AnalyticsChartCard(
      child: Column(
        children: [
          AnalyticsFunnelRow(
            label: 'Total',
            count: total,
            fraction: 1.0,
            color: const Color(0xFFDDDDDD),
          ),
          const SizedBox(height: 10),
          AnalyticsFunnelRow(
            label: 'Confirmed',
            count: _snap.confirmedBookings,
            fraction:
                total > 0 ? _snap.confirmedBookings / total : 0,
            color: const Color(0xFF2E7D32),
            showRate:
                '${_snap.bookingConversionRate.toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 10),
          AnalyticsFunnelRow(
            label: 'Pending',
            count: _snap.pendingBookings,
            fraction: total > 0 ? _snap.pendingBookings / total : 0,
            color: const Color(0xFF1565C0),
          ),
          const SizedBox(height: 10),
          AnalyticsFunnelRow(
            label: 'Cancelled',
            count: _snap.cancelledBookings,
            fraction:
                total > 0 ? _snap.cancelledBookings / total : 0,
            color: const Color(0xFFE65100),
          ),
        ],
      ),
    );
  }

  // ── User distribution ─────────────────────────────────────────────────────

  Widget _userDistribution() {
    final roles = [
      ('Organisers', _snap.organizers, const Color(0xFF1565C0)),
      ('Venue Owners', _snap.venueOwners, const Color(0xFF6A1B9A)),
      ('Attendees', _snap.attendees, const Color(0xFF2E7D32)),
    ];

    return AnalyticsChartCard(
      child: Column(
        children: roles.map((r) {
          final fraction = _snap.totalUsers > 0
              ? (r.$2 / _snap.totalUsers).clamp(0.0, 1.0)
              : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      r.$1,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${r.$2} (${(fraction * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(
                        color: r.$3,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fraction,
                    backgroundColor: const Color(0xFFF0F0F0),
                    valueColor: AlwaysStoppedAnimation<Color>(r.$3),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Top organisers ────────────────────────────────────────────────────────

  Widget _topOrganizers() {
    return Column(
      children: _snap.topOrganizers.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final o = entry.value;
        return AnalyticsRankingRow(
          rank: rank,
          title: o.name,
          subtitle:
              '${o.eventCount} event${o.eventCount == 1 ? '' : 's'}',
          primaryValue: '${o.totalRegistrations} reg',
          secondaryValue:
              '${o.avgFillRate.toStringAsFixed(0)}% fill',
        );
      }).toList(),
    );
  }

  // ── Top venues ────────────────────────────────────────────────────────────

  Widget _topVenues() {
    return Column(
      children: _snap.topVenues.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final v = entry.value;
        return AnalyticsRankingRow(
          rank: rank,
          title: v.ownerName,
          subtitle:
              '${v.bookingCount} confirmed booking${v.bookingCount == 1 ? '' : 's'}',
          primaryValue: AnalyticsFormatters.currency(v.totalRevenue),
        );
      }).toList(),
    );
  }

  // ── Category breakdown ────────────────────────────────────────────────────

  Widget _categoryBreakdown() {
    final entries = _snap.eventsByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(7).toList();
    final maxVal =
        top.isNotEmpty ? top.first.value.toDouble() : 1.0;

    return AnalyticsChartCard(
      child: Column(
        children: top.map((cat) {
          final fraction = (cat.value / maxVal).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    cat.key,
                    style: const TextStyle(
                        color: Color(0xFF6B6B6B), fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: const Color(0xFFF0F0F0),
                      valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF1A1A1A)),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  child: Text(
                    '${cat.value}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Event health ──────────────────────────────────────────────────────────

  Widget _eventHealth() {
    return Row(
      children: [
        _healthCard('Published', '${_snap.publishedEvents}',
            const Color(0xFF2E7D32)),
        const SizedBox(width: 10),
        _healthCard(
            'Draft', '${_snap.draftEvents}', const Color(0xFFE65100)),
        const SizedBox(width: 10),
        _healthCard('Completed', '${_snap.completedEvents}',
            const Color(0xFF546E7A)),
      ],
    );
  }

  Widget _healthCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                  color: Color(0xFF9B9B9B), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottlenecks ───────────────────────────────────────────────────────────

  Widget _bottlenecks() {
    return Column(
      children: _snap.bottlenecks.map((b) {
        final color = AnalyticsColors.severityColor(b.severity);
        return AnalyticsInsightTile(
          icon: b.severity == 'high'
              ? Icons.error_outline
              : Icons.warning_amber_outlined,
          title: b.title,
          body: b.description,
          color: color,
        );
      }).toList(),
    );
  }

  // ── Risk indicators ───────────────────────────────────────────────────────

  Widget _riskIndicators() {
    return Column(
      children: _snap.riskIndicators.map((r) {
        return AnalyticsInsightTile(
          icon: Icons.shield_outlined,
          title: r.title,
          body: r.description,
          color: const Color(0xFF6A1B9A),
        );
      }).toList(),
    );
  }

  // ── System utilisation ────────────────────────────────────────────────────

  Widget _systemUtilization() {
    final rate = _snap.systemUtilizationRate;
    final color = AnalyticsColors.utilColor(rate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Booking Capacity Used',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (rate / 100).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rate < 30
                ? 'Low utilisation — most venue capacity is unused. '
                    'Promote available rooms to attract more bookings.'
                : rate < 60
                    ? 'Moderate utilisation. Room for growth across venue portfolio.'
                    : 'Strong utilisation. Platform is operating at high capacity.',
            style: const TextStyle(
                color: Color(0xFF6B6B6B), fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
