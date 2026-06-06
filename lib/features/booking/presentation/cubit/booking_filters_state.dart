import 'package:equatable/equatable.dart';

enum BookingRangeFilter {
  all,
  today,
  week,
}

class BookingFiltersState extends Equatable {
  const BookingFiltersState({
    this.searchQuery = '',
    this.range = BookingRangeFilter.all,
    this.staffId,
  });

  final String searchQuery;
  final BookingRangeFilter range;
  final String? staffId;

  BookingFiltersState copyWith({
    String? searchQuery,
    BookingRangeFilter? range,
    String? staffId,
  }) {
    return BookingFiltersState(
      searchQuery: searchQuery ?? this.searchQuery,
      range: range ?? this.range,
      staffId: staffId ?? this.staffId,
    );
  }

  @override
  List<Object?> get props => [searchQuery, range, staffId];
}
