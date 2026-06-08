import 'package:equatable/equatable.dart';

enum BookingRangeFilter { all, today, week }

class BookingFiltersState extends Equatable {
  const BookingFiltersState({
    this.searchQuery = '',
    this.range = BookingRangeFilter.all,
    this.staffId,
  });

  static const Object _keepStaffId = Object();

  final String searchQuery;
  final BookingRangeFilter range;
  final String? staffId;

  BookingFiltersState copyWith({
    String? searchQuery,
    BookingRangeFilter? range,
    Object? staffId = _keepStaffId,
  }) {
    return BookingFiltersState(
      searchQuery: searchQuery ?? this.searchQuery,
      range: range ?? this.range,
      staffId: staffId == _keepStaffId ? this.staffId : staffId as String?,
    );
  }

  @override
  List<Object?> get props => [searchQuery, range, staffId];
}
