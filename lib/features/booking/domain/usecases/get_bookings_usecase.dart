import 'package:injectable/injectable.dart';

import '../entities/booking.dart';
import '../repositories/booking_repository.dart';

@injectable
class GetBookingsUseCase {
  const GetBookingsUseCase(this._repository);

  final BookingRepository _repository;

  Future<List<Booking>> call() => _repository.getBookings();
}
