import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_status.dart';

BookingStatus nextStatusFor(Booking booking) {
  switch (booking.status) {
    case BookingStatus.pending:
      return BookingStatus.confirmed;
    case BookingStatus.confirmed:
      return BookingStatus.inProgress;
    case BookingStatus.inProgress:
      return BookingStatus.completed;
    case BookingStatus.completed:
      return BookingStatus.completed;
    case BookingStatus.cancelled:
      return BookingStatus.cancelled;
    case BookingStatus.noShow:
      return BookingStatus.noShow;
  }
}
