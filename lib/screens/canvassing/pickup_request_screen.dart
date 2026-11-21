import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../../constants/app_colors.dart';
import '../../services/geu/pickup_service.dart';

class PickupRequestScreen extends StatefulWidget {
  const PickupRequestScreen({super.key});
  @override
  State<PickupRequestScreen> createState() => _PickupRequestScreenState();
}

class _PickupRequestScreenState extends State<PickupRequestScreen> {
  final search = TextEditingController();
  final notes = TextEditingController();
  final qty = TextEditingController();
  final dpPercent = TextEditingController();
  final installmentCount = TextEditingController();
  final intervalDays = TextEditingController();
  final _signature = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> workOrders = [];
  Map<String, List<Map<String, dynamic>>> dropdowns = {};
  Map<String, dynamic>? selected, supplier;
  int? warehouseId, routeId, unitId;
  DateTime date = DateUtils.dateOnly(DateTime.now());
  DateTime installmentStart = DateUtils.dateOnly(DateTime.now());
  List<String> zoneDays = [];
  List<String> contractPhotos = [];
  Uint8List? signaturePng;
  String type = 'pickup';
  String price = '';
  String? rekeningWarning, searchError, formError;
  bool loadingDropdowns = true;
  bool loadingSupplier = false;
  bool loading = false;
  bool online = true;
  bool dpEnabled = false;
  bool installmentEnabled = false;
  bool paymentPlanOpen = false;
  bool checkingBank = false;
  Timer? _searchDebounce;
  int _searchRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    _checkOnline();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    search.dispose();
    notes.dispose();
    qty.dispose();
    dpPercent.dispose();
    installmentCount.dispose();
    intervalDays.dispose();
    _signature.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    try {
      final result = await PickupService.createDropdowns();
      if (mounted)
        setState(() {
          dropdowns = result;
          loadingDropdowns = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          formError = _message(error);
          loadingDropdowns = false;
        });
    }
  }

  Future<void> _checkOnline() async {
    final value = await PickupService.isOnline();
    if (mounted) setState(() => online = value);
  }

  int? _id(Map row) => int.tryParse(
    '${row['id'] ?? row['gudang_id'] ?? row['provinsi_id'] ?? row['satuan_id'] ?? ''}',
  );
  String _label(Map row) =>
      '${row['name'] ?? row['nama'] ?? row['nama_gudang'] ?? row['gudang'] ?? row['text'] ?? '-'}';
  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '').split('\n#').first;

  Future<void> _search() async {
    final query = search.text.trim();
    final request = ++_searchRequest;
    if (!mounted) return;
    setState(() {
      searchError = null;
    });
    try {
      final result = await PickupService.searchWorkOrders(query);
      if (mounted && request == _searchRequest)
        setState(() => workOrders = result);
    } catch (error) {
      if (mounted && request == _searchRequest)
        setState(() {
          workOrders = [];
          searchError = _message(error);
        });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _selectWorkOrder(Map<String, dynamic> wo) async {
    setState(() {
      selected = wo;
      supplier = null;
      loadingSupplier = true;
      checkingBank = true;
      rekeningWarning = null;
      warehouseId = null;
      routeId = null;
      unitId = null;
      zoneDays = [];
      price = '';
      search.clear();
      workOrders = [];
      searchError = null;
      formError = null;
    });
    final supplierId = int.tryParse('${wo['supplier_id'] ?? ''}') ?? 0;
    try {
      final data = await PickupService.supplierDetail(supplierId);
      if (!mounted) return;
      setState(() {
        supplier = data;
        final assignedWarehouse = int.tryParse(
          '${data['gudang_terdekat_id'] ?? ''}',
        );
        final assignedRoute = int.tryParse('${data['provinsi_id'] ?? ''}');
        if (assignedWarehouse != null &&
            dropdowns['gudang']?.any((r) => _id(r) == assignedWarehouse) ==
                true)
          warehouseId = assignedWarehouse;
        if (assignedRoute != null &&
            dropdowns['provinces']?.any((r) => _id(r) == assignedRoute) == true)
          routeId = assignedRoute;
        price =
            '${wo['status_wo'] == 'A3' ? 0 : data['price'] ?? wo['harga_awal'] ?? 0}';
      });
      try {
        final reason = await PickupService.validateSupplierBank(supplierId);
        if (mounted)
          setState(() {
            rekeningWarning = reason;
            checkingBank = false;
          });
      } catch (_) {
        if (mounted)
          setState(() {
            rekeningWarning =
                'Validasi rekening online belum berhasil. Coba lagi sebelum menyimpan.';
            checkingBank = false;
          });
      }
      try {
        final days = await PickupService.supplierSchedule(supplierId);
        if (mounted) setState(() => zoneDays = days);
      } catch (_) {}
    } catch (error) {
      if (mounted)
        setState(() {
          supplier = null;
          formError = _message(error);
        });
    } finally {
      if (mounted)
        setState(() {
          loadingSupplier = false;
          checkingBank = false;
        });
    }
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 78,
      maxWidth: 1600,
    );
    if (file == null) return;
    contractPhotos.add(base64Encode(await file.readAsBytes()));
    if (mounted) setState(() {});
  }

  Future<void> _saveSignature() async {
    final bytes = await _signature.toPngBytes();
    if (bytes == null || bytes.isEmpty) return;
    setState(() => signaturePng = bytes);
  }

  double get _estimate =>
      (double.tryParse(qty.text) ?? 0) * (double.tryParse(price) ?? 0);
  bool get _paymentPlanValid =>
      (!dpEnabled ||
          ((double.tryParse(dpPercent.text) ?? -1) >= 0 &&
              (double.tryParse(dpPercent.text) ?? 101) <= 100 &&
              contractPhotos.isNotEmpty &&
              signaturePng != null)) &&
      (!installmentEnabled ||
          ((int.tryParse(installmentCount.text) ?? 0) > 0 &&
              (int.tryParse(intervalDays.text) ?? 0) > 0));

  Future<void> _submit() async {
    if (!online) {
      _toast('Request pickup hanya tersedia saat online.');
      return;
    }
    if (selected == null ||
        supplier == null ||
        warehouseId == null ||
        unitId == null ||
        qty.text.trim().isEmpty) {
      _toast('Lengkapi WO, gudang, kemasan, dan jumlah pickup.');
      return;
    }
    if (!_paymentPlanValid) {
      _toast('Lengkapi data payment plan dan bukti yang wajib.');
      return;
    }
    if (rekeningWarning != null) {
      _toast('Rekening supplier harus tervalidasi sebelum membuat pickup.');
      return;
    }
    if (checkingBank || loadingSupplier) {
      _toast('Menunggu validasi rekening supplier selesai.');
      return;
    }
    if (zoneDays.isNotEmpty &&
        !zoneDays.any((day) => _sameWeekday(day, date.weekday))) {
      _toast('Tanggal tidak sesuai jadwal zona: ${zoneDays.join(', ')}');
      return;
    }
    setState(() {
      loading = true;
      formError = null;
    });
    try {
      final plan = dpEnabled || installmentEnabled
          ? <String, dynamic>{
              'has_dp': dpEnabled,
              if (dpEnabled) 'dp_percentage': double.parse(dpPercent.text),
              'installment_enabled': installmentEnabled,
              if (installmentEnabled)
                'installment_count': int.parse(installmentCount.text),
              if (installmentEnabled)
                'interval_days': int.parse(intervalDays.text),
              if (installmentEnabled)
                'installment_start_date': _apiDate(installmentStart),
              if (dpEnabled)
                'contract_photos': contractPhotos
                    .map((photo) => 'data:image/jpeg;base64,$photo')
                    .toList(),
              if (dpEnabled)
                'signature_photos': [
                  'data:image/png;base64,${base64Encode(signaturePng!)}',
                ],
            }
          : null;
      await PickupService.create(
        date: _apiDate(date),
        warehouseId: warehouseId!,
        type: type,
        routeProvinceId: routeId,
        workOrderId: int.tryParse('${selected!['id']}') ?? 0,
        supplierId: int.tryParse('${selected!['supplier_id']}') ?? 0,
        unitId: unitId!,
        quantity: double.parse(qty.text),
        price: double.tryParse(price) ?? 0,
        tick: _tick,
        notes: notes.text,
        paymentPlan: plan,
      );
      if (!mounted) return;
      _toast('Request pickup berhasil dibuat.');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => formError = _message(error));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool _tick = false;
  bool _sameWeekday(String name, int weekday) {
    const ids = {
      'senin': 1,
      'selasa': 2,
      'rabu': 3,
      'kamis': 4,
      'jumat': 5,
      'sabtu': 6,
      'minggu': 7,
    };
    return ids.entries.any(
      (e) => name.toLowerCase().contains(e.key) && e.value == weekday,
    );
  }

  String _apiDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _pickDate({required bool installment}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final current = installment ? installmentStart : date;
    final result = await showDatePicker(
      context: context,
      initialDate: current.isBefore(today) ? today : current,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      selectableDayPredicate: installment || zoneDays.isEmpty
          ? null
          : (day) => zoneDays.any((name) => _sameWeekday(name, day.weekday)),
    );
    if (result != null && mounted)
      setState(() {
        if (installment) {
          installmentStart = result;
        } else {
          date = result;
        }
      });
  }

  Widget _dropdown({
    required String label,
    required String key,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    final rows = dropdowns[key] ?? const <Map<String, dynamic>>[];
    return DropdownButtonFormField<int>(
      value: rows.any((r) => _id(r) == value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: rows
          .where((r) => _id(r) != null)
          .map(
            (r) => DropdownMenuItem(
              value: _id(r),
              child: Text(_label(r), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: loading ? null : onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loadingDropdowns)
      return Scaffold(
        appBar: AppBar(title: const Text('Create Pickup')),
        body: const Center(child: CircularProgressIndicator()),
      );
    return Scaffold(
      appBar: AppBar(title: const Text('Create Pickup')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () => _pickDate(installment: false),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      'Tanggal: ${date.day}/${date.month}/${date.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(
                      labelText: 'Tipe',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pickup', child: Text('Pickup')),
                      DropdownMenuItem(
                        value: 'mandiri',
                        child: Text('Mandiri'),
                      ),
                    ],
                    onChanged: loading
                        ? null
                        : (v) => setState(() => type = v ?? 'pickup'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: search,
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                _searchDebounce?.cancel();
                _search();
              },
              decoration: InputDecoration(
                labelText: 'Pilih Work Order',
                hintText: 'Cari kode WO atau supplier',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          search.clear();
                          setState(() => workOrders = []);
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            if (search.text.trim().isEmpty && selected == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Daftar WO yang muncul mengikuti akun dan izin role yang sedang login.',
                ),
              ),
            if (searchError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  searchError!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ...workOrders.map(
              (wo) => Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  onTap: loading ? null : () => _selectWorkOrder(wo),
                  title: Text(
                    '${wo['kode'] ?? '-'}  |  ${wo['supplier_name'] ?? '-'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Status ${wo['status_wo'] ?? '-'}${'${wo['creator_name'] ?? ''}'.isEmpty ? '' : ' • Dibuat ${wo['creator_name']}'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
            if (selected != null) ...[
              const SizedBox(height: 14),
              Card(
                color: const Color(0xFFE8F1ED),
                child: ListTile(
                  title: Text(
                    '${selected!['supplier_name'] ?? '-'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${supplier?['alamat'] ?? 'Memuat detail supplier…'}',
                  ),
                  trailing: loadingSupplier
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          onPressed: () => setState(() {
                            selected = null;
                            supplier = null;
                          }),
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              if (supplier != null) ...[
                if (rekeningWarning != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: Text(
                      rekeningWarning!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                if (rekeningWarning == null && checkingBank)
                  const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _dropdown(
                        label: 'Rute',
                        key: 'provinces',
                        value: routeId,
                        onChanged: (v) => setState(() => routeId = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dropdown(
                        label: 'Gudang *',
                        key: 'gudang',
                        value: warehouseId,
                        onChanged: (v) => setState(() => warehouseId = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _dropdown(
                        label: 'Kemasan *',
                        key: 'kemasan',
                        value: unitId,
                        onChanged: (v) => setState(() => unitId = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: qty,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Qty *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey(price),
                        initialValue: price,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Harga',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('INC (Tick)'),
                        value: _tick,
                        onChanged: (v) => setState(() => _tick = v ?? false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Catatan',
                    hintText: 'Opsional',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Payment Plan'),
                        subtitle: const Text('Opsional'),
                        trailing: Icon(
                          paymentPlanOpen
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        onTap: () =>
                            setState(() => paymentPlanOpen = !paymentPlanOpen),
                      ),
                      if (paymentPlanOpen)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Uang muka (DP)'),
                                value: dpEnabled,
                                onChanged: loading
                                    ? null
                                    : (v) => setState(() {
                                        dpEnabled = v ?? false;
                                        if (dpEnabled)
                                          installmentEnabled = false;
                                      }),
                              ),
                              if (dpEnabled) ...[
                                TextField(
                                  controller: dpPercent,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Persentase DP *',
                                    suffixText: '%',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Estimasi DP: Rp ${(_estimate * ((double.tryParse(dpPercent.text) ?? 0) / 100)).round()}',
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: loading ? null : _pickPhoto,
                                  icon: const Icon(Icons.add_a_photo_outlined),
                                  label: Text(
                                    'Foto kontrak (${contractPhotos.length})',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tanda tangan *',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Signature(
                                    controller: _signature,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        _signature.clear();
                                        setState(() => signaturePng = null);
                                      },
                                      child: const Text('Hapus TTD'),
                                    ),
                                    TextButton(
                                      onPressed: _saveSignature,
                                      child: const Text('Simpan TTD'),
                                    ),
                                    if (signaturePng != null)
                                      const Icon(
                                        Icons.check_circle,
                                        color: AppColors.success,
                                      ),
                                  ],
                                ),
                              ],
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Pembayaran bertahap'),
                                value: installmentEnabled,
                                onChanged: loading
                                    ? null
                                    : (v) => setState(() {
                                        installmentEnabled = v ?? false;
                                        if (installmentEnabled)
                                          dpEnabled = false;
                                      }),
                              ),
                              if (installmentEnabled) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: installmentCount,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Jumlah termin *',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: intervalDays,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Jarak hari *',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _pickDate(installment: true),
                                  icon: const Icon(Icons.calendar_month),
                                  label: Text(
                                    'Mulai ${installmentStart.day}/${installmentStart.month}/${installmentStart.year}',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
            if (formError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  formError!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed:
                    loading || !online || selected == null || supplier == null
                    ? null
                    : _submit,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(loading ? 'Menyimpan…' : 'Simpan Pickup'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
              ),
            ),
            if (!online)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Hubungkan internet untuk membuat pickup.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
