import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/geu/visit_planner_service.dart' show WorkOrderStatus;
import '../../services/geu/work_order_service.dart';

/// Generic "create WO for this supplier" sheet, usable anywhere a supplier
/// id/name is known (e.g. My Claims) — unlike add_work_order_sheet.dart,
/// which is wired to the visit-planner-scoped endpoint and a MissionItem.
Future<String?> showCreateWorkOrderSheet(
  BuildContext context, {
  required int supplierId,
  required String supplierName,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      _CreateWorkOrderSheet(supplierId: supplierId, supplierName: supplierName),
);

class _CreateWorkOrderSheet extends StatefulWidget {
  final int supplierId;
  final String supplierName;
  const _CreateWorkOrderSheet({
    required this.supplierId,
    required this.supplierName,
  });

  @override
  State<_CreateWorkOrderSheet> createState() => _CreateWorkOrderSheetState();
}

class _CreateWorkOrderSheetState extends State<_CreateWorkOrderSheet> {
  DateTime _tgl = DateTime.now();
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
    try {
      final statuses = await WorkOrderService.statuses();
      if (mounted) setState(() => _statuses = statuses);
    } catch (_) {
      // Status is optional on this endpoint — the form still works without
      // it, so a failed fetch shouldn't block WO creation.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _tgl,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (result != null && mounted) setState(() => _tgl = result);
  }

  String _format(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final kode = await WorkOrderService.create(
        supplierId: widget.supplierId,
        tgl: _tgl,
        statusId: _statusId,
      );
      if (!mounted) return;
      Navigator.pop(context, kode);
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
            'Buat Work Order',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.supplierName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Tanggal WO',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(_format(_tgl)),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_statuses.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: _statusId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Status WO (opsional)',
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
              onPressed: _saving ? null : _submit,
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
