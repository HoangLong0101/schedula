import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/booking_status.dart';
import '../../domain/usecases/create_booking_usecase.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../cubit/booking_form_cubit.dart';
import '../cubit/booking_form_state.dart';

class BookingFormSheet {
  static Future<void> show(
    BuildContext context, {
    required String tenantId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return BlocProvider(
          create: (_) => BookingFormCubit(),
          child: _BookingFormContent(tenantId: tenantId),
        );
      },
    );
  }
}

class _BookingFormContent extends StatelessWidget {
  const _BookingFormContent({required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 8,
      ),
      child: BlocBuilder<BookingFormCubit, BookingFormState>(
        builder: (context, state) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New booking',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Customer ID'),
                onChanged: context.read<BookingFormCubit>().updateCustomerId,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Staff ID'),
                onChanged: context.read<BookingFormCubit>().updateStaffId,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Service ID'),
                onChanged: context.read<BookingFormCubit>().updateServiceId,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DatePickerField(
                      label: 'Date',
                      value: state.date,
                      onPicked: context.read<BookingFormCubit>().updateDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimePickerField(
                      label: 'Start',
                      value: state.startTime,
                      onPicked: context.read<BookingFormCubit>().updateStartTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _TimePickerField(
                label: 'End',
                value: state.endTime,
                onPicked: context.read<BookingFormCubit>().updateEndTime,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                onChanged: context.read<BookingFormCubit>().updateNotes,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isValid
                      ? () => _submit(context, state)
                      : null,
                  child: const Text('Create booking'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  void _submit(BuildContext context, BookingFormState state) {
    final start = state.startDateTime;
    final end = state.endDateTime;
    if (start == null || end == null) {
      return;
    }

    context.read<BookingBloc>().add(
          BookingCreateRequested(
            CreateBookingParams(
              tenantId: tenantId,
              staffId: state.staffId,
              customerId: state.customerId,
              serviceId: state.serviceId,
              startTime: start,
              endTime: end,
              status: BookingStatus.confirmed,
              notes: state.notes.isEmpty ? null : state.notes,
            ),
          ),
        );
    Navigator.of(context).pop();
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onPicked,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? label
        : '${value!.day}/${value!.month}/${value!.year}';
    return OutlinedButton(
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 1),
        );
        if (!context.mounted) return;
        if (picked != null) {
          onPicked(picked);
        }
      },
      child: Text(text),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onPicked,
  });

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onPicked;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? label : value!.format(context);
    return OutlinedButton(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value ?? TimeOfDay.now(),
        );
        if (!context.mounted) return;
        if (picked != null) {
          onPicked(picked);
        }
      },
      child: Text(text),
    );
  }
}
