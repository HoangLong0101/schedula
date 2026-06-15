import 'package:flutter/material.dart';

class BookingSearchField extends StatelessWidget {
  const BookingSearchField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: 'Tìm kiếm lịch hẹn',
        prefixIcon: Icon(Icons.search),
      ),
      textInputAction: TextInputAction.search,
    );
  }
}
