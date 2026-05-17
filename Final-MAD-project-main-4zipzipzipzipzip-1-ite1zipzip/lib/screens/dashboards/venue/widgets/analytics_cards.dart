import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../../models/analytics_model.dart';
import '../../../../widgets/analytics/analytics_widgets.dart';
import '../../../../../utils/analytics_utils.dart';

class AnalyticsOverviewCards extends StatelessWidget {
  final AnalyticsSnapshot data;
  const AnalyticsOverviewCards({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Business Metrics'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _MetricCard(
              icon: Icons.attach_money_rounded,
              label: 'Total Revenue',
              value: '\$${data.totalRevenue.toStringAsFixed(0)}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricCard(
              icon: Icons.trending_up_rounded,
              label: 'Avg Booking Value',
              value: '\$${data.avgBookingValue.toStringAsFixed(0)}',
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _MetricCard(
              icon: Icons.percent_rounded,
              label: 'Occupancy Rate',
              value: '${data.occupancyRate.toStringAsFixed(1)}%',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricCard(
              icon: Icons.cancel_outlined,
              label: 'Cancellation Rate',
              value: '${data.cancellationRate.toStringAsFixed(1)}%',
              muted: true,
            ),
          ),
        ]),
        const SizedBox(height: 24),
        _sectionLabel('Status Breakdown'),
        const SizedBox(height: 12),
        _StatusRow(data: data),
        if (data.revenueByBuilding.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionLabel('Revenue by Building'),
          const SizedBox(height: 12),
          ...data.revenueByBuilding
              .map((b) => _BuildingRevenueRow(stat: b)),
        ],
        if (data.topRooms.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionLabel('Revenue per Room'),
          const SizedBox(height: 12),
          ..._revenueByRoom(data.topRooms).asMap().entries.map(
                (e) => _RoomRevenueRow(rank: e.key + 1, stat: e.value),
              ),
        ],
        const SizedBox(height: 24),
        _sectionLabel('Top Rooms by Bookings'),
        const SizedBox(height: 12),
        if (data.topRooms.isEmpty)
          _emptyState('No room bookings yet')
        else
          ...data.topRooms.asMap().entries.map(
                (e) => _RoomStatRow(rank: e.key + 1, stat: e.value),
              ),
        const SizedBox(height: 24),
        _sectionLabel('Peak Booking Times'),
        const SizedBox(height: 12),
        _PeakTimesCard(data: data),
        const SizedBox(height: 24),
        _sectionLabel('Customer Insights'),
        const SizedBox(height: 12),
        if (data.topOrganizers.isEmpty)
          _emptyState('No client data yet')
        else
          ...data.topOrganizers.take(5).map((o) => _ClientRow(stat: o)),
        if (data.repeatOrganizers.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RepeatClientsChip(count: data.repeatOrganizers.length),
        ],
        if (data.paymentBreakdown.paid > 0 ||
            data.paymentBreakdown.pending > 0 ||
            data.paymentBreakdown.refunded > 0) ...[
          const SizedBox(height: 24),
          _sectionLabel('Payment Breakdown'),
          const SizedBox(height: 12),
          _PaymentBreakdownCard(breakdown: data.paymentBreakdown),
        ],
        if (data.underutilizedRooms.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionLabel('Underutilised Rooms'),
          const SizedBox(height: 4),
          const Text(
            'Rooms with low booking activity',
            style: TextStyle(
                color: Color(0xFF9B9B9B),
                fontSize: 12,
                fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 12),
          _UnderutilizedRoomsCard(rooms: data.underutilizedRooms),
        ],
        const SizedBox(height: 24),
        _sectionLabel('Intelligent Insights'),
        const SizedBox(height: 12),
        VenueInsightsPanel(data: data),
      ],
    );
  }

  List<RoomStats> _revenueByRoom(List<RoomStats> rooms) {
    final sorted = [...rooms]..sort((a, b) => b.revenue.compareTo(a.revenue));
    return sorted;
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      );

  Widget _emptyState(String msg) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Text(msg,
            style: const TextStyle(color: Color(0xFF9B9B9B), fontSize: 13)),
      );
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool muted;
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: muted ? const Color(0xFFEEEEEE) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon,
                color: muted ? const Color(0xFF9B9B9B) : Colors.white,
                size: 17),
          ),
          const SizedBox(height: 14),
          Text(value,
              style: TextStyle(
                  color: muted
                      ? const Color(0xFF9B9B9B)
                      : const Color(0xFF1A1A1A),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9B9B9B),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1)),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final AnalyticsSnapshot data;
  const _StatusRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.totalBookings;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          _pill('${data.confirmedBookings}', 'Confirmed',
              Colors.white, const Color(0xFF1A1A1A)),
          const SizedBox(width: 8),
          _pill('${data.pendingBookings}', 'Pending',
              const Color(0xFF3D3D3D), const Color(0xFFF0F0F0)),
          const SizedBox(width: 8),
          _pill('${data.cancelledBookings}', 'Cancelled',
              const Color(0xFF9B9B9B), const Color(0xFFF5F5F5)),
          const SizedBox(width: 8),
          _pill('$total', 'Total',
              const Color(0xFF1A1A1A), const Color(0xFFEEEEEE)),
        ],
      ),
    );
  }

  Widget _pill(String count, String label, Color fg, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(count,
                style: TextStyle(
                    color: fg,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9B9B9B),
                    fontSize: 10,
                    fontWeight: FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

class _BuildingRevenueRow extends StatelessWidget {
  final BuildingRevenue stat;
  const _BuildingRevenueRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.apartment_outlined,
                color: Color(0xFF3D3D3D), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.buildingName,
                    style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(
                    '${stat.bookingCount} confirmed booking${stat.bookingCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: Color(0xFF9B9B9B), fontSize: 11)),
              ],
            ),
          ),
          Text(
            '\$${stat.revenue.toStringAsFixed(0)}',
            style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w700,
                fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _RoomStatRow extends StatelessWidget {
  final int rank;
  final RoomStats stat;
  const _RoomStatRow({required this.rank, required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$rank',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.roomName,
                    style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(stat.buildingName,
                    style: const TextStyle(
                        color: Color(0xFF9B9B9B), fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${stat.bookingCount} booking${stat.bookingCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
              Text('\$${stat.revenue.toStringAsFixed(0)} rev',
                  style: const TextStyle(
                      color: Color(0xFF9B9B9B), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoomRevenueRow extends StatelessWidget {
  final int rank;
  final RoomStats stat;
  const _RoomRevenueRow({required this.rank, required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$rank',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.roomName,
                    style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(stat.buildingName,
                    style: const TextStyle(
                        color: Color(0xFF9B9B9B), fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${stat.revenue.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
              Text(
                  '${stat.bookingCount} booking${stat.bookingCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: Color(0xFF9B9B9B), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeakTimesCard extends StatelessWidget {
  final AnalyticsSnapshot data;
  const _PeakTimesCard({required this.data});

  static const _dayAbbrs = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final noData = data.totalBookings == 0;

    if (noData) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No booking data yet',
                style: TextStyle(color: Color(0xFF9B9B9B), fontSize: 13)),
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildHourChart(),
        const SizedBox(height: 12),
        _buildDayChart(),
      ],
    );
  }

  Widget _buildHourChart() {
    final hours = data.bookingsByHour;
    final workHours =
        hours.where((h) => h.hour >= 6 && h.hour <= 22).toList();
    double maxCount =
        workHours.fold(0.0, (m, h) => h.count > m ? h.count.toDouble() : m);
    if (maxCount == 0) maxCount = 1;

    final bars = workHours.asMap().entries.map((e) {
      final h = e.value;
      final isPeak = h.count > 0 &&
          h.count ==
              workHours.fold(0, (m, x) => x.count > m ? x.count : m);
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: h.count.toDouble(),
            color: isPeak
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFD0D0D0),
            width: 8,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      );
    }).toList();

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
            children: [
              const Icon(Icons.schedule_outlined,
                  color: Color(0xFF1A1A1A), size: 16),
              const SizedBox(width: 6),
              const Text('Bookings by Hour',
                  style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: BarChart(
              BarChartData(
                maxY: maxCount * 1.3,
                barGroups: bars,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFFEEEEEE),
                    strokeWidth: 1,
                  ),
                ),
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
                      reservedSize: 18,
                      interval: 2,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx >= workHours.length) {
                          return const SizedBox.shrink();
                        }
                        final h = workHours[idx].hour;
                        if (idx % 2 != 0) return const SizedBox.shrink();
                        final suffix = h >= 12 ? 'p' : 'a';
                        final display = h == 0
                            ? '12a'
                            : h == 12
                                ? '12p'
                                : h > 12
                                    ? '${h - 12}$suffix'
                                    : '$h$suffix';
                        return Text(display,
                            style: const TextStyle(
                                color: Color(0xFF9B9B9B), fontSize: 9));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1A1A1A),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final h = workHours[group.x].hour;
                      final suffix = h >= 12 ? 'PM' : 'AM';
                      final display = h == 0
                          ? '12AM'
                          : h == 12
                              ? '12PM'
                              : h > 12
                                  ? '${h - 12}$suffix'
                                  : '$h$suffix';
                      return BarTooltipItem(
                        '$display\n${rod.toY.toInt()} bookings',
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

  Widget _buildDayChart() {
    final days = data.bookingsByDay;
    double maxCount =
        days.fold(0.0, (m, d) => d.count > m ? d.count.toDouble() : m);
    if (maxCount == 0) maxCount = 1;

    final bars = days.asMap().entries.map((e) {
      final d = e.value;
      final isPeak = d.count > 0 &&
          d.count == days.fold(0, (m, x) => x.count > m ? x.count : m);
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: d.count.toDouble(),
            color: isPeak
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFD0D0D0),
            width: 22,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

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
            children: [
              const Icon(Icons.calendar_today_outlined,
                  color: Color(0xFF1A1A1A), size: 16),
              const SizedBox(width: 6),
              const Text('Bookings by Day of Week',
                  style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: BarChart(
              BarChartData(
                maxY: maxCount * 1.3,
                barGroups: bars,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFFEEEEEE),
                    strokeWidth: 1,
                  ),
                ),
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
                      reservedSize: 18,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx >= _dayAbbrs.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(_dayAbbrs[idx],
                            style: const TextStyle(
                                color: Color(0xFF9B9B9B), fontSize: 9));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1A1A1A),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                      '${_dayAbbrs[group.x]}\n${rod.toY.toInt()} bookings',
                      const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  final OrganizerStats stat;
  const _ClientRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              stat.name.isNotEmpty
                  ? stat.name[0].toUpperCase()
                  : 'O',
              style: const TextStyle(
                  color: Color(0xFF3D3D3D),
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(stat.name,
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${stat.bookingCount} bookings',
                  style: const TextStyle(
                      color: Color(0xFF3D3D3D),
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
              Text('\$${stat.totalSpend.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Color(0xFF9B9B9B), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RepeatClientsChip extends StatelessWidget {
  final int count;
  const _RepeatClientsChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat_rounded,
              size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            '$count repeat client${count == 1 ? '' : 's'}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Venue Insights Panel
// ─────────────────────────────────────────────────────────────────────────────

class VenueInsightsPanel extends StatelessWidget {
  final AnalyticsSnapshot data;
  const VenueInsightsPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final insights = _buildInsights();
    if (insights.isEmpty) return const SizedBox.shrink();
    return Column(
      children: insights
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InsightCard(
                icon: item.$1,
                color: item.$2,
                title: item.$3,
                body: item.$4,
              ),
            ),
          )
          .toList(),
    );
  }

  List<(IconData, Color, String, String)> _buildInsights() {
    final items = <(IconData, Color, String, String)>[];

    // 1. Top room
    if (data.topRooms.isNotEmpty) {
      final top = data.topRooms.first;
      items.add((
        Icons.star_outline,
        const Color(0xFF1565C0),
        'Top-performing room',
        '"${top.roomName}" leads with ${top.bookingCount} '
            'booking${top.bookingCount == 1 ? '' : 's'} and '
            '\$${top.revenue.toStringAsFixed(0)} in revenue.',
      ));
    }

    // 2. Occupancy
    final occ = data.occupancyRate;
    if (occ > 0) {
      final IconData icon;
      final Color color;
      final String body;
      if (occ >= 70) {
        icon = Icons.trending_up;
        color = const Color(0xFF2E7D32);
        body =
            'Your average occupancy is ${occ.toStringAsFixed(0)}% — well above the 70% benchmark. Keep it up!';
      } else if (occ >= 40) {
        icon = Icons.swap_horiz;
        color = const Color(0xFFE65100);
        body =
            'Your average occupancy is ${occ.toStringAsFixed(0)}%. Consider promoting lower-demand rooms with discounts.';
      } else {
        icon = Icons.warning_amber_outlined;
        color = const Color(0xFFDC2626);
        body =
            'Occupancy is only ${occ.toStringAsFixed(0)}%. Review pricing and availability to attract more bookings.';
      }
      items.add((icon, color, 'Occupancy rate', body));
    }

    // 3. Revenue spread
    if (data.revenueByBuilding.length > 1) {
      final topBuilding = data.revenueByBuilding.first;
      items.add((
        Icons.business_outlined,
        const Color(0xFF6A1B9A),
        'Revenue concentration',
        '"${topBuilding.buildingName}" drives the most revenue '
            '(\$${topBuilding.revenue.toStringAsFixed(0)}). '
            'Diversifying your portfolio may reduce risk.',
      ));
    }

    // 4. Cancellation warning
    final total = data.totalBookings;
    final cancelled = data.cancelledBookings;
    if (total > 0 && cancelled / total > 0.2) {
      items.add((
        Icons.cancel_outlined,
        const Color(0xFFDC2626),
        'High cancellation rate',
        '${(cancelled / total * 100).toStringAsFixed(0)}% of bookings were cancelled. '
            'Consider tightening your cancellation policy or following up with organisers.',
      ));
    }

    // 5. Repeat clients
    if (data.repeatOrganizers.isNotEmpty) {
      items.add((
        Icons.people_outline,
        const Color(0xFF2E7D32),
        'Loyal clients',
        '${data.repeatOrganizers.length} '
            'organiser${data.repeatOrganizers.length == 1 ? '' : 's'} '
            'have booked with you more than once — a strong sign of trust.',
      ));
    }

    return items;
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _InsightCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF4A4A4A),
                    fontSize: 12,
                    height: 1.45,
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

// ─────────────────────────────────────────────────────────────────────────────
// Payment Breakdown Card
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentBreakdownCard extends StatelessWidget {
  final PaymentBreakdown breakdown;
  const _PaymentBreakdownCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final total = breakdown.paid + breakdown.pending + breakdown.refunded;
    final totalRevenue = breakdown.paidRevenue +
        breakdown.pendingRevenue +
        breakdown.refundedRevenue;

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
                'Payment Status',
                style: TextStyle(
                  color: Color(0xFF9B9B9B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                AnalyticsFormatters.currency(totalRevenue),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _payRow(
            label: 'Paid',
            count: breakdown.paid,
            revenue: breakdown.paidRevenue,
            total: total,
            color: const Color(0xFF2E7D32),
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 10),
          _payRow(
            label: 'Pending',
            count: breakdown.pending,
            revenue: breakdown.pendingRevenue,
            total: total,
            color: const Color(0xFF1565C0),
            icon: Icons.schedule_outlined,
          ),
          const SizedBox(height: 10),
          _payRow(
            label: 'Refunded',
            count: breakdown.refunded,
            revenue: breakdown.refundedRevenue,
            total: total,
            color: const Color(0xFFE65100),
            icon: Icons.reply_outlined,
          ),
          if (total > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  if (breakdown.paid > 0)
                    Expanded(
                      flex: breakdown.paid,
                      child: Container(
                          height: 6,
                          color: const Color(0xFF2E7D32)),
                    ),
                  if (breakdown.pending > 0)
                    Expanded(
                      flex: breakdown.pending,
                      child: Container(
                          height: 6,
                          color: const Color(0xFF1565C0)),
                    ),
                  if (breakdown.refunded > 0)
                    Expanded(
                      flex: breakdown.refunded,
                      child: Container(
                          height: 6,
                          color: const Color(0xFFE65100)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _payRow({
    required String label,
    required int count,
    required double revenue,
    required int total,
    required Color color,
    required IconData icon,
  }) {
    final pct = total > 0 ? (count / total * 100) : 0.0;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$count · ${AnalyticsFormatters.currency(revenue)}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFFF0F0F0),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Underutilised Rooms Card
// ─────────────────────────────────────────────────────────────────────────────

class _UnderutilizedRoomsCard extends StatelessWidget {
  final List<UnderutilizedRoom> rooms;
  const _UnderutilizedRoomsCard({required this.rooms});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rooms.map((r) => _UnderutilizedRoomRow(room: r)).toList(),
    );
  }
}

class _UnderutilizedRoomRow extends StatelessWidget {
  final UnderutilizedRoom room;
  const _UnderutilizedRoomRow({required this.room});

  @override
  Widget build(BuildContext context) {
    final pct = room.utilizationPct;
    final color = pct < 10
        ? const Color(0xFFDC2626)
        : pct < 20
            ? const Color(0xFFE65100)
            : const Color(0xFF9B9B9B);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.meeting_room_outlined,
                    size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.roomName,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      room.buildingName,
                      style: const TextStyle(
                          color: Color(0xFF9B9B9B), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    room.bookingCount == 0
                        ? 'No bookings'
                        : '${room.bookingCount} booking${room.bookingCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(0)}% utilised',
                    style: const TextStyle(
                        color: Color(0xFF9B9B9B), fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            room.bookingCount == 0
                ? 'Consider promoting this room or reviewing its pricing and availability.'
                : 'Low relative activity. Targeted promotions may help increase bookings.',
            style: const TextStyle(
                color: Color(0xFF9B9B9B), fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}
