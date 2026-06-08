import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'booking_filters_state.dart';

@injectable
class BookingFiltersCubit extends Cubit<BookingFiltersState> {
  BookingFiltersCubit() : super(const BookingFiltersState());

  void updateSearch(String value) {
    emit(state.copyWith(searchQuery: value));
  }

  void updateRange(BookingRangeFilter range) {
    emit(state.copyWith(range: range));
  }

  void updateStaff(String? staffId) {
    emit(state.copyWith(staffId: staffId));
  }
}
