import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/operational_report.dart';
import '../../domain/usecases/get_operational_reports_usecase.dart';
import 'report_csv_export.dart';

class OperationalReports extends StatefulWidget {
  const OperationalReports({
    super.key,
    required this.tenantId,
    required this.rangeIndex,
  });

  final String tenantId;
  final int rangeIndex;

  @override
  State<OperationalReports> createState() => _OperationalReportsState();
}

class _OperationalReportsState extends State<OperationalReports> {
  late final future = getIt<GetOperationalReportsUseCase>()(widget.tenantId);
  ReportKind kind = ReportKind.bookings;
  String staff = '';
  String service = '';
  String status = '';
  String paymentMethod = '';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        final either = snapshot.data;
        if (either == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return either.fold((failure) => Text(failure.message), (all) {
          final filtered = _filter(all);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Báo cáo vận hành',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SegmentedButton<ReportKind>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ReportKind.bookings,
                    label: Text('Lịch'),
                  ),
                  ButtonSegment(value: ReportKind.payments, label: Text('Thu')),
                  ButtonSegment(
                    value: ReportKind.customers,
                    label: Text('Khách'),
                  ),
                  ButtonSegment(
                    value: ReportKind.campaigns,
                    label: Text('Email'),
                  ),
                  ButtonSegment(value: ReportKind.staff, label: Text('NV')),
                ],
                selected: {kind},
                onSelectionChanged: (value) =>
                    setState(() => kind = value.first),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Filter(
                    label: 'Nhân viên',
                    value: staff,
                    values: _values(all, (record) => record.staffId),
                    onChanged: (value) => setState(() => staff = value),
                  ),
                  _Filter(
                    label: 'Dịch vụ',
                    value: service,
                    values: _values(all, (record) => record.serviceId),
                    onChanged: (value) => setState(() => service = value),
                  ),
                  _Filter(
                    label: 'Trạng thái',
                    value: status,
                    values: _values(all, (record) => record.status),
                    onChanged: (value) => setState(() => status = value),
                  ),
                  _Filter(
                    label: 'Thanh toán',
                    value: paymentMethod,
                    values: _values(all, (record) => record.paymentMethod),
                    onChanged: (value) => setState(() => paymentMethod = value),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Kpis(records: filtered),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: supportsCsvExport
                      ? () => exportCsv(
                          'schedula-${kind.name}.csv',
                          _csv(filtered),
                        )
                      : null,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(
                    supportsCsvExport ? 'Xuất CSV' : 'CSV chỉ có trên web',
                  ),
                ),
              ),
              ..._rows(all, filtered),
            ],
          );
        });
      },
    );
  }

  List<ReportRecord> _filter(List<ReportRecord> all) {
    final now = DateTime.now();
    final start = switch (widget.rangeIndex) {
      0 => DateTime(now.year, now.month, now.day),
      1 => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6)),
      2 => DateTime(now.year, now.month),
      _ => DateTime(now.year),
    };
    return all
        .where(
          (record) =>
              record.kind == kind &&
              !record.date.isBefore(start) &&
              (staff.isEmpty || record.staffId == staff) &&
              (service.isEmpty || record.serviceId == service) &&
              (status.isEmpty || record.status == status) &&
              (paymentMethod.isEmpty || record.paymentMethod == paymentMethod),
        )
        .toList(growable: false);
  }

  List<Widget> _rows(List<ReportRecord> all, List<ReportRecord> filtered) {
    if (kind != ReportKind.staff) {
      return filtered
          .map(
            (record) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(record.title),
              subtitle: Text(
                [
                  record.subtitle,
                  if (record.bookingId.isNotEmpty) 'Lịch ${record.bookingId}',
                  if (record.reconciliationStatus.isNotEmpty)
                    'Đối soát ${record.reconciliationStatus}',
                ].where((value) => value.isNotEmpty).join(' • '),
              ),
              trailing: Text(
                record.amount == 0
                    ? record.status
                    : '${record.amount.toString()} đ',
              ),
            ),
          )
          .toList(growable: false);
    }
    final bookings = all.where((record) => record.kind == ReportKind.bookings);
    return filtered
        .map(
          (record) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(record.title),
            subtitle: Text(record.subtitle),
            trailing: Text(
              '${bookings.where((booking) => booking.staffId == record.id).length} lịch',
            ),
          ),
        )
        .toList(growable: false);
  }

  List<String> _values(
    List<ReportRecord> records,
    String Function(ReportRecord) read,
  ) {
    final values = records.map(read).where((value) => value.isNotEmpty).toSet()
      ..remove('');
    return values.toList(growable: false)..sort();
  }

  String _csv(List<ReportRecord> records) {
    String cell(Object value) => '"${value.toString().replaceAll('"', '""')}"';
    return [
      'id,date,title,subtitle,staffId,serviceId,status,paymentMethod,amount,bookingId,reconciliationStatus',
      ...records.map(
        (record) => [
          record.id,
          record.date.toIso8601String(),
          record.title,
          record.subtitle,
          record.staffId,
          record.serviceId,
          record.status,
          record.paymentMethod,
          record.amount,
          record.bookingId,
          record.reconciliationStatus,
        ].map(cell).join(','),
      ),
    ].join('\r\n');
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem(value: '', child: Text('Tất cả')),
          ...values.map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (selected) => onChanged(selected ?? ''),
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.records});

  final List<ReportRecord> records;

  @override
  Widget build(BuildContext context) {
    final total = records.fold<int>(0, (sum, record) => sum + record.amount);
    final completed = records
        .where(
          (record) => record.status == 'completed' || record.status == 'sent',
        )
        .length;
    return Row(
      children: [
        Expanded(
          child: _Kpi(label: 'Bản ghi', value: '${records.length}'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Kpi(label: 'Hoàn tất', value: '$completed'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Kpi(label: 'Tổng', value: '$total đ'),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
