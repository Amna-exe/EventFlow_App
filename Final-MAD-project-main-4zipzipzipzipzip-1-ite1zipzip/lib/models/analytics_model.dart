class TimeSeriesPoint {
  final DateTime date;
  final double value;
  const TimeSeriesPoint(this.date, this.value);
}

class RoomStats {
  final String roomId;
  final String roomName;
  final String buildingName;
  final int bookingCount;
  final double revenue;
  const RoomStats({
    required this.roomId,
    required this.roomName,
    required this.buildingName,
    required this.bookingCount,
    required this.revenue,
  });
}

class BuildingRevenue {
  final String buildingId;
  final String buildingName;
  final double revenue;
  final int bookingCount;
  const BuildingRevenue({
    required this.buildingId,
    required this.buildingName,
    required this.revenue,
    required this.bookingCount,
  });
}

class OrganizerStats {
  final String organizerId;
  final String name;
  final int bookingCount;
  final double totalSpend;
  const OrganizerStats({
    required this.organizerId,
    required this.name,
    required this.bookingCount,
    required this.totalSpend,
  });
}

class HourSlotCount {
  final int hour;
  final int count;
  const HourSlotCount(this.hour, this.count);
}

class DaySlotCount {
  final int weekday;
  final int count;
  const DaySlotCount(this.weekday, this.count);
}

// ── New: Underutilised Room ────────────────────────────────────────────────

class UnderutilizedRoom {
  final String roomId;
  final String roomName;
  final String buildingName;
  final int bookingCount;
  final double utilizationPct;
  const UnderutilizedRoom({
    required this.roomId,
    required this.roomName,
    required this.buildingName,
    required this.bookingCount,
    required this.utilizationPct,
  });
}

// ── New: Payment Breakdown ─────────────────────────────────────────────────

class PaymentBreakdown {
  final int paid;
  final int pending;
  final int refunded;
  final double paidRevenue;
  final double pendingRevenue;
  final double refundedRevenue;

  const PaymentBreakdown({
    this.paid = 0,
    this.pending = 0,
    this.refunded = 0,
    this.paidRevenue = 0,
    this.pendingRevenue = 0,
    this.refundedRevenue = 0,
  });

  static const empty = PaymentBreakdown();
}

// ── New: Venue Efficiency (Organiser view) ─────────────────────────────────

class VenueEfficiencyEntry {
  final String buildingName;
  final int bookingCount;
  final double totalRevenuePaid;
  const VenueEfficiencyEntry({
    required this.buildingName,
    required this.bookingCount,
    required this.totalRevenuePaid,
  });
}

// ── New: Operational Bottleneck ────────────────────────────────────────────

class BottleneckIndicator {
  final String title;
  final String description;
  final String severity; // 'high' | 'medium' | 'low'
  const BottleneckIndicator({
    required this.title,
    required this.description,
    required this.severity,
  });
}

// ── New: Platform Risk Indicator ───────────────────────────────────────────

class PlatformRiskIndicator {
  final String title;
  final String description;
  const PlatformRiskIndicator({
    required this.title,
    required this.description,
  });
}

// ── New: Attendee Analytics Snapshot ──────────────────────────────────────

class AttendeeAnalyticsSnapshot {
  final int totalRegistered;
  final int totalAttended;
  final double attendanceRate;
  final int uniqueCategories;
  final double diversityScore;
  final int currentStreak;
  final int bestStreak;
  final Map<String, int> categoryDistribution;
  final List<TimeSeriesPoint> monthlyActivity;

  const AttendeeAnalyticsSnapshot({
    required this.totalRegistered,
    required this.totalAttended,
    required this.attendanceRate,
    required this.uniqueCategories,
    required this.diversityScore,
    required this.currentStreak,
    required this.bestStreak,
    required this.categoryDistribution,
    required this.monthlyActivity,
  });

  static AttendeeAnalyticsSnapshot empty() => const AttendeeAnalyticsSnapshot(
        totalRegistered: 0,
        totalAttended: 0,
        attendanceRate: 0,
        uniqueCategories: 0,
        diversityScore: 0,
        currentStreak: 0,
        bestStreak: 0,
        categoryDistribution: {},
        monthlyActivity: [],
      );
}

// ── Venue Owner Snapshot ───────────────────────────────────────────────────

class AnalyticsSnapshot {
  final double totalRevenue;
  final double avgBookingValue;
  final double occupancyRate;
  final double cancellationRate;
  final int totalBookings;
  final int confirmedBookings;
  final int cancelledBookings;
  final int pendingBookings;

  final List<RoomStats> topRooms;
  final List<BuildingRevenue> revenueByBuilding;
  final List<OrganizerStats> topOrganizers;
  final List<OrganizerStats> repeatOrganizers;

  final List<TimeSeriesPoint> dailyBookings;
  final List<TimeSeriesPoint> weeklyRevenue;
  final List<TimeSeriesPoint> monthlyRevenue;
  final List<HourSlotCount> bookingsByHour;
  final List<DaySlotCount> bookingsByDay;

  // ── Extended fields ──────────────────────────────────────────────────────
  final List<UnderutilizedRoom> underutilizedRooms;
  final PaymentBreakdown paymentBreakdown;

  const AnalyticsSnapshot({
    required this.totalRevenue,
    required this.avgBookingValue,
    required this.occupancyRate,
    required this.cancellationRate,
    required this.totalBookings,
    required this.confirmedBookings,
    required this.cancelledBookings,
    required this.pendingBookings,
    required this.topRooms,
    required this.revenueByBuilding,
    required this.topOrganizers,
    required this.repeatOrganizers,
    required this.dailyBookings,
    required this.weeklyRevenue,
    required this.monthlyRevenue,
    required this.bookingsByHour,
    required this.bookingsByDay,
    this.underutilizedRooms = const [],
    this.paymentBreakdown = const PaymentBreakdown(),
  });

  static AnalyticsSnapshot empty() => const AnalyticsSnapshot(
        totalRevenue: 0,
        avgBookingValue: 0,
        occupancyRate: 0,
        cancellationRate: 0,
        totalBookings: 0,
        confirmedBookings: 0,
        cancelledBookings: 0,
        pendingBookings: 0,
        topRooms: [],
        revenueByBuilding: [],
        topOrganizers: [],
        repeatOrganizers: [],
        dailyBookings: [],
        weeklyRevenue: [],
        monthlyRevenue: [],
        bookingsByHour: [],
        bookingsByDay: [],
        underutilizedRooms: [],
        paymentBreakdown: PaymentBreakdown.empty,
      );
}

// ── Organiser Analytics ────────────────────────────────────────────────────

class CategoryStats {
  final String category;
  final int eventCount;
  final int totalRegistrations;
  final int totalAttendees;
  final double avgFillRate;
  const CategoryStats({
    required this.category,
    required this.eventCount,
    required this.totalRegistrations,
    required this.totalAttendees,
    required this.avgFillRate,
  });
}

class EventPerformance {
  final String eventId;
  final String title;
  final String category;
  final String status;
  final int registered;
  final int expected;
  final int attended;
  final double fillRate;
  final double attendanceRate;
  final DateTime? startDate;
  const EventPerformance({
    required this.eventId,
    required this.title,
    required this.category,
    required this.status,
    required this.registered,
    required this.expected,
    required this.attended,
    required this.fillRate,
    required this.attendanceRate,
    this.startDate,
  });
}

class OrganizerAnalyticsSnapshot {
  final int totalEvents;
  final int publishedEvents;
  final int draftEvents;
  final int completedEvents;
  final int totalRegistrations;
  final int totalAttended;
  final double overallFillRate;
  final double overallAttendanceRate;
  final double overallNoShowRate;
  final List<EventPerformance> eventPerformances;
  final List<CategoryStats> categoryBreakdown;
  final List<TimeSeriesPoint> registrationVelocity;
  final int repeatAttendees;
  final int uniqueAttendees;

  // ── Extended fields ──────────────────────────────────────────────────────
  final List<HourSlotCount> peakRegistrationHours;
  final List<TimeSeriesPoint> monthlyRegistrations;
  final double revenueEstimate;
  final List<VenueEfficiencyEntry> venueEfficiency;

  const OrganizerAnalyticsSnapshot({
    required this.totalEvents,
    required this.publishedEvents,
    required this.draftEvents,
    required this.completedEvents,
    required this.totalRegistrations,
    required this.totalAttended,
    required this.overallFillRate,
    required this.overallAttendanceRate,
    required this.overallNoShowRate,
    required this.eventPerformances,
    required this.categoryBreakdown,
    required this.registrationVelocity,
    required this.repeatAttendees,
    required this.uniqueAttendees,
    this.peakRegistrationHours = const [],
    this.monthlyRegistrations = const [],
    this.revenueEstimate = 0.0,
    this.venueEfficiency = const [],
  });

  static OrganizerAnalyticsSnapshot empty() =>
      const OrganizerAnalyticsSnapshot(
        totalEvents: 0,
        publishedEvents: 0,
        draftEvents: 0,
        completedEvents: 0,
        totalRegistrations: 0,
        totalAttended: 0,
        overallFillRate: 0,
        overallAttendanceRate: 0,
        overallNoShowRate: 0,
        eventPerformances: [],
        categoryBreakdown: [],
        registrationVelocity: [],
        repeatAttendees: 0,
        uniqueAttendees: 0,
      );
}

// ── Admin Analytics ────────────────────────────────────────────────────────

class OrganizerLeaderEntry {
  final String organizerId;
  final String name;
  final int eventCount;
  final int totalRegistrations;
  final double avgFillRate;
  const OrganizerLeaderEntry({
    required this.organizerId,
    required this.name,
    required this.eventCount,
    required this.totalRegistrations,
    required this.avgFillRate,
  });
}

class VenueLeaderEntry {
  final String ownerId;
  final String ownerName;
  final int bookingCount;
  final double totalRevenue;
  const VenueLeaderEntry({
    required this.ownerId,
    required this.ownerName,
    required this.bookingCount,
    required this.totalRevenue,
  });
}

class AdminAnalyticsSnapshot {
  final int totalUsers;
  final int organizers;
  final int venueOwners;
  final int attendees;
  final int totalEvents;
  final int publishedEvents;
  final int draftEvents;
  final int completedEvents;
  final int totalBookings;
  final int confirmedBookings;
  final int pendingBookings;
  final int cancelledBookings;
  final int totalRegistrations;
  final double bookingConversionRate;
  final double avgRegistrationsPerEvent;
  final List<OrganizerLeaderEntry> topOrganizers;
  final List<VenueLeaderEntry> topVenues;
  final List<TimeSeriesPoint> monthlyBookings;
  final List<TimeSeriesPoint> monthlyRegistrations;
  final Map<String, int> eventsByCategory;

  // ── Extended fields ──────────────────────────────────────────────────────
  final List<BottleneckIndicator> bottlenecks;
  final List<PlatformRiskIndicator> riskIndicators;
  final List<TimeSeriesPoint> userGrowthTrend;
  final double systemUtilizationRate;

  const AdminAnalyticsSnapshot({
    required this.totalUsers,
    required this.organizers,
    required this.venueOwners,
    required this.attendees,
    required this.totalEvents,
    required this.publishedEvents,
    required this.draftEvents,
    required this.completedEvents,
    required this.totalBookings,
    required this.confirmedBookings,
    required this.pendingBookings,
    required this.cancelledBookings,
    required this.totalRegistrations,
    required this.bookingConversionRate,
    required this.avgRegistrationsPerEvent,
    required this.topOrganizers,
    required this.topVenues,
    required this.monthlyBookings,
    required this.monthlyRegistrations,
    required this.eventsByCategory,
    this.bottlenecks = const [],
    this.riskIndicators = const [],
    this.userGrowthTrend = const [],
    this.systemUtilizationRate = 0.0,
  });

  static AdminAnalyticsSnapshot empty() => const AdminAnalyticsSnapshot(
        totalUsers: 0,
        organizers: 0,
        venueOwners: 0,
        attendees: 0,
        totalEvents: 0,
        publishedEvents: 0,
        draftEvents: 0,
        completedEvents: 0,
        totalBookings: 0,
        confirmedBookings: 0,
        pendingBookings: 0,
        cancelledBookings: 0,
        totalRegistrations: 0,
        bookingConversionRate: 0,
        avgRegistrationsPerEvent: 0,
        topOrganizers: [],
        topVenues: [],
        monthlyBookings: [],
        monthlyRegistrations: [],
        eventsByCategory: <String, int>{},
      );
}
