import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/geu/nfc_recovery_service.dart';

class NfcRecoveryCardScreen extends StatefulWidget {
  const NfcRecoveryCardScreen({super.key});

  @override
  State<NfcRecoveryCardScreen> createState() => _NfcRecoveryCardScreenState();
}

class _NfcRecoveryCardScreenState extends State<NfcRecoveryCardScreen> {
  List<Map<String, dynamic>> _warehouses = [];
  int? _warehouseId;
  bool _loading = true;
  bool _writing = false;
  bool _reading = false;
  Map<String, String>? _cardDetails;
  String? _error;

  String _friendlyError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('ioexception') || raw.contains('platformexception')) {
      return 'Android gagal memformat kartu MIFARE Classic ini. Coba format kartu sebagai NDEF di NFC Tools, lalu ulangi penulisan. Pastikan kartu menempel stabil selama proses.';
    }
    final message = error.toString().replaceFirst('Exception: ', '');
    final stackStart = message.indexOf('\n#0');
    return stackStart == -1 ? message : message.substring(0, stackStart);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await NfcRecoveryService.loadWarehouses();
      if (!mounted) return;
      setState(() {
        _warehouses = rows;
        _warehouseId = _id(rows.first);
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(error);
          _loading = false;
        });
      }
    }
  }

  int? _id(Map row) => int.tryParse(
    '${row['id'] ?? row['gudang_id'] ?? row['warehouse_id'] ?? ''}',
  );
  String _name(Map row) =>
      '${row['nama_gudang'] ?? row['gudang'] ?? row['name'] ?? row['nama'] ?? 'Gudang'}';

  Future<void> _writeCard() async {
    final warehouseId = _warehouseId;
    if (warehouseId == null || _writing) return;
    setState(() {
      _writing = true;
      _error = null;
    });
    try {
      final card = await NfcRecoveryService.issueCard(warehouseId);
      await NfcRecoveryService.writeTag(card);
      if (!mounted) return;
      setState(
        () => _cardDetails = {
          'card_id': card.cardId,
          'warehouse_id': card.warehouseId.toString(),
          'warehouse_name': card.warehouseName,
          'expires_at': card.expiresAt.toUtc().toIso8601String(),
        },
      );
      final localExpiry = card.expiresAt.toLocal();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kartu ${card.warehouseName} berhasil ditulis. Aktif sampai ${MaterialLocalizations.of(context).formatMediumDate(localExpiry)}.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _readCard() async {
    if (_reading || _writing) return;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final data = await NfcRecoveryService.readTag();
      if (mounted) setState(() => _cardDetails = data);
    } catch (error) {
      if (mounted)
        setState(() {
          _error = _friendlyError(error);
          _cardDetails = null;
        });
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  String _cardExpiry(Map<String, String> details) {
    final expiry = DateTime.tryParse(details['expires_at'] ?? '');
    if (expiry == null) return 'Informasi masa aktif tidak ada di kartu ini';
    final local = expiry.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '${expiry.isAfter(DateTime.now()) ? 'Aktif sampai' : 'Kedaluwarsa'} $date, $time';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tulis Kartu NFC')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Pilih gudang untuk kartu pemulihan device lock. Kartu berlaku 5 hari dan hanya dapat dipakai setelah email serta password akun diverifikasi.',
              ),
              const SizedBox(height: 20),
              if (_warehouses.isEmpty)
                Text(_error ?? 'Tidak ada gudang yang dapat dipilih.')
              else
                DropdownButtonFormField<int>(
                  value: _warehouseId,
                  decoration: const InputDecoration(
                    labelText: 'Gudang',
                    border: OutlineInputBorder(),
                  ),
                  items: _warehouses
                      .where((row) => _id(row) != null)
                      .map(
                        (row) => DropdownMenuItem(
                          value: _id(row),
                          child: Text(
                            _name(row),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _writing
                      ? null
                      : (value) => setState(() => _warehouseId = value),
                ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              if (_cardDetails != null) ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail kartu NFC',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        _detailRow(
                          'Gudang',
                          _cardDetails!['warehouse_name'] ??
                              'Tidak tercatat pada kartu',
                        ),
                        if (_cardDetails!['warehouse_id'] != null)
                          _detailRow(
                            'ID Gudang',
                            _cardDetails!['warehouse_id']!,
                          ),
                        _detailRow('ID Kartu', _cardDetails!['card_id'] ?? '-'),
                        const SizedBox(height: 8),
                        Text(
                          _cardExpiry(_cardDetails!),
                          style: TextStyle(
                            color:
                                (_cardDetails!['expires_at'] == null ||
                                    (DateTime.tryParse(
                                          _cardDetails!['expires_at']!,
                                        )?.isAfter(DateTime.now()) ??
                                        false))
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_cardDetails!['warehouse_name'] == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Kartu ini ditulis dengan format lama. Tulis ulang agar nama gudang dan masa aktif tersimpan di kartu.',
                            ),
                          ),
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Detail dibaca dari isi kartu. Validasi final tetap dilakukan server saat kartu dipakai.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _reading || _writing ? null : _readCard,
                  icon: _reading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.nfc),
                  label: Text(
                    _reading ? 'Membaca kartu…' : 'Baca detail kartu',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _writing || _reading || _warehouseId == null
                      ? null
                      : _writeCard,
                  icon: _writing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.nfc),
                  label: Text(
                    _writing ? 'Menulis kartu…' : 'Tulis kartu aktif 5 hari',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        const Text(':  '),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
