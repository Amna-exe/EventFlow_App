import '../models/analytics_model.dart';
import '../models/user_model.dart';
import '../models/payment_model.dart';
import 'auth_service.dart';
import 'venue_service.dart';
import 'booking_management_service.dart';
import 'registration_service.dart';
import 'payment_service.dart';

class AnalyticsService {
  // ── Simple in-memory cache ─────────────────────────────────────────────────

  static final Map<String, _CacheEntry<AnalyticsSnapshot>> _venueCache = {};
  static _CacheEntry<AdminAnalyticsSnapshot>? _adminCache;
  static final Map<String, _CacheEntry<OrganizerAnalyticsSnapshot>>
      _orgCache = {};
  static final Map<String, _CacheEntry<AttendeeAnalyticsSnapshot>>
      _attendeeCache = {};

  static const _cacheTtlMinutes = 5;

  static T? _hit<T>(_CacheEntry<T>? entry) {
    if (entry == null) return null;
    final age = DateTime.now().difference(entry.timestamp).inMinutes;
    return age < _cacheTtlMinutes ? entry.value : null;
  }

  static void invalidateAll() {
    _venueCache.clear();
    _adminCache = null;
    _orgCache.clear();
    _attendeeCache.clear();
  }

  // ── Venue Owner Snapshot ───────────────────────────────────────────────────

  static AnalyticsSnapshot compute(String ownerId) {
    final cached = _hit(_venueCache[ownerId]);
    if (cached != null) return cached;

    final result = _computeVenue(ownerId);
    _venueCache[ownerId] = _CacheEntry(result);
    return result;
  }

  static AnalyticsSnapshot _computeVenue(String ownerId) {
    final venue = VenueService();
    final bms = BookingManagementService();
    final ps = PaymentService();

    final buildings = venue.buildingsForOwner(ownerId);
    final ownerRoomIds = <String>{};
    final roomBuilding = <String, String>{};
    final roomName = <String, String>{};
    final buildingNameMap = <String, String>{};

    for (final b in buildings) {
      buildingNameMap[b.id] = b.name;
      for (final r in venue.roomsForBuilding(b.id)) {
        ownerRoomIds.add(r.id);
        roomBuilding[r.id] = b.id;
        roomName[r.id] = r.name;
      }
    }

    if (ownerRoomIds.isEmpty) return AnalyticsSnapshot.empty();

    final bookings = bms.getBookingsForOwner(ownerId);
    if (bookings.isEmpty) return AnalyticsSnapshot.empty();

    final confirmed = bookings.where((b) => b.isActive).toList();
    final cancelled =
        bookings.where((b) => b.isCancelled && !b.isRejected).toList();
    final rejected = bookings.where((b) => b.isRejected).toList();
    final pending = bookings.where((b) => b.isPending).toList();
    final allInactive = cancelled.length + rejected.length;

    final totalRevenue = confirmed.fold<double>(0, (s, b) => s + b.revenue);
    final avgBookingValue =
        confirmed.isEmpty ? 0.0 : totalRevenue / confirmed.length;

    final totalHours = ownerRoomIds.length * 16.0 * 30;
    final bookedHours =
        confirmed.fold<double>(0, (s, b) => s + b.durationHours);
    final occupancyRate = totalHours > 0
        ? (bookedHours / totalHours * 100).clamp(0.0, 100.0)
        : 0.0;

    final cancellationRate = bookings.isNotEmpty
        ? (allInactive / bookings.length * 100).clamp(0.0, 100.0)
        : 0.0;

    // ── Room stats ──────────────────────────────────────────────────────────
    final roomStats = <String, _RoomAccumulator>{};
    final roomBookingCount = <String, int>{};

    for (final rid in ownerRoomIds) {
      roomBookingCount[rid] = 0;
    }

    for (final b in confirmed) {
      roomStats.putIfAbsent(
        b.roomId,
        () => _RoomAccumulator(
          roomId: b.roomId,
          roomName: b.roomName,
          buildingName: b.buildingName,
        ),
      );
      roomStats[b.roomId]!.bookingCount++;
      roomStats[b.roomId]!.revenue += b.revenue;
      roomBookingCount[b.roomId] = (roomBookingCount[b.roomId] ?? 0) + 1;
    }

    final topRooms = roomStats.values
        .map((a) => RoomStats(
              roomId: a.roomId,
              roomName: a.roomName,
              buildingName: a.buildingName,
              bookingCount: a.bookingCount,
              revenue: a.revenue,
            ))
        .toList()
      ..sort((a, b) => b.bookingCount.compareTo(a.bookingCount));

    // ── Underutilised rooms ─────────────────────────────────────────────────
    // Rooms with < 20% of the max booking count across all rooms
    final maxBookings =
        roomBookingCount.values.fold(0, (m, c) => c > m ? c : m);
    final threshold = maxBookings > 0 ? maxBookings * 0.2 : 0;
    final underutilizedRooms = <UnderutilizedRoom>[];
    for (final rid in ownerRoomIds) {
      final bCount = roomBookingCount[rid] ?? 0;
      if (bCount <= threshold) {
        final bId = roomBuilding[rid] ?? '';
        final bName = buildingNameMap[bId] ?? '';
        final rName = roomName[rid] ?? rid;
        final utilPct = maxBookings > 0
            ? (bCount / maxBookings * 100).clamp(0.0, 100.0)
            : 0.0;
        underutilizedRooms.add(UnderutilizedRoom(
          roomId: rid,
          roomName: rName,
          buildingName: bName,
          bookingCount: bCount,
          utilizationPct: utilPct,
        ));
      }
    }
    underutilizedRooms.sort((a, b) => a.bookingCount.compareTo(b.bookingCount));

    // ── Building stats ──────────────────────────────────────────────────────
    final buildingAcc = <String, _BuildingAccumulator>{};
    for (final b in confirmed) {
      buildingAcc.putIfAbsent(
        b.buildingId,
        () => _BuildingAccumulator(
          buildingId: b.buildingId,
          buildingName: b.buildingName,
        ),
      );
      buildingAcc[b.buildingId]!.revenue += b.revenue;
      buildingAcc[b.buildingId]!.bookingCount++;
    }
    final revenueByBuilding = buildingAcc.values
        .map((a) => BuildingRevenue(
              buildingId: a.buildingId,
              buildingName: a.buildingName,
              revenue: a.revenue,
              bookingCount: a.bookingCount,
            ))
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    // ── Organizer stats ─────────────────────────────────────────────────────
    final orgStats = <String, _OrgAccumulator>{};
    for (final b in bookings) {
      orgStats.putIfAbsent(
        b.organizerId,
        () => _OrgAccumulator(
            organizerId: b.organizerId, name: b.organizerName),
      );
      orgStats[b.organizerId]!.bookingCount++;
      if (b.isActive) orgStats[b.organizerId]!.totalSpend += b.revenue;
    }
    final topOrganizers = orgStats.values
        .map((a) => OrganizerStats(
              organizerId: a.organizerId,
              name: a.name,
              bookingCount: a.bookingCount,
              totalSpend: a.totalSpend,
            ))
        .toList()
      ..sort((a, b) => b.bookingCount.compareTo(a.bookingCount));

    final repeatOrganizers =
        topOrganizers.where((o) => o.bookingCount > 1).toList();

    // ── Time-series: daily bookings ─────────────────────────────────────────
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final dailyCounts = <DateTime, double>{};
    for (var i = 0; i < 30; i++) {
      final d = thirtyDaysAgo.add(Duration(days: i));
      dailyCounts[DateTime(d.year, d.month, d.day)] = 0;
    }
    for (final b in bookings) {
      final key =
          DateTime(b.createdAt.year, b.createdAt.month, b.createdAt.day);
      if (dailyCounts.containsKey(key)) {
        dailyCounts[key] = dailyCounts[key]! + 1;
      }
    }
    final dailyBookings = dailyCounts.entries
        .map((e) => TimeSeriesPoint(e.key, e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // ── Time-series: weekly revenue ─────────────────────────────────────────
    final weeklyRevenue = <DateTime, double>{};
    for (var i = 0; i < 8; i++) {
      final weekStart =
          _startOfWeek(now.subtract(Duration(days: 7 * (7 - i))));
      weeklyRevenue[weekStart] = 0;
    }
    for (final b in confirmed) {
      final ws = _startOfWeek(b.start);
      if (weeklyRevenue.containsKey(ws)) {
        weeklyRevenue[ws] = weeklyRevenue[ws]! + b.revenue;
      }
    }
    final weeklyRevList = weeklyRevenue.entries
        .map((e) => TimeSeriesPoint(e.key, e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // ── Time-series: monthly revenue ────────────────────────────────────────
    final monthlyRevenue = <DateTime, double>{};
    for (var i = 5; i >= 0; i--) {
      monthlyRevenue[_monthStart(now.month - i, now.year)] = 0;
    }
    for (final b in confirmed) {
      final ms = DateTime(b.start.year, b.start.month);
      if (monthlyRevenue.containsKey(ms)) {
        monthlyRevenue[ms] = monthlyRevenue[ms]! + b.revenue;
      }
    }
    final monthlyRevList = monthlyRevenue.entries
        .map((e) => TimeSeriesPoint(e.key, e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // ── Peak hour/day heatmap ───────────────────────────────────────────────
    final hourCounts = <int, int>{};
    final dayCounts = <int, int>{};
    for (final b in confirmed) {
      final h = b.start.hour;
      hourCounts[h] = (hourCounts[h] ?? 0) + 1;
      final d = b.start.weekday;
      dayCounts[d] = (dayCounts[d] ?? 0) + 1;
    }
    final bookingsByHour =
        List.generate(24, (i) => HourSlotCount(i, hourCounts[i] ?? 0));
    final bookingsByDay =
        List.generate(7, (i) => DaySlotCount(i + 1, dayCounts[i + 1] ?? 0));

    // ── Payment breakdown ───────────────────────────────────────────────────
    int payPaid = 0;
    int payPending = 0;
    int payRefunded = 0;
    double payPaidRev = 0;
    double payPendingRev = 0;
    double payRefundedRev = 0;

    for (final b in confirmed) {
      final pay = ps.get(b.id);
      if (pay == null) continue;
      switch (pay.status) {
        case PaymentStatus.paid:
          payPaid++;
          payPaidRev += pay.amount;
          break;
        case PaymentStatus.refunded:
          payRefunded++;
          payRefundedRev += pay.amount;
          break;
        case PaymentStatus.pending:
          payPending++;
          payPendingRev += pay.amount;
          break;
      }
    }

    return AnalyticsSnapshot(
      totalRevenue: totalRevenue,
      avgBookingValue: avgBookingValue,
      occupancyRate: occupancyRate,
      cancellationRate: cancellationRate,
      totalBookings: bookings.length,
      confirmedBookings: confirmed.length,
      cancelledBookings: allInactive,
      pendingBookings: pending.length,
      topRooms: topRooms.take(5).toList(),
      revenueByBuilding: revenueByBuilding,
      topOrganizers: topOrganizers.take(5).toList(),
      repeatOrganizers: repeatOrganizers.take(5).toList(),
      dailyBookings: dailyBookings,
      weeklyRevenue: weeklyRevList,
      monthlyRevenue: monthlyRevList,
      bookingsByHour: bookingsByHour,
      bookingsByDay: bookingsByDay,
      underutilizedRooms: underutilizedRooms.take(5).toList(),
      paymentBreakdown: PaymentBreakdown(
        paid: payPaid,
        pending: payPending,
        refunded: payRefunded,
        paidRevenue: payPaidRev,
        pendingRevenue: payPendingRev,
        refundedRevenue: payRefundedRev,
      ),
    );
  }

  // ── Organiser Analytics Snapshot ──────────────────────────────────────────

  static OrganizerAnalyticsSnapshot computeForOrganizer(String organizerId) {
    final cached = _hit(_orgCache[organizerId]);
    if (cached != null) return cached;

    final result = _computeOrganizer(organizerId);
    _orgCache[organizerId] = _CacheEntry(result);
    return result;
  }

  static OrganizerAnalyticsSnapshot _computeOrganizer(String organizerId) {
    final auth = AuthService();
    final reg = RegistrationService();

    final myEvents = auth.allEvents
        .where((e) => e['organizerId'] == organizerId)
        .toList();

    if (myEvents.isEmpty) return OrganizerAnalyticsSnapshot.empty();

    final now = DateTime.now();
    int totalRegistrations = 0;
    int totalAttended = 0;
    int totalExpected = 0;

    final performances = <EventPerformance>[];

    for (final e in myEvents) {
      final eventId = e['id'] as String;
      final regs = reg.registrationsForEvent(eventId);
      final registered = regs.length;
      final attended = regs.where((r) => r['attended'] == true).length;
      final expected = (e['expectedAttendees'] as int?) ?? 0;
      final status = _computeEventStatus(e, now);

      final fillRate = expected > 0
          ? (registered / expected * 100).clamp(0.0, 100.0)
          : 0.0;
      final attendanceRate = registered > 0
          ? (attended / registered * 100).clamp(0.0, 100.0)
          : 0.0;

      performances.add(EventPerformance(
        eventId: eventId,
        title: e['title'] as String? ?? 'Untitled',
        category: e['category'] as String? ?? 'General',
        status: status,
        registered: registered,
        expected: expected,
        attended: attended,
        fillRate: fillRate,
        attendanceRate: attendanceRate,
        startDate: e['start'] as DateTime?,
      ));

      totalRegistrations += registered;
      totalAttended += attended;
      totalExpected += expected;
    }

    performances.sort((a, b) => b.registered.compareTo(a.registered));

    // ── Category breakdown ──────────────────────────────────────────────────
    final catMap = <String, _CatAccumulator>{};
    for (final p in performances) {
      catMap.putIfAbsent(p.category, () => _CatAccumulator(p.category));
      catMap[p.category]!.eventCount++;
      catMap[p.category]!.totalRegistrations += p.registered;
      catMap[p.category]!.totalAttendees += p.attended;
      catMap[p.category]!.totalExpected += p.expected;
    }
    final categoryBreakdown = catMap.values
        .map((c) => CategoryStats(
              category: c.category,
              eventCount: c.eventCount,
              totalRegistrations: c.totalRegistrations,
              totalAttendees: c.totalAttendees,
              avgFillRate: c.totalExpected > 0
                  ? (c.totalRegistrations / c.totalExpected * 100)
                      .clamp(0.0, 100.0)
                  : 0.0,
            ))
        .toList()
      ..sort((a, b) => b.totalRegistrations.compareTo(a.totalRegistrations));

    // ── Registration velocity — last 30 days ────────────────────────────────
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final allRegs = reg.all.where((r) {
      final eventId = r['eventId'] as String;
      return myEvents.any((e) => e['id'] == eventId);
    }).toList();

    final dailyRegCounts = <DateTime, double>{};
    for (var i = 0; i < 30; i++) {
      final d = thirtyDaysAgo.add(Duration(days: i));
      dailyRegCounts[DateTime(d.year, d.month, d.day)] = 0;
    }
    for (final r in allRegs) {
      final registeredAt = r['registeredAt'] as DateTime?;
      if (registeredAt == null) continue;
      final key =
          DateTime(registeredAt.year, registeredAt.month, registeredAt.day);
      if (dailyRegCounts.containsKey(key)) {
        dailyRegCounts[key] = dailyRegCounts[key]! + 1;
      }
    }
    final registrationVelocity = dailyRegCounts.entries
        .map((e) => TimeSeriesPoint(e.key, e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // ── Monthly registrations — last 6 months ───────────────────────────────
    final monthlyRegMap = <DateTime, double>{};
    for (var i = 5; i >= 0; i--) {
      monthlyRegMap[_monthStart(now.month - i, now.year)] = 0;
    }
    for (final r in allRegs) {
      final registeredAt = r['registeredAt'] as DateTime?;
      if (registeredAt == null) continue;
      final ms = DateTime(registeredAt.year, registeredAt.month);
      if (monthlyRegMap.containsKey(ms)) {
        monthlyRegMap[ms] = monthlyRegMap[ms]! + 1;
      }
    }
    final monthlyRegistrations = monthlyRegMap.entries
        .map((e) => TimeSeriesPoint(e.key, e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // ── Peak registration hours ─────────────────────────────────────────────
    final regHourCounts = <int, int>{};
    for (final r in allRegs) {
      final registeredAt = r['registeredAt'] as DateTime?;
      if (registeredAt == null) continue;
      final h = registeredAt.hour;
      regHourCounts[h] = (regHourCounts[h] ?? 0) + 1;
    }
    final peakRegistrationHours =
        List.generate(24, (i) => HourSlotCount(i, regHourCounts[i] ?? 0));

    // ── Repeat / unique attendees ───────────────────────────────────────────
    final attendeeCounts = <String, int>{};
    for (final r in allRegs) {
      final attendeeId = r['attendeeId'] as String;
      attendeeCounts[attendeeId] = (attendeeCounts[attendeeId] ?? 0) + 1;
    }
    final repeatAttendees =
        attendeeCounts.values.where((c) => c > 1).length;
    final uniqueAttendees = attendeeCounts.length;

    // ── Revenue estimate — from related bookings ─────────────────────────────
    final myEventIds = myEvents.map((e) => e['id'] as String).toSet();
    double revenueEstimate = 0.0;
    final venueAcc = <String, _VenueEffAcc>{};

    for (final b in auth.allBookings) {
      final eid = b['eventId'] as String? ?? '';
      final orgId = b['organizerId'] as String? ?? '';
      if (!myEventIds.contains(eid) || orgId != organizerId) continue;
      final status = b['status'] as String? ?? '';
      if (status == 'confirmed') {
        final rev = (b['revenue'] as num?)?.toDouble() ?? 0.0;
        revenueEstimate += rev;

        final bName = b['buildingName'] as String? ?? 'Unknown';
        venueAcc.putIfAbsent(bName, () => _VenueEffAcc(bName));
        venueAcc[bName]!.bookingCount++;
        venueAcc[bName]!.revenue += rev;
      }
    }

    final venueEfficiency = venueAcc.values
        .map((v) => VenueEfficiencyEntry(
              buildingName: v.buildingName,
              bookingCount: v.bookingCount,
              totalRevenuePaid: v.revenue,
            ))
        .toList()
      ..sort((a, b) => b.bookingCount.compareTo(a.bookingCount));

    final published =
        myEvents.where((e) => e['status'] == 'published').length;
    final draft = myEvents.where((e) => e['status'] == 'draft').length;
    final completed =
        performances.where((p) => p.status == 'completed').length;

    final overallFillRate = totalExpected > 0
        ? (totalRegistrations / totalExpected * 100).clamp(0.0, 100.0)
        : 0.0;
    final overallAttendanceRate = totalRegistrations > 0
        ? (totalAttended / totalRegistrations * 100).clamp(0.0, 100.0)
        : 0.0;

    return OrganizerAnalyticsSnapshot(
      totalEvents: myEvents.length,
      publishedEvents: published,
      draftEvents: draft,
      completedEvents: completed,
      totalRegistrations: totalRegistrations,
      totalAttended: totalAttended,
      overallFillRate: overallFillRate,
      overallAttendanceRate: overallAttendanceRate,
      overallNoShowRate:
          (100 - overallAttendanceRate).clamp(0.0, 100.0),
      eventPerformances: performances,
      categoryBreakdown: categoryBreakdown,
      registrationVelocity: registrationVelocity,
      repeatAttendees: repeatAttendees,
      uniqueAttendees: uniqueAttendees,
      peakRegistrationHours: peakRegistrationHours,
      monthlyRegistrations: monthlyRegistrations,
      revenueEstimate: revenueEstimate,
      venueEfficiency: venueEfficiency.take(5).toList(),
    );
  }

  // ── Attendee Analytics Snapshot ────────────────────────────────────────────

  static AttendeeAnalyticsSnapshot computeForAttendee(String userId) {
    final cached = _hit(_attendeeCache[userId]);
    if (cached != null) return cached;

    final result = _computeAttendee(userId);
    _attendeeCache[userId] = _CacheEntry(result);
    return result;
  }

  static AttendeeAnalyticsSnapshot _computeAttendee(String userId) {
    final auth = AuthService();
    final reg = RegistrationService();

    final regs = reg.registrationsForAttendee(userId);
    if (regs.isEmpty) return AttendeeAnalyticsSnapshot.empty();

    final now = DateTime.now();

    // Map registrations to events
    final allPublished = auth.allEvents
        .where((e) => e['status'] == 'published')
        .toList();
    final eventMap = <String, Map<String, dynamic>>{
      for (final e in allPublished) e['id'] as String: e,
    };

    // Attended events sorted by start date
    final attendedEvents = <DateTime>[];
    final categoryDist = <String, int>{};
    int attended = 0;

    for (final r in regs) {
      final eid = r['eventId'] as String? ?? '';
      final ev = eventMap[eid];
      if (ev == null) continue;

      final cat = ev['category'] as String? ?? 'General';
      categoryDist[cat] = (categoryDist[cat] ?? 0) + 1;

      if (r['attended'] == true) {
        attended++;
        final start = ev['start'];
        if (start is DateTime && start.isBefore(now)) {
          attendedEvents.add(start);
        }
      }
    }

    attendedEvents.sort();

    // Attendance streak (consecutive months with at least one attended event)
    int currentStreak = 0;
    int bestStreak = 0;
    if (attendedEvents.isNotEmpty) {
      currentStreak = _computeStreak(attendedEvents, now);
      bestStreak = _computeBestStreak(attendedEvents);
    }

    // Diversity score: unique categories attended / total known categories
    const totalKnownCategories = 10;
    final uniqueCats = categoryDist.keys.length;
    final diversityScore =
        (uniqueCats / totalKnownCategories).clamp(0.0, 1.0);

    // Monthly activity — last 6 months
    final monthlyMap = <DateTime, double>{};
    for (var i = 5; i >= 0; i--) {
      monthlyMap[_monthStart(now.month - i, now.year)] = 0;
    }
    for (final r in regs) {
      final registeredAt = r['registeredAt'] as DateTime?;
      if (registeredAt == null) continue;
      final ms = DateTime(registeredAt.year, registeredAt.month);
      if (monthlyMap.containsKey(ms)) {
        monthlyMap[ms] = monthlyMap[ms]! + 1;
      }
    }
    final monthlyActivity = monthlyMap.entries
        .map((e) => TimeSeriesPoint(e.key, e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final attendanceRate = regs.isNotEmpty
        ? (attended / regs.length * 100).clamp(0.0, 100.0)
        : 0.0;

    final snap = AttendeeAnalyticsSnapshot(
      totalRegistered: regs.length,
      totalAttended: attended,
      attendanceRate: attendanceRate,
      uniqueCategories: uniqueCats,
      diversityScore: diversityScore,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      categoryDistribution: categoryDist,
      monthlyActivity: monthlyActivity,
    );

    _attendeeCache[userId] = _CacheEntry(snap);
    return snap;
  }

  // ── Platform-wide Admin Snapshot ──────────────────────────────────────────

  static AdminAnalyticsSnapshot computePlatformWide() {
    final cached = _hit(_adminCache);
    if (cached != null) return cached;

    final result = _computePlatformWide();
    _adminCache = _CacheEntry(result);
    return result;
  }

  static AdminAnalyticsSnapshot _computePlatformWide() {
    final auth = AuthService();
    final reg = RegistrationService();

    final allUsers = auth.allUsers;
    final allEvents = auth.allEvents;
    final allBookings = auth.allBookings;
    final allRegs = reg.all;

    final organizers =
        allUsers.where((u) => u.role == UserRole.organizer).toList();
    final venueOwners =
        allUsers.where((u) => u.role == UserRole.staff).toList();
    final attendees =
        allUsers.where((u) => u.role == UserRole.attendee).toList();

    final now = DateTime.now();

    final confirmed =
        allBookings.where((b) => b['status'] == 'confirmed').length;
    final pending =
        allBookings.where((b) => b['status'] == 'pending').length;
    final cancelled =
        allBookings.where((b) => b['status'] == 'cancelled').length;

    final convRate = allBookings.isNotEmpty
        ? (confirmed / allBookings.length * 100).clamp(0.0, 100.0)
        : 0.0;

    final published =
        allEvents.where((e) => e['status'] == 'published').length;
    final draft = allEvents.where((e) => e['status'] == 'draft').length;
    final completedEvts = allEvents.where((e) {
      final end = e['end'];
      return end is DateTime &&
          end.isBefore(now) &&
          e['status'] == 'published';
    }).length;

    final avgRegsPerEvent =
        allEvents.isNotEmpty ? allRegs.length / allEvents.length : 0.0;

    // ── Top organizers leaderboard ──────────────────────────────────────────
    final orgLeaderMap = <String, _OrgLeaderAcc>{};
    for (final u in organizers) {
      final myEvts = allEvents.where((e) => e['organizerId'] == u.id).toList();
      int totalRegs = 0;
      int totalExp = 0;
      for (final e in myEvts) {
        totalRegs += reg.countForEvent(e['id'] as String);
        totalExp += (e['expectedAttendees'] as int?) ?? 0;
      }
      orgLeaderMap[u.id] = _OrgLeaderAcc(
        organizerId: u.id,
        name: u.fullName,
        eventCount: myEvts.length,
        totalRegistrations: totalRegs,
        totalExpected: totalExp,
      );
    }
    final topOrganizers = orgLeaderMap.values
        .map((a) => OrganizerLeaderEntry(
              organizerId: a.organizerId,
              name: a.name,
              eventCount: a.eventCount,
              totalRegistrations: a.totalRegistrations,
              avgFillRate: a.totalExpected > 0
                  ? (a.totalRegistrations / a.totalExpected * 100)
                      .clamp(0.0, 100.0)
                  : 0.0,
            ))
        .toList()
      ..sort(
          (a, b) => b.totalRegistrations.compareTo(a.totalRegistrations));

    // ── Top venues leaderboard ──────────────────────────────────────────────
    final venueLeaderMap = <String, _VenueLeaderAcc>{};
    for (final u in venueOwners) {
      final snap = AnalyticsService.compute(u.id);
      venueLeaderMap[u.id] = _VenueLeaderAcc(
        ownerId: u.id,
        ownerName: u.fullName,
        bookingCount: snap.confirmedBookings,
        totalRevenue: snap.totalRevenue,
      );
    }
    final topVenues = venueLeaderMap.values
        .map((a) => VenueLeaderEntry(
              ownerId: a.ownerId,
              ownerName: a.ownerName,
              bookingCount: a.bookingCount,
              totalRevenue: a.totalRevenue,
            ))
        .toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    // ── Monthly bookings & registrations (last 6 months) ────────────────────
    final monthlyBk = <DateTime, double>{};
    final monthlyReg = <DateTime, double>{};
    for (var i = 5; i >= 0; i--) {
      final m = _monthStart(now.month - i, now.year);
      monthlyBk[m] = 0;
      monthlyReg[m] = 0;
    }
    for (final b in allBookings) {
      final createdAt = b['createdAt'];
      if (createdAt is DateTime) {
        final ms = DateTime(createdAt.year, createdAt.month);
        if (monthlyBk.containsKey(ms)) monthlyBk[ms] = monthlyBk[ms]! + 1;
      }
    }
    for (final r in allRegs) {
      final registeredAt = r['registeredAt'] as DateTime?;
      if (registeredAt == null) continue;
      final ms = DateTime(registeredAt.year, registeredAt.month);
      if (monthlyReg.containsKey(ms)) monthlyReg[ms] = monthlyReg[ms]! + 1;
    }
    final monthlyBookings = monthlyBk.entries
        .map((e) => TimeSeriesPoint(e.key, e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final monthlyRegistrations = monthlyReg.entries
        .map((e) => TimeSeriesPoint(e.key, e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // ── Events by category ──────────────────────────────────────────────────
    final catMap = <String, int>{};
    for (final e in allEvents) {
      final cat = (e['category'] as String?) ?? 'General';
      catMap[cat] = (catMap[cat] ?? 0) + 1;
    }

    // ── User growth trend (simulated from seed data — last 6 months) ────────
    final userGrowthMap = <DateTime, double>{};
    for (var i = 5; i >= 0; i--) {
      userGrowthMap[_monthStart(now.month - i, now.year)] = 0;
    }
    // Distribute users evenly across months as a baseline indicator
    final usersPerMonth = allUsers.length / 6;
    var cum = 0.0;
    for (final key in userGrowthMap.keys.toList()..sort()) {
      cum += usersPerMonth;
      userGrowthMap[key] = cum;
    }
    final userGrowthTrend = userGrowthMap.entries
        .map((e) => TimeSeriesPoint(e.key, e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // ── System utilisation rate ─────────────────────────────────────────────
    // Ratio of confirmed bookings to total possible bookings (all rooms × 30d)
    final venue = VenueService();
    int totalRooms = 0;
    for (final u in venueOwners) {
      for (final b in venue.buildingsForOwner(u.id)) {
        totalRooms += venue.roomsForBuilding(b.id).length;
      }
    }
    final totalCapacityBookings = totalRooms * 20; // ~20 bookings per room/month
    final systemUtilizationRate = totalCapacityBookings > 0
        ? (confirmed / totalCapacityBookings * 100).clamp(0.0, 100.0)
        : 0.0;

    // ── Operational bottlenecks ─────────────────────────────────────────────
    final bottlenecks = <BottleneckIndicator>[];

    if (allBookings.isNotEmpty) {
      final pendingRate = pending / allBookings.length * 100;
      if (pendingRate > 40) {
        bottlenecks.add(BottleneckIndicator(
          title: 'High pending booking rate',
          description:
              '${pendingRate.toStringAsFixed(0)}% of bookings are still pending. '
              'Venue owners may need to improve approval response times.',
          severity: 'high',
        ));
      } else if (pendingRate > 20) {
        bottlenecks.add(BottleneckIndicator(
          title: 'Elevated pending bookings',
          description:
              '${pendingRate.toStringAsFixed(0)}% of bookings are pending — above the 20% target.',
          severity: 'medium',
        ));
      }

      final cancelRate = cancelled / allBookings.length * 100;
      if (cancelRate > 30) {
        bottlenecks.add(BottleneckIndicator(
          title: 'High cancellation rate',
          description:
              '${cancelRate.toStringAsFixed(0)}% of bookings are cancelled. '
              'Consider reviewing cancellation policies and event planning quality.',
          severity: 'high',
        ));
      }
    }

    if (allEvents.isNotEmpty) {
      final draftRate = draft / allEvents.length * 100;
      if (draftRate > 50) {
        bottlenecks.add(BottleneckIndicator(
          title: 'Many unpublished events',
          description:
              '${draftRate.toStringAsFixed(0)}% of events remain in draft. '
              'Organisers may need assistance completing event setup.',
          severity: 'medium',
        ));
      }
    }

    if (avgRegsPerEvent < 3 && allEvents.isNotEmpty) {
      bottlenecks.add(BottleneckIndicator(
        title: 'Low average registrations per event',
        description:
            'Average of ${avgRegsPerEvent.toStringAsFixed(1)} registrations per event. '
            'Consider promotional tools to drive attendee engagement.',
        severity: 'medium',
      ));
    }

    // ── Risk indicators ─────────────────────────────────────────────────────
    final riskIndicators = <PlatformRiskIndicator>[];

    if (organizers.isNotEmpty) {
      final activeOrgs = orgLeaderMap.values
          .where((o) => o.totalRegistrations > 0)
          .length;
      if (activeOrgs < organizers.length * 0.5) {
        riskIndicators.add(PlatformRiskIndicator(
          title: 'Organiser churn risk',
          description:
              'Only $activeOrgs of ${organizers.length} organisers have active registrations. '
              '${organizers.length - activeOrgs} may be disengaged.',
        ));
      }
    }

    if (venueOwners.isNotEmpty) {
      final activeVenues =
          venueLeaderMap.values.where((v) => v.bookingCount > 0).length;
      if (activeVenues < venueOwners.length * 0.6) {
        riskIndicators.add(PlatformRiskIndicator(
          title: 'Underperforming venues',
          description:
              '$activeVenues of ${venueOwners.length} venue owners have confirmed bookings. '
              '${venueOwners.length - activeVenues} venue owners have no activity.',
        ));
      }
    }

    if (attendees.isNotEmpty && allRegs.isEmpty) {
      riskIndicators.add(PlatformRiskIndicator(
        title: 'No attendee engagement',
        description:
            'No attendee registrations recorded. Platform may lack visibility with end users.',
      ));
    }

    return AdminAnalyticsSnapshot(
      totalUsers: allUsers.length,
      organizers: organizers.length,
      venueOwners: venueOwners.length,
      attendees: attendees.length,
      totalEvents: allEvents.length,
      publishedEvents: published,
      draftEvents: draft,
      completedEvents: completedEvts,
      totalBookings: allBookings.length,
      confirmedBookings: confirmed,
      pendingBookings: pending,
      cancelledBookings: cancelled,
      totalRegistrations: allRegs.length,
      bookingConversionRate: convRate,
      avgRegistrationsPerEvent: avgRegsPerEvent,
      topOrganizers: topOrganizers.take(5).toList(),
      topVenues: topVenues.take(5).toList(),
      monthlyBookings: monthlyBookings,
      monthlyRegistrations: monthlyRegistrations,
      eventsByCategory: catMap,
      bottlenecks: bottlenecks,
      riskIndicators: riskIndicators,
      userGrowthTrend: userGrowthTrend,
      systemUtilizationRate: systemUtilizationRate,
    );
  }

  // ── Streak helpers ─────────────────────────────────────────────────────────

  static int _computeStreak(List<DateTime> sorted, DateTime now) {
    if (sorted.isEmpty) return 0;
    int streak = 0;
    DateTime cursor = now;
    for (var i = sorted.length - 1; i >= 0; i--) {
      final diff = cursor.difference(sorted[i]).inDays;
      if (diff <= 45) {
        streak++;
        cursor = sorted[i];
      } else {
        break;
      }
    }
    return streak;
  }

  static int _computeBestStreak(List<DateTime> sorted) {
    if (sorted.isEmpty) return 0;
    int best = 1;
    int current = 1;
    for (var i = 1; i < sorted.length; i++) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff <= 45) {
        current++;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }
    return best;
  }

  // ── Common helpers ─────────────────────────────────────────────────────────

  static String _computeEventStatus(Map<String, dynamic> e, DateTime now) {
    final status = e['status'] as String? ?? 'draft';
    if (status == 'draft') return 'draft';
    final start = e['start'] as DateTime?;
    final end = e['end'] as DateTime?;
    if (start == null || end == null) return status;
    if (now.isAfter(end)) return 'completed';
    if (now.isAfter(start) && now.isBefore(end)) return 'ongoing';
    return 'upcoming';
  }

  static DateTime _startOfWeek(DateTime d) {
    final diff = d.weekday - 1;
    return DateTime(d.year, d.month, d.day - diff);
  }

  static DateTime _monthStart(int month, int year) {
    var m = month;
    var y = year;
    while (m <= 0) {
      m += 12;
      y--;
    }
    while (m > 12) {
      m -= 12;
      y++;
    }
    return DateTime(y, m);
  }
}

// ── Cache entry ────────────────────────────────────────────────────────────

class _CacheEntry<T> {
  final T value;
  final DateTime timestamp;
  _CacheEntry(this.value) : timestamp = DateTime.now();
}

// ── Private accumulators ──────────────────────────────────────────────────

class _RoomAccumulator {
  final String roomId;
  final String roomName;
  final String buildingName;
  int bookingCount = 0;
  double revenue = 0;
  _RoomAccumulator({
    required this.roomId,
    required this.roomName,
    required this.buildingName,
  });
}

class _BuildingAccumulator {
  final String buildingId;
  final String buildingName;
  double revenue = 0;
  int bookingCount = 0;
  _BuildingAccumulator({
    required this.buildingId,
    required this.buildingName,
  });
}

class _OrgAccumulator {
  final String organizerId;
  final String name;
  int bookingCount = 0;
  double totalSpend = 0;
  _OrgAccumulator({required this.organizerId, required this.name});
}

class _CatAccumulator {
  final String category;
  int eventCount = 0;
  int totalRegistrations = 0;
  int totalAttendees = 0;
  int totalExpected = 0;
  _CatAccumulator(this.category);
}

class _OrgLeaderAcc {
  final String organizerId;
  final String name;
  final int eventCount;
  final int totalRegistrations;
  final int totalExpected;
  _OrgLeaderAcc({
    required this.organizerId,
    required this.name,
    required this.eventCount,
    required this.totalRegistrations,
    required this.totalExpected,
  });
}

class _VenueLeaderAcc {
  final String ownerId;
  final String ownerName;
  final int bookingCount;
  final double totalRevenue;
  _VenueLeaderAcc({
    required this.ownerId,
    required this.ownerName,
    required this.bookingCount,
    required this.totalRevenue,
  });
}

class _VenueEffAcc {
  final String buildingName;
  int bookingCount = 0;
  double revenue = 0;
  _VenueEffAcc(this.buildingName);
}
