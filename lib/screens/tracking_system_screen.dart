import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/geu/geu_api_client.dart';

class TrackingSystemScreen extends StatefulWidget {
  const TrackingSystemScreen({super.key});

  @override
  State<TrackingSystemScreen> createState() => _TrackingSystemScreenState();
}

class _TrackingSystemScreenState extends State<TrackingSystemScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Masukkan kode PO, WO, atau Surat Jalan.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = await GeuApiClient.instance;
      final response = await dio.get(
        '/api-tms/tracking/e2e',
        queryParameters: {'code': code},
      );
      final data = GeuApiClient.unwrapData(response.data);
      if (response.statusCode != 200 || data is! Map) {
        throw Exception(
          GeuApiClient.responseMessage(response.data) ??
              'Data tracking tidak ditemukan.',
        );
      }
      setState(() => _result = Map<String, dynamic>.from(data));
    } catch (e) {
      setState(() {
        _result = null;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _text(dynamic value, [String fallback = '-']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _date(dynamic value) {
    final raw = _text(value, '');
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year} $hour:$minute';
  }

  String _pickupStatus(dynamic value) {
    final raw = _text(value);
    if (RegExp(r'^\d+$').hasMatch(raw)) return 'Pickup';
    switch (raw.toLowerCase()) {
      case 'approved':
        return 'Disetujui';
      case 'pending':
        return 'Menunggu';
      case 'done':
      case 'completed':
        return 'Selesai';
      default:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = _result?['pickup'] is Map
        ? Map<String, dynamic>.from(_result!['pickup'] as Map)
        : null;
    final workOrders = _maps(_result?['work_orders']);
    final suratJalan = _maps(_result?['surat_jalans']);
    final auditLogs = _maps(_result?['audit_logs']);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      appBar: AppBar(
        title: const Text('Tracking System'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _result == null ? () async {} : _search,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _buildSearchCard(),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildMessage(Icons.search_off_rounded, _error!, Colors.red),
            if (pickup != null) ...[
              const SizedBox(height: 16),
              _buildPickupCard(pickup),
              if (workOrders.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSection(
                  'Work Order',
                  Icons.description_outlined,
                  workOrders.map(_buildWorkOrder).toList(),
                ),
              ],
              if (suratJalan.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSection(
                  'Surat Jalan',
                  Icons.receipt_long_outlined,
                  suratJalan.map(_buildSuratJalan).toList(),
                ),
              ],
              if (auditLogs.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildAuditTimeline(auditLogs),
              ],
            ],
            if (_result == null && _error == null && !_loading)
              _buildMessage(
                Icons.route_outlined,
                'Cari kode untuk melihat perjalanan dokumen dan status operasional.',
                AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lacak dokumen operasional',
              style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              'Gunakan kode PO, WO, atau Surat Jalan.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Contoh: GEU-PO-26-HBZ0023',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: _loading ? null : _search,
                ),
                filled: true,
                fillColor: const Color(0xFFF6F8F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupCard(Map<String, dynamic> p) {
    final status = _pickupStatus(p['status']);
    return Card(
      elevation: 0,
      color: AppColors.primaryGreen,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _text(p['kode']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _whiteLine(
              Icons.calendar_today_outlined,
              _date(p['tgl'] ?? p['created_at']),
            ),
            _whiteLine(Icons.store_outlined, _text(p['gudang_name'])),
            _whiteLine(
              Icons.person_outline,
              _text(p['driver_name'], 'Driver belum ditentukan'),
            ),
            _whiteLine(
              Icons.directions_car_outlined,
              _text(p['fleet_plat'], 'Armada belum ditentukan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _whiteLine(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Icon(icon, size: 17, color: Colors.white70),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
          ),
        ),
      ],
    ),
  );

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryGreen),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildWorkOrder(Map<String, dynamic> item) => _compactTile(
    Icons.description_outlined,
    _text(item['kode']),
    '${_text(item['supplier_name'])} • Qty ${_text(item['qty'])} ${_text(item['satuan_name'], '')}'
        .trim(),
  );

  Widget _buildSuratJalan(Map<String, dynamic> item) {
    final details = _maps(item['details']);
    final done = details
        .where((d) => _text(d['status']).toLowerCase() == 'done')
        .length;
    return _compactTile(
      Icons.receipt_long_outlined,
      _text(item['kode']),
      '${_date(item['tgl'])} • ${_text(item['status'])} • ${done}/${details.length} selesai',
    );
  }

  Widget _compactTile(IconData icon, String title, String subtitle) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: AppColors.primaryGreen.withValues(alpha: .1),
      child: Icon(icon, color: AppColors.primaryGreen, size: 19),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
  );

  Widget _buildAuditTimeline(List<Map<String, dynamic>> logs) {
    final visible = logs.take(40).toList();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.timeline_rounded,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 9),
                Text(
                  'Riwayat aktivitas',
                  style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...visible.asMap().entries.map((entry) {
              final log = entry.value;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (entry.key < visible.length - 1)
                          Expanded(
                            child: Container(
                              width: 1.5,
                              color: AppColors.primaryGreen.withValues(
                                alpha: .25,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _text(log['action']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _date(log['created_at']),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (_text(log['description'], '').isNotEmpty)
                              Text(
                                _text(log['description']),
                                style: AppTextStyles.caption,
                              ),
                            if (_text(log['user_name'], '').isNotEmpty)
                              Text(
                                'Oleh ${_text(log['user_name'])}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(IconData icon, String message, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 18),
    child: Column(
      children: [
        Icon(icon, size: 42, color: color.withValues(alpha: .7)),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, height: 1.4),
        ),
      ],
    ),
  );
}
