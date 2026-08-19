import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/geu/visit_planner_models.dart';

class SkipMissionDraft {
  final String reason;
  final DateTime? rescheduleDate;
  const SkipMissionDraft({required this.reason, this.rescheduleDate});
}

Future<SkipMissionDraft?> showSkipMissionSheet(
  BuildContext context,
  MissionItem item,
) => showModalBottomSheet<SkipMissionDraft>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _SkipMissionSheet(item: item),
);

class _SkipMissionSheet extends StatefulWidget {
  final MissionItem item;
  const _SkipMissionSheet({required this.item});
  @override
  State<_SkipMissionSheet> createState() => _SkipMissionSheetState();
}

class _SkipMissionSheetState extends State<_SkipMissionSheet> {
  String _choice = '';
  DateTime? _date;
  final _other = TextEditingController();
  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null && mounted) setState(() => _date = value);
  }

  @override
  Widget build(BuildContext context) {
    final valid =
        _choice.isNotEmpty &&
        (_choice != 'Jadwalkan ulang' || _date != null) &&
        (_choice != 'Lainnya' || _other.text.trim().isNotEmpty);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lewati kunjungan',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              widget.item.supplierName,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ...['Lokasi tutup', 'Jadwalkan ulang', 'Lainnya'].map(
              (value) => RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text(value),
                value: value,
                groupValue: _choice,
                onChanged: (v) => setState(() => _choice = v ?? ''),
              ),
            ),
            if (_choice == 'Jadwalkan ulang')
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  _date == null
                      ? 'Pilih tanggal baru'
                      : '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}',
                ),
              ),
            if (_choice == 'Lainnya')
              TextField(
                controller: _other,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Alasan *',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: valid
                    ? () => Navigator.pop(
                        context,
                        SkipMissionDraft(
                          reason: _choice == 'Lainnya'
                              ? _other.text.trim()
                              : _choice,
                          rescheduleDate: _date,
                        ),
                      )
                    : null,
                child: const Text('Konfirmasi lewati'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
