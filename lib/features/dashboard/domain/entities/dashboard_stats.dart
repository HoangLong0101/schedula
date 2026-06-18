import 'package:equatable/equatable.dart';

/// A coarse time-of-day bucket used to build the booking heatmap.
enum BookingPeriod { morning, afternoon, evening }

/// One cell of the bookings heatmap: how many bookings started on
/// [weekday] (1 = Monday ... 7 = Sunday, see [DateTime.weekday]) during
/// [period].
class BookingHeatmapCell extends Equatable {
  const BookingHeatmapCell({
    required this.weekday,
    required this.period,
    required this.count,
  });

  final int weekday;
  final BookingPeriod period;
  final int count;

  @override
  List<Object?> get props => [weekday, period, count];
}

/// The number of bookings that started on a given [date] (time component
/// truncated to midnight), used to plot the daily bookings trend chart.
class BookingTrendPoint extends Equatable {
  const BookingTrendPoint({required this.date, required this.count});

  final DateTime date;
  final int count;

  @override
  List<Object?> get props => [date, count];
}

/// A booking scheduled to start today, shown in the dashboard's
/// "Lịch hẹn hôm nay" section.
class DashboardAppointment extends Equatable {
  const DashboardAppointment({
    required this.id,
    required this.customerName,
    required this.staffName,
    required this.serviceName,
    required this.startTime,
  });

  final String id;
  final String customerName;
  final String staffName;
  final String serviceName;
  final DateTime startTime;

  @override
  List<Object?> get props => [
    id,
    customerName,
    staffName,
    serviceName,
    startTime,
  ];
}

/// A staff member with a live availability status derived from whether
/// they currently have an in-progress booking.
class StaffAvailability extends Equatable {
  const StaffAvailability({
    required this.id,
    required this.name,
    required this.inSession,
    required this.bookingCount,
  });

  final String id;
  final String name;
  final bool inSession;
  final int bookingCount;

  @override
  List<Object?> get props => [id, name, inSession, bookingCount];
}

/// Aggregate counts for the tenant's customer base, used by the
/// "Quản lý khách hàng" quick-access card.
class CustomerOverview extends Equatable {
  const CustomerOverview({
    required this.totalCustomers,
    required this.returningCustomers,
    required this.needsFollowUpCustomers,
  });

  static const empty = CustomerOverview(
    totalCustomers: 0,
    returningCustomers: 0,
    needsFollowUpCustomers: 0,
  );

  final int totalCustomers;
  final int returningCustomers;
  final int needsFollowUpCustomers;

  @override
  List<Object?> get props => [
    totalCustomers,
    returningCustomers,
    needsFollowUpCustomers,
  ];
}

/// Owner-facing KPIs aggregated from the `bookings` collection for a tenant.
class DashboardStats extends Equatable {
  const DashboardStats({
    required this.totalBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.noShowBookings,
    required this.upcomingBookings,
    required this.totalRevenue,
    required this.hourlyBookingCounts,
    required this.heatmap,
    required this.dailyTrend,
    required this.todayAppointments,
    required this.staffAvailability,
    required this.customerOverview,
  });

  static const empty = DashboardStats(
    totalBookings: 0,
    completedBookings: 0,
    cancelledBookings: 0,
    noShowBookings: 0,
    upcomingBookings: 0,
    totalRevenue: 0,
    hourlyBookingCounts: [],
    heatmap: [],
    dailyTrend: [],
    todayAppointments: [],
    staffAvailability: [],
    customerOverview: CustomerOverview.empty,
  );

  final int totalBookings;
  final int completedBookings;
  final int cancelledBookings;
  final int noShowBookings;
  final int upcomingBookings;
  final int totalRevenue;
  final List<int> hourlyBookingCounts;
  final List<BookingHeatmapCell> heatmap;
  final List<BookingTrendPoint> dailyTrend;
  final List<DashboardAppointment> todayAppointments;
  final List<StaffAvailability> staffAvailability;
  final CustomerOverview customerOverview;

  double get cancellationRate =>
      totalBookings == 0 ? 0 : cancelledBookings / totalBookings;

  int get peakHeatmapCount =>
      heatmap.fold(0, (peak, cell) => cell.count > peak ? cell.count : peak);

  int get peakDailyTrendCount => dailyTrend.fold(
    0,
    (peak, point) => point.count > peak ? point.count : peak,
  );

  @override
  List<Object?> get props => [
    totalBookings,
    completedBookings,
    cancelledBookings,
    noShowBookings,
    upcomingBookings,
    totalRevenue,
    hourlyBookingCounts,
    heatmap,
    dailyTrend,
    todayAppointments,
    staffAvailability,
    customerOverview,
  ];
}
