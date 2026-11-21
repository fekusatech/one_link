import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/geu/visit_planner_service.dart' show WorkOrderStatus;
import '../../services/geu/work_order_service.dart';

/// Filter sheet for the WO list - mirrors crm-react's filter bar (date
/// range, status, type, PIC) so field sales can find "WO hari ini" or
/// "WO yang masih Open" without scrolling everything.
Future<WorkOrderFilters?> showWorkOrderFilterSheet(
  BuildContext context, {
  required WorkOrderFilters current,
}) => showModalBottomSheet<WorkOrderFilters>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _WorkOrderFilterSheet(initial: current),
);

class _WorkOrderFilterSheet extends StatefulWidget {
  final WorkOrderFilters initial;
  const _WorkOrderFilterSheet({required this.initial});

  @override
  State<_WorkOrderFilterSheet> createState() => _WorkOrderFilterSheetState();
}

const _typeOptions = [
  (null, 'Semua Tipe'),
  ('revisit', 'Revisit'),
  ('cro', 'CRO'),
  ('regular', 'Reguler'),
];

class _WorkOrderFilterSheetState extends State<_WorkOrderFilterSheet> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int? _statusId;
  String? _type;
  WorkOrderPic? _pic;

  List<WorkOrderStatus> _statuses = const [];
  bool _loadingStatuses = true;

  @override
  void initState() {
    super.initState();
    _dateFrom = widget.initial.dateFrom;
    _dateTo = widget.initial.dateTo;
    _statusId = widget.initial.statusId;
    _type = widget.initial.type;
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    try {
      final statuses = await WorkOrderService.statuses();
      if (mounted) setState(() => _statuses = statuses);
    } catch (_) {
      // Optional — status filter just won't offer options if this fails.
    } finally {
      if (mounted) setState(() => _loadingStatuses = false);
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
    );
    if (result != null && mounted) {
      setState(() {
        _dateFrom = result.start;
        _dateTo = result.end;
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  bool get _hasFilters =>
      _dateFrom != null ||
      _dateTo != null ||
      _statusId != null ||
      _type != null ||
      _pic != null;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 8,
      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filter Work Order',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              if (_hasFilters)
                TextButton(
                  onPressed: () => setState(() {
                    _dateFrom = null;
                    _dateTo = null;
                    _statusId = null;
                    _type = null;
                    _pic = null;
                  }),
                  child: const Text('Reset'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tanggal',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(
              _dateFrom != null && _dateTo != null
                  ? '${_formatDate(_dateFrom!)} - ${_formatDate(_dateTo!)}'
                  : 'Pilih rentang tanggal',
            ),
          ),
          const SizedBox(height: 16),
          const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _loadingStatuses
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<int?>(
                  initialValue: _statusId,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Semua Status'),
                    ),
                    for (final s in _statuses)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.code} - ${s.name}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _statusId = v),
                ),
          const SizedBox(height: 16),
          const Text('Tipe', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            initialValue: _type,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final (value, label) in _typeOptions)
                DropdownMenuItem(value: value, child: Text(label)),
            ],
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 16),
          const Text('PIC', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _PicPicker(
            selected: _pic,
            onChanged: (pic) => setState(() => _pic = pic),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                WorkOrderFilters(
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                  statusId: _statusId,
                  type: _type,
                  picId: _pic?.id,
                ),
              ),
              child: const Text('Terapkan Filter'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PicPicker extends StatefulWidget {
  final WorkOrderPic? selected;
  final ValueChanged<WorkOrderPic?> onChanged;
  const _PicPicker({required this.selected, required this.onChanged});

  @override
  State<_PicPicker> createState() => _PicPickerState();
}

class _PicPickerState extends State<_PicPicker> {
  @override
  Widget build(BuildContext context) {
    if (widget.selected != null) {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.selected!.name),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => widget.onChanged(null),
          ),
        ],
      );
    }
    return Autocomplete<WorkOrderPic>(
      displayStringForOption: (p) => p.name,
      optionsBuilder: (value) async {
        try {
          return await WorkOrderService.pics(search: value.text);
        } catch (_) {
          return const [];
        }
      },
      onSelected: widget.onChanged,
      fieldViewBuilder: (context, controller, focusNode, onSubmit) =>
          TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              hintText: 'Cari PIC...',
            ),
          ),
    );
  }
}
