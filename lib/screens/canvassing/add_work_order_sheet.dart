import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/geu/visit_planner_models.dart';
import '../../services/geu/visit_planner_service.dart';

Future<int?> showAddWorkOrderSheet(
  BuildContext context,
  MissionItem supplier,
) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _AddWorkOrderSheet(supplier: supplier),
);

class _AddWorkOrderSheet extends StatefulWidget {
  final MissionItem supplier;
  const _AddWorkOrderSheet({required this.supplier});

  @override
  State<_AddWorkOrderSheet> createState() => _AddWorkOrderSheetState();
}

class _AddWorkOrderSheetState extends State<_AddWorkOrderSheet> {
  DateTime _date = DateTime.now();
  DateTime? _followUpAt;
  int? _statusId;
  List<WorkOrderStatus> _statuses = const [];
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statuses = await VisitPlannerService.getWorkOrderStatuses();
      if (mounted)
        setState(() {
          _statuses = statuses;
          _loading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error.toString();
          _loading = false;
        });
    }
  }

  Future<void> _pickDate({required bool followUp}) async {
    final initial = followUp ? _followUpAt ?? _date : _date;
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (result != null && mounted)
      setState(() {
        if (followUp)
          _followUpAt = result;
        else
          _date = result;
      });
  }

  String _format(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _submit() async {
    if (_statusId == null) return;
    setState(() => _saving = true);
    try {
      final workOrder = await VisitPlannerService.createWorkOrder(
        supplierId: widget.supplier.supplierId,
        statusId: _statusId!,
        date: _date,
        followUpAt: _followUpAt,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${workOrder.code} berhasil dibuat.')),
      );
      Navigator.pop(context, workOrder.id);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tambah Work Order',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.supplier.supplierName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.supplier.address.isEmpty
                      ? 'Alamat belum tersedia'
                      : widget.supplier.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DateField(
            label: 'Tanggal WO',
            value: _format(_date),
            onTap: () => _pickDate(followUp: false),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else
            DropdownButtonFormField<int>(
              value: _statusId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Status WO *',
                border: OutlineInputBorder(),
              ),
              items: _statuses
                  .map(
                    (status) => DropdownMenuItem(
                      value: status.id,
                      child: Text('${status.code} — ${status.name}'),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _statusId = value),
            ),
          const SizedBox(height: 12),
          _DateField(
            label: 'Jadwal follow-up (opsional)',
            value: _followUpAt == null
                ? 'Pilih tanggal'
                : _format(_followUpAt!),
            onTap: () => _pickDate(followUp: true),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _loading || _saving || _statusId == null
                  ? null
                  : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Simpan Work Order'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      child: Text(value),
    ),
  );
}
