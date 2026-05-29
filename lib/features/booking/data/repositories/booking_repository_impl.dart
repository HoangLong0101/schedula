import 'package:injectable/injectable.dart';

import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_datasource.dart';
import '../datasources/booking_realtime_data_source.dart';
import '../models/booking_model.dart';

@LazySingleton(as: BookingRepository)
class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl(
    this._dataSource,
    this._realtimeDataSource,
  );

  final BookingDataSource _dataSource;
  final BookingRealtimeDataSource _realtimeDataSource;

  @override
  Future<List<Booking>> getBookings() async {
    final models = await _dataSource.fetchBookings();
    return models;
  }

  @override
  Stream<List<Booking>> watchBookings(String tenantId) {
    return _dataSource.watchBookings(tenantId);
  }

  @override
  Future<void> saveBooking(Booking booking) {
    return _dataSource.saveBooking(
      booking is BookingModel
          ? booking
          : BookingModel(id: booking.id, title: booking.title),
    );
  }

  @override
  Future<void> deleteBooking(String bookingId) {
    return _dataSource.deleteBooking(bookingId);
  }

  Future<void> setTenantLive(String tenantId, bool live) {
    return _realtimeDataSource.setTenantLive(
      tenantId: tenantId,
      live: live,
    );
  }
}
