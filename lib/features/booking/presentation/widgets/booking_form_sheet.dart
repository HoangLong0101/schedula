import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/booking_status.dart';
import '../../domain/usecases/create_booking_usecase.dart';
import '../../domain/usecases/scan_appointment_image_usecase.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../cubit/booking_form_cubit.dart';
import '../cubit/booking_form_state.dart';

class BookingFormSheet {
  static Future<void> show(BuildContext context, {required String tenantId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BlocProvider(
          create: (_) =>
              BookingFormCubit(getIt<ScanAppointmentImageUseCase>()),
          child: _BookingFormContent(tenantId: tenantId),
        );
      },
    );
  }
}

class _BookingFormContent extends StatefulWidget {
  const _BookingFormContent({required this.tenantId});

  final String tenantId;

  @override
  State<_BookingFormContent> createState() => _BookingFormContentState();
}

class _BookingFormContentState extends State<_BookingFormContent> {
  final _lookupController = TextEditingController();
  final _customerNameController = TextEditingController();

  @override
  void dispose() {
    _lookupController.dispose();
    _customerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 24),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: BlocConsumer<BookingFormCubit, BookingFormState>(
          listenWhen: (previous, current) =>
              previous.extraction != current.extraction &&
              current.extraction != null,
          listener: (context, state) {
            // Reflect AI-extracted values in the editable text fields.
            _lookupController.text = state.customerLookup;
            _customerNameController.text = state.customerName;
          },
          builder: (context, state) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                MediaQuery.viewInsetsOf(context).bottom + 26,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4B5563),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Thêm lịch hẹn mới',
                          style: TextStyle(
                            color: _Tokens.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _CloseButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _ModeSwitcher(
                    aiMode: state.aiMode,
                    onManual: () => context.read<BookingFormCubit>().updateMode(
                      aiMode: false,
                    ),
                    onAi: () => context.read<BookingFormCubit>().updateMode(
                      aiMode: true,
                    ),
                  ),
                  if (state.aiMode) ...[
                    const SizedBox(height: 16),
                    _AiScanPanel(
                      scanning: state.aiScanning,
                      error: state.aiError,
                      scanned: state.extraction != null,
                      onPick: (source) => _pickAndScan(context, source),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const _SectionLabel('Khách hàng'),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _lookupController,
                    hintText: 'Nhập SĐT hoặc tìm khách có sẵn...',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    onChanged: context
                        .read<BookingFormCubit>()
                        .updateCustomerLookup,
                  ),
                  const SizedBox(height: 16),
                  const _SectionLabel('Tên khách hàng'),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _customerNameController,
                    hintText: 'Nhập tên khách hàng',
                    icon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    onChanged: context
                        .read<BookingFormCubit>()
                        .updateCustomerName,
                  ),
                  const SizedBox(height: 16),
                  const _SectionLabel('Nhân viên phụ trách'),
                  const SizedBox(height: 8),
                  _InputField(
                    hintText: 'Chọn nhân viên',
                    icon: Icons.medical_services_outlined,
                    textInputAction: TextInputAction.next,
                    onChanged: context.read<BookingFormCubit>().updateStaffName,
                  ),
                  const SizedBox(height: 16),
                  const _SectionLabel('Dịch vụ'),
                  const SizedBox(height: 8),
                  _InputField(
                    hintText: 'Chọn dịch vụ',
                    icon: Icons.spa_outlined,
                    textInputAction: TextInputAction.next,
                    onChanged: context
                        .read<BookingFormCubit>()
                        .updateServiceName,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerGroup(
                          label: 'Ngày',
                          child: _DatePickerField(
                            value: state.date,
                            onPicked: context
                                .read<BookingFormCubit>()
                                .updateDate,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PickerGroup(
                          label: 'Giờ',
                          child: _TimePickerField(
                            value: state.startTime,
                            onPicked: context
                                .read<BookingFormCubit>()
                                .updateStartTime,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PickerGroup(
                    label: 'Kết thúc',
                    child: _TimePickerField(
                      value: state.endTime,
                      onPicked: context.read<BookingFormCubit>().updateEndTime,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SectionLabel('Ghi chú'),
                  const SizedBox(height: 8),
                  _InputField(
                    hintText: 'Ghi chú thêm (tùy chọn)',
                    icon: Icons.notes_outlined,
                    minLines: 2,
                    maxLines: 3,
                    onChanged: context.read<BookingFormCubit>().updateNotes,
                  ),
                  const SizedBox(height: 24),
                  _SubmitButton(
                    enabled: state.isValid,
                    onPressed: () => _submit(context, state),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickAndScan(BuildContext context, ImageSource source) async {
    final cubit = context.read<BookingFormCubit>();
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) {
      return;
    }
    await cubit.scanImage(picked.path);
  }

  void _submit(BuildContext context, BookingFormState state) {
    if (!state.isValid) {
      return;
    }

    final customerName = state.customerName.trim();
    final staffName = state.staffName.trim();
    final serviceName = state.serviceName.trim();
    final lookup = state.customerLookup.trim();

    context.read<BookingBloc>().add(
      BookingCreateRequested(
        CreateBookingParams(
          tenantId: widget.tenantId,
          staffId: _stableId('staff', staffName),
          customerId: lookup.isNotEmpty
              ? _stableId('customer', lookup)
              : _stableId('customer', customerName),
          serviceId: _stableId('service', serviceName),
          startTime: state.startDateTime,
          endTime: state.endDateTime,
          status: BookingStatus.confirmed,
          notes: state.notes.trim().isEmpty ? null : state.notes.trim(),
          customerName: customerName,
          staffName: staffName,
          serviceName: serviceName,
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  String _stableId(String prefix, String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    if (normalized.isEmpty) {
      return '$prefix-${DateTime.now().millisecondsSinceEpoch}';
    }
    return '$prefix-$normalized';
  }
}

class _AiScanPanel extends StatelessWidget {
  const _AiScanPanel({
    required this.scanning,
    required this.error,
    required this.scanned,
    required this.onPick,
  });

  final bool scanning;
  final String? error;
  final bool scanned;
  final ValueChanged<ImageSource> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FAFB),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _Tokens.teal.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chụp hoặc chọn ảnh lịch hẹn (tin nhắn, ghi chú...), '
            'AI sẽ tự điền thông tin.',
            style: TextStyle(
              color: _Tokens.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (scanning)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: _Tokens.teal,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _ScanSourceButton(
                    icon: Icons.photo_camera_outlined,
                    label: 'Chụp ảnh',
                    onPressed: () => onPick(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ScanSourceButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Chọn ảnh',
                    onPressed: () => onPick(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (scanned && !scanning) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 16),
                SizedBox(width: 6),
                Text(
                  'Đã điền thông tin từ ảnh. Vui lòng kiểm tra lại.',
                  style: TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ScanSourceButton extends StatelessWidget {
  const _ScanSourceButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _Tokens.teal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _Tokens.teal.withValues(alpha: 0.45)),
          ),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({
    required this.aiMode,
    required this.onManual,
    required this.onAi,
  });

  final bool aiMode;
  final VoidCallback onManual;
  final VoidCallback onAi;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeButton(
            label: 'Nhập thủ công',
            icon: Icons.person_outline,
            selected: !aiMode,
            onPressed: onManual,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ModeButton(
            label: 'AI tự động',
            icon: Icons.auto_awesome,
            selected: aiMode,
            onPressed: onAi,
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: TextButton.styleFrom(
          backgroundColor: selected ? _Tokens.teal : const Color(0xFFF2F3F6),
          foregroundColor: selected ? Colors.white : _Tokens.muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF697386),
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.hintText,
    required this.icon,
    required this.onChanged,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String hintText;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines,
      style: const TextStyle(
        color: _Tokens.text,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: Icon(icon, color: const Color(0xFF98A1B2), size: 20),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _Tokens.teal, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
      ),
    );
  }
}

class _PickerGroup extends StatelessWidget {
  const _PickerGroup({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_SectionLabel(label), const SizedBox(height: 8), child],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.value, required this.onPicked});

  final DateTime value;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    return _PickerButton(
      icon: Icons.calendar_today_outlined,
      label: DateFormat('MM/dd/yyyy').format(value),
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 2),
        );
        if (!context.mounted || picked == null) return;
        onPicked(picked);
      },
    );
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({required this.value, required this.onPicked});

  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onPicked;

  @override
  Widget build(BuildContext context) {
    return _PickerButton(
      icon: Icons.schedule_outlined,
      label: value.format(context),
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value,
        );
        if (!context.mounted || picked == null) return;
        onPicked(picked);
      },
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFF7F8FA),
          foregroundColor: _Tokens.text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF98A1B2), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 66,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _Tokens.teal,
          disabledBackgroundColor: const Color(0xFFD9DEDE),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: const Text(
          'Đặt lịch ngay',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.close, color: Color(0xFF697386), size: 22),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF5F6F8),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

class _Tokens {
  const _Tokens._();

  static const text = Color(0xFF111827);
  static const muted = Color(0xFF697386);
  static const teal = Color(0xFF22AFC2);
}
