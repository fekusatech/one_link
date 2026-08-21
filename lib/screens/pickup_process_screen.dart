import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/surat_jalan.dart';
import '../services/geu/surat_jalan_service.dart';
import '../services/geu/photo_watermark_service.dart';
import '../services/user_storage.dart';

/// Mirrors application/views/surat-jalan/detail_form.php + new_take.php
/// (web ERP): a "KELENGKAPAN DATA" checklist (foto/GPS/TTD), multi-photo
/// capture with the watermark baked in and VISIBLE in the thumbnail (not
/// just applied silently at submit time), and a swipe-to-confirm slider for
/// the final step. Each piece of evidence is saved to the server as soon as
/// it's captured (same as web) — the final swipe only sends qty_real +
/// status=done, so a crash mid-flow doesn't lose already-captured evidence.
class PickupProcessScreen extends StatefulWidget {
  final SuratJalan? suratJalan;
  final int? supplierIndex;

  const PickupProcessScreen({super.key, this.suratJalan, this.supplierIndex});

  @override
  State<PickupProcessScreen> createState() => _PickupProcessScreenState();
}

class _PhotoTypeOption {
  final String value;
  final String label;
  const _PhotoTypeOption(this.value, this.label);
}

const _photoTypeOptions = [
  _PhotoTypeOption('delivery', 'Bukti Pengambilan'),
  _PhotoTypeOption('condition', 'Kondisi Barang'),
  _PhotoTypeOption('foto_kemasan', 'Kemasan'),
  _PhotoTypeOption('other', 'Lainnya'),
];

class _CapturedPhoto {
  final Uint8List bytes;
  final String photoType;
  final String label;
  _CapturedPhoto({required this.bytes, required this.photoType, required this.label});
}

class _PickupProcessScreenState extends State<PickupProcessScreen> {
  bool _isBusy = false;
  String _busyMessage = '';

  // Photos — uploaded immediately on capture (see _addPhoto), same as web.
  // _existingPhotoUrls comes from the server (driver left and came back to
  // this item) and is display-only; _photos is what THIS session captured.
  List<String> _existingPhotoUrls = [];
  final List<_CapturedPhoto> _photos = [];
  final ImagePicker _picker = ImagePicker();
  String _selectedPhotoType = _photoTypeOptions.first.value;
  bool _isCapturingPhoto = false;

  // GPS — saved immediately once captured. Seeded from the server on open
  // so resuming a partially-done item doesn't show "belum diambil" for
  // data that's already there.
  double? _gpsLat;
  double? _gpsLng;
  bool _isCapturingGps = false;

  // Signature — saved explicitly via a "Simpan" button (a pad needs a
  // deliberate confirm, unlike photo/GPS which are one-shot actions).
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: AppColors.primaryGreen,
    exportBackgroundColor: Colors.white,
  );
  bool _hasDrawnSignature = false;
  bool _ttdSaved = false;
  bool _isSavingTtd = false;
  String? _existingTtdUrl;
  Uint8List? _freshSignatureBytes;
  bool _redrawingSignature = false;

  // Qty Real — same underlying kemasan-unit value regardless of which mode
  // the driver is looking at; the other field is always a derived preview
  // (matches web's detail_form.php: qty_real ↔ liter conversion is
  // one-directional at input time, converted via detail.totLiter).
  bool _isKemasanMode = true;
  final TextEditingController _kemasanController = TextEditingController();
  final TextEditingController _literController = TextEditingController();

  // ── Getters ──────────────────────────────────────────────
  SuratJalanDetail? get _currentDetail {
    final details = widget.suratJalan?.suratJalanDetail ?? [];
    final idx = widget.supplierIndex ?? 0;
    return idx < details.length ? details[idx] : null;
  }

  String get supplierName => _currentDetail?.supplierName ?? 'Supplier';
  String get supplierStatus => _currentDetail?.status ?? 'pending';
  String get suratJalanKode => widget.suratJalan?.kode ?? 'SJ-XXXX';
  String get detailId => _currentDetail?.suratJalanDetailId ?? '';
  String get _satuanLabel => _currentDetail?.satuan ?? 'Liter';
  double get _totLiter => _currentDetail?.totLiter ?? 1;
  bool get _hasConversion => _totLiter > 1;

  bool _isWorkingMode = true;

  double get _qtyRealKemasan => double.tryParse(_kemasanController.text.replaceAll(',', '.')) ?? 0;
  bool get _hasAnyPhoto => _existingPhotoUrls.isNotEmpty || _photos.isNotEmpty;
  bool get _hasGps => _gpsLat != null && _gpsLng != null;
  bool get _canSubmit => _isWorkingMode && _hasAnyPhoto && _hasGps && _ttdSaved && _qtyRealKemasan > 0;

  @override
  void initState() {
    super.initState();
    _checkWorkingMode();
    _signatureController.addListener(() {
      if (mounted && _signatureController.isNotEmpty != _hasDrawnSignature) {
        setState(() {
          _hasDrawnSignature = _signatureController.isNotEmpty;
          if (_redrawingSignature) _ttdSaved = false; // redrawing invalidates the previous save
        });
      }
    });
    _kemasanController.text = _currentDetail?.qtyOrder ?? '';
    _syncLiterFromKemasan();
    _seedExistingEvidence();
  }

  Future<void> _checkWorkingMode() async {
    final active = await UserStorage.isWorkingModeActive();
    if (mounted) setState(() => _isWorkingMode = active);
  }

  // Resuming a partially-completed item (driver left mid-way and came back)
  // shouldn't show an empty checklist for evidence that's already saved —
  // that was the actual bug report: photo + signature visible on the detail
  // screen, but this screen opened as if nothing existed yet.
  void _seedExistingEvidence() {
    final detail = _currentDetail;
    if (detail == null) return;

    _existingPhotoUrls = detail.photoUrls.isNotEmpty
        ? detail.photoUrls
        : (detail.fotoUrl != null && detail.fotoUrl!.isNotEmpty ? [detail.fotoUrl!] : const []);

    if (detail.ttdUrl != null && detail.ttdUrl!.isNotEmpty) {
      _existingTtdUrl = detail.ttdUrl;
      _ttdSaved = true;
    }

    final gps = detail.suratJalanDetailGps;
    if (gps.isNotEmpty && gps.contains(',')) {
      final parts = gps.split(',');
      final lat = double.tryParse(parts[0].trim());
      final lng = parts.length > 1 ? double.tryParse(parts[1].trim()) : null;
      if (lat != null && lng != null) {
        _gpsLat = lat;
        _gpsLng = lng;
      }
    }
  }

  @override
  void dispose() {
    _kemasanController.dispose();
    _literController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<int> _requireDetailId() async {
    if (detailId.isEmpty) throw Exception('Detail ID tidak ditemukan');
    return int.parse(detailId);
  }

  // ── Qty conversion (kemasan <-> liter, via totLiter) ──────
  void _syncLiterFromKemasan() {
    final kemasan = double.tryParse(_kemasanController.text.replaceAll(',', '.')) ?? 0;
    _literController.text = _hasConversion
        ? (kemasan * _totLiter).toStringAsFixed(1)
        : _kemasanController.text;
  }

  void _onLiterChanged(String value) {
    final liter = double.tryParse(value.replaceAll(',', '.')) ?? 0;
    final kemasan = _hasConversion ? liter / _totLiter : liter;
    _kemasanController.text = _hasConversion ? kemasan.toStringAsFixed(2) : value;
    setState(() {});
  }

  // ── GPS ──────────────────────────────────────────────────
  Future<void> _captureGps() async {
    setState(() => _isCapturingGps = true);
    try {
      final id = await _requireDetailId();
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await GeuSuratJalanService.saveGps(id, pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _gpsLat = pos.latitude;
        _gpsLng = pos.longitude;
        _isCapturingGps = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturingGps = false);
      _showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── Photo (capture -> watermark -> upload immediately) ────
  Future<void> _addPhoto(ImageSource source) async {
    if (_photos.length >= 10) {
      _showErrorSnackbar('Maksimal 10 foto per item.');
      return;
    }
    final XFile? photo = await _picker.pickImage(source: source, imageQuality: 90);
    if (photo == null) return;

    setState(() => _isCapturingPhoto = true);
    try {
      final id = await _requireDetailId();
      final label = _photoTypeOptions.firstWhere((o) => o.value == _selectedPhotoType).label;
      final raw = await photo.readAsBytes();
      final watermarked = await PhotoWatermarkService.applyAndEncode(
        raw,
        label: label,
        suratJalanKode: suratJalanKode,
      );
      await GeuSuratJalanService.uploadPhotos(
        id,
        [GeuPhotoUpload(bytes: watermarked, photoType: _selectedPhotoType)],
        lat: _gpsLat,
        lng: _gpsLng,
      );
      if (!mounted) return;
      setState(() {
        _photos.add(_CapturedPhoto(bytes: watermarked, photoType: _selectedPhotoType, label: label));
        _isCapturingPhoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturingPhoto = false);
      _showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── Signature ────────────────────────────────────────────
  Future<void> _saveSignature() async {
    setState(() => _isSavingTtd = true);
    try {
      final id = await _requireDetailId();
      final Uint8List? sigBytes = await _signatureController.toPngBytes();
      if (sigBytes == null) throw Exception('Gagal memproses tanda tangan');
      final sigWebp = await PhotoWatermarkService.toWebp(sigBytes);
      await GeuSuratJalanService.saveTtd(id, sigWebp);
      if (!mounted) return;
      setState(() {
        _ttdSaved = true;
        _isSavingTtd = false;
        _redrawingSignature = false;
        _freshSignatureBytes = sigBytes;
        _existingTtdUrl = null; // stale now — this session's PNG bytes are the source of truth for preview
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingTtd = false);
      _showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── Final submit ─────────────────────────────────────────
  Future<void> _confirmAndSubmit() async {
    final qtyPlan = double.tryParse(_currentDetail?.qtyOrder ?? '') ?? 0;
    final qtyReal = _qtyRealKemasan;
    final planLiter = qtyPlan * _totLiter;
    final realLiter = qtyReal * _totLiter;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Sebelum Selesai'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _kv('Qty Plan', '${qtyPlan.toStringAsFixed(qtyPlan == qtyPlan.roundToDouble() ? 0 : 2)} $_satuanLabel'),
                  _kv('Qty Real (input Anda)', '${qtyReal.toStringAsFixed(qtyReal == qtyReal.roundToDouble() ? 0 : 2)} $_satuanLabel', highlight: true),
                  if (_hasConversion) ...[
                    const Divider(height: 16),
                    _kv('Konversi Plan', '${planLiter.toStringAsFixed(0)} Liter'),
                    _kv('Konversi Real', '${realLiter.toStringAsFixed(1)} Liter', highlight: true, color: AppColors.success),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '⚠️ PERHATIAN:',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '• Pastikan Qty Real sudah sesuai jumlah yang diangkut\n'
              '• Pastikan kemasan sesuai dengan yang diambil\n'
              '• Kesalahan input akan dikenakan SP (Surat Peringatan)',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Data yang sudah disubmit tidak bisa diubah kembali.',
              style: AppTextStyles.caption.copyWith(color: AppColors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cek Ulang'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            child: const Text('Ya, Saya Yakin'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _submitPickup();
  }

  Widget _kv(String label, String value, {bool highlight = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                color: highlight ? (color ?? AppColors.primaryGreen) : AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPickup() async {
    setState(() {
      _isBusy = true;
      _busyMessage = 'Menyelesaikan pickup...';
    });
    try {
      final id = await _requireDetailId();
      await GeuSuratJalanService.updateStatus(id, status: 'done', qtyReal: _qtyRealKemasan);
      if (mounted) {
        setState(() => _isBusy = false);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBusy = false);
        _showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showErrorSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  void _showCancelDialog() {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: !_isBusy,
      builder: (context) => AlertDialog(
        title: Text(
          'Batalkan Penjemputan',
          style: AppTextStyles.h5.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Masukkan alasan pembatalan untuk $supplierName:', style: AppTextStyles.bodySmall),
            const SizedBox(height: 12),
            TextFormField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tutup.. / Barang tidak ada.. / Lainnya..',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Kembali', style: TextStyle(color: AppColors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                _showErrorSnackbar('Alasan wajib diisi');
                return;
              }
              Navigator.pop(context);
              _handleCancel(reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCancel(String reason) async {
    setState(() {
      _isBusy = true;
      _busyMessage = 'Membatalkan penjemputan...';
    });
    try {
      final id = await _requireDetailId();
      await GeuSuratJalanService.updateStatus(id, status: 'cancel', keteranganCancel: reason);
      if (mounted) {
        setState(() => _isBusy = false);
        _showCancelSuccessDialog(reason);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBusy = false);
        _showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showCancelSuccessDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel, color: AppColors.error, size: 56),
            const SizedBox(height: 16),
            Text(
              'Penjemputan Dibatalkan',
              style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.bold, color: AppColors.error),
            ),
            const SizedBox(height: 8),
            Text('Alasan: $reason', textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 56),
            const SizedBox(height: 16),
            Text(
              'Pickup Berhasil!',
              style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.bold, color: AppColors.success),
            ),
            const SizedBox(height: 8),
            Text(
              'Volume: ${_qtyRealKemasan.toStringAsFixed(1)} $_satuanLabel\nSupplier: $supplierName',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Selesai', style: TextStyle(color: AppColors.primaryGreen)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Proses Penjemputan',
          style: AppTextStyles.h5.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryGreen),
        actions: [
          if (supplierStatus != 'done' && supplierStatus != 'cancelled' && supplierStatus != 'cancel')
            TextButton.icon(
              onPressed: _isBusy ? null : _showCancelDialog,
              icon: Icon(Icons.cancel_outlined, color: AppColors.error, size: 18),
              label: Text('Batalkan', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isWorkingMode)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade900),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '👁️ Mode Pratinjau (Off-Shift): Anda dapat melihat detail WO & supplier. Aktifkan Shift Kerja di Beranda untuk mengisi data.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildHeader(),
              const SizedBox(height: 20),
              _buildChecklist(),
              const SizedBox(height: 20),
              _buildSection(icon: Icons.camera_alt, title: 'Foto Bukti Penjemputan', required: true, child: _buildPhotoSection()),
              const SizedBox(height: 20),
              _buildSection(icon: Icons.location_on, title: 'Lokasi GPS', required: true, child: _buildGpsSection()),
              const SizedBox(height: 20),
              _buildSection(icon: Icons.draw, title: 'Tanda Tangan Pemilik', required: true, child: _buildSignatureSection()),
              const SizedBox(height: 20),
              _buildSection(icon: Icons.local_drink, title: 'Qty Real Angkut', required: true, child: _buildQtySection()),
              const SizedBox(height: 28),
              _buildSwipeSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(supplierName, style: AppTextStyles.h5.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(suratJalanKode, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          if (_currentDetail?.supplierAlamat != null) ...[
            const SizedBox(height: 4),
            Text(
              _currentDetail!.supplierAlamat,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _statusChip(supplierStatus),
              const Spacer(),
              if (_currentDetail?.qtyOrder != null)
                Text('Order: ${_currentDetail!.qtyOrder} $_satuanLabel', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'done'
        ? AppColors.success
        : status == 'pickup'
            ? AppColors.warning
            : status == 'cancelled' || status == 'cancel'
                ? AppColors.error
                : AppColors.grey;
    final label = status == 'done'
        ? 'SELESAI'
        : status == 'pickup'
            ? 'PROSES'
            : status == 'cancelled' || status == 'cancel'
                ? 'BATAL'
                : 'PENDING';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.bold)),
    );
  }

  // "KELENGKAPAN DATA" — mirrors detail_form.php's checklist pills exactly.
  Widget _buildChecklist() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('KELENGKAPAN DATA', style: AppTextStyles.caption.copyWith(color: AppColors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          _checklistItem('Foto Pengambilan (${_existingPhotoUrls.length + _photos.length})', _hasAnyPhoto),
          const SizedBox(height: 6),
          _checklistItem('GPS Lokasi', _hasGps),
          const SizedBox(height: 6),
          _checklistItem('Tanda Tangan', _ttdSaved),
        ],
      ),
    );
  }

  Widget _checklistItem(String label, bool done) {
    final color = done ? AppColors.success : AppColors.accentOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(done ? Icons.check : Icons.close, size: 13, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.black)),
        ],
      ),
    );
  }

  Widget _buildSection({required IconData icon, required String title, required Widget child, bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            if (required) ...[const SizedBox(width: 4), const Text('*', style: TextStyle(color: AppColors.error, fontSize: 16))],
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  // ── Photo section: type chips + thumbnail grid (watermark visible) ────
  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _photoTypeOptions.map((opt) {
            final selected = opt.value == _selectedPhotoType;
            return ChoiceChip(
              label: Text(opt.label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.primaryGreen)),
              selected: selected,
              selectedColor: AppColors.primaryGreen,
              backgroundColor: AppColors.primaryGreen.withOpacity(0.08),
              onSelected: (_) => setState(() => _selectedPhotoType = opt.value),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _existingPhotoUrls.length + _photos.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final lastIndex = _existingPhotoUrls.length + _photos.length;
            if (index == lastIndex) return _addPhotoTile();

            if (index < _existingPhotoUrls.length) {
              final url = _existingPhotoUrls[index];
              return GestureDetector(
                onTap: () => _previewNetworkPhoto(url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) => progress == null
                            ? child
                            : const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: AppColors.backgroundGrey, child: const Icon(Icons.broken_image, color: AppColors.grey)),
                      ),
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(Icons.zoom_in, color: Colors.white, size: 16, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                      ),
                    ],
                  ),
                ),
              );
            }

            final photo = _photos[index - _existingPhotoUrls.length];
            return GestureDetector(
              onTap: () => _previewPhoto(photo),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(photo.bytes, fit: BoxFit.cover),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        color: Colors.black.withOpacity(0.55),
                        child: Text(
                          photo.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(Icons.zoom_in, color: Colors.white, size: 16, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_hasAnyPhoto) ...[
          const SizedBox(height: 8),
          Text(
            'Foto yang sudah diupload tidak bisa dihapus dari sini — ambil foto baru kalau ada yang salah.',
            style: AppTextStyles.caption.copyWith(color: AppColors.grey),
          ),
        ],
      ],
    );
  }

  Widget _addPhotoTile() {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _isCapturingPhoto ? null : () => _showPhotoSourceSheet(),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundGrey,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: _isCapturingPhoto
            ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 26, color: AppColors.grey),
                  const SizedBox(height: 4),
                  Text('Tambah', style: AppTextStyles.caption.copyWith(color: AppColors.grey)),
                ],
              ),
      ),
    );
  }

  void _previewNetworkPhoto(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previewPhoto(_CapturedPhoto photo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.memory(photo.bytes, fit: BoxFit.contain),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                child: Text(photo.label, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primaryGreen),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _addPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primaryGreen),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(context);
                _addPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── GPS section ────────────────────────────────────────────
  Widget _buildGpsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hasGps ? AppColors.success : AppColors.borderColor, width: _hasGps ? 2 : 1),
      ),
      child: Row(
        children: [
          Icon(_hasGps ? Icons.location_on : Icons.location_off_outlined, color: _hasGps ? AppColors.success : AppColors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _hasGps ? '${_gpsLat!.toStringAsFixed(6)}, ${_gpsLng!.toStringAsFixed(6)}' : 'Lokasi belum diambil',
              style: AppTextStyles.bodySmall.copyWith(color: _hasGps ? AppColors.black : AppColors.grey),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _isCapturingGps ? null : _captureGps,
            icon: _isCapturingGps
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, size: 16),
            label: Text(_hasGps ? 'Perbarui' : 'Ambil GPS'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryGreen, side: const BorderSide(color: AppColors.primaryGreen)),
          ),
        ],
      ),
    );
  }

  // ── Signature section ────────────────────────────────────
  Widget _buildSignatureSection() {
    // Already saved (either from a previous session or earlier this one)
    // and the driver hasn't asked to redo it — show the real saved image
    // instead of an empty pad, so it's obvious nothing needs redoing.
    if (_ttdSaved && !_redrawingSignature) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success, width: 2),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: _freshSignatureBytes != null
                  ? Image.memory(_freshSignatureBytes!, fit: BoxFit.contain)
                  : _existingTtdUrl != null
                      ? Image.network(_existingTtdUrl!, fit: BoxFit.contain)
                      : const Icon(Icons.check_circle, color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                Text('Tanda tangan tersimpan', style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _redrawingSignature = true;
                    _signatureController.clear();
                    _hasDrawnSignature = false;
                    _freshSignatureBytes = null;
                  }),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Ganti'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Signature(controller: _signatureController, height: 180, backgroundColor: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                _signatureController.clear();
                setState(() => _hasDrawnSignature = false);
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Ulangi'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: (!_hasDrawnSignature || _isSavingTtd) ? null : _saveSignature,
              icon: _isSavingTtd
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 16),
              label: const Text('Simpan Tanda Tangan'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  // ── Qty Real section: Per Kemasan / Per Liter toggle ──────
  Widget _buildQtySection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasConversion)
            Row(
              children: [
                Expanded(
                  child: _qtyModeButton('Per $_satuanLabel', _isKemasanMode, () => setState(() => _isKemasanMode = true)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _qtyModeButton('Per Liter', !_isKemasanMode, () => setState(() => _isKemasanMode = false)),
                ),
              ],
            ),
          if (_hasConversion) const SizedBox(height: 10),
          if (_isKemasanMode || !_hasConversion)
            TextFormField(
              controller: _kemasanController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(_syncLiterFromKemasan),
              style: AppTextStyles.h5.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Masukkan qty',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixText: _satuanLabel,
              ),
            )
          else
            TextFormField(
              controller: _literController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: _onLiterChanged,
              style: AppTextStyles.h5.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Masukkan total liter',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixText: 'Liter',
              ),
            ),
          if (_hasConversion) ...[
            const SizedBox(height: 6),
            Text(
              _isKemasanMode
                  ? '= ${_literController.text.isEmpty ? '0' : _literController.text} Liter'
                  : '= ${_kemasanController.text.isEmpty ? '0' : _kemasanController.text} $_satuanLabel',
              style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Qty Plan: ${_currentDetail?.qtyOrder ?? '0'} $_satuanLabel'
            '${_hasConversion ? ' (= ${((double.tryParse(_currentDetail?.qtyOrder ?? '') ?? 0) * _totLiter).toStringAsFixed(0)} Liter)' : ''}',
            style: AppTextStyles.caption.copyWith(color: AppColors.grey),
          ),
        ],
      ),
    );
  }

  Widget _qtyModeButton(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryGreen : AppColors.backgroundGrey,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: active ? Colors.white : AppColors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  // ── Swipe-to-confirm ───────────────────────────────────────
  Widget _buildSwipeSection() {
    final ready = _canSubmit;
    return Column(
      children: [
        Text(
          _isBusy ? _busyMessage : 'Geser untuk menyelesaikan pickup',
          style: AppTextStyles.caption.copyWith(color: AppColors.grey),
        ),
        const SizedBox(height: 8),
        _SwipeToConfirm(
          enabled: ready && !_isBusy,
          busy: _isBusy,
          onConfirmed: _confirmAndSubmit,
        ),
        if (!ready) ...[
          const SizedBox(height: 8),
          Text(
            'Lengkapi foto, GPS & tanda tangan terlebih dahulu',
            style: AppTextStyles.caption.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

/// Slide-to-confirm button — mirrors the drag interaction in
/// application/views/surat-jalan/detail_form.php (.slide-container /
/// .slide-thumb), reimplemented as a Flutter gesture since there's no
/// equivalent widget in the existing dependency set.
class _SwipeToConfirm extends StatefulWidget {
  final bool enabled;
  final bool busy;
  final VoidCallback onConfirmed;

  const _SwipeToConfirm({required this.enabled, required this.busy, required this.onConfirmed});

  @override
  State<_SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<_SwipeToConfirm> {
  double _dragX = 0;
  static const _thumbSize = 46.0;
  static const _trackHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled || widget.busy ? 1 : 0.5,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxX = constraints.maxWidth - _thumbSize - 6;
          final dragX = _dragX.clamp(0, maxX).toDouble();
          return Container(
            height: _trackHeight,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(_trackHeight / 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Text sits in the space to the right of the thumb's resting
                // spot, not centered across the whole track — otherwise the
                // thumb covers its first few letters at rest (reported as
                // "GESER" reading as "SER" on a real device).
                Positioned(
                  left: _thumbSize + 12,
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      widget.busy ? 'MEMPROSES...' : 'GESER UNTUK SELESAI >>>',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: AppColors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: _dragX == 0 ? const Duration(milliseconds: 250) : Duration.zero,
                  curve: Curves.easeOut,
                  left: 3 + dragX,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (widget.enabled && !widget.busy)
                        ? (details) => setState(() => _dragX += details.delta.dx)
                        : null,
                    onHorizontalDragEnd: (widget.enabled && !widget.busy)
                        ? (details) {
                            if (dragX >= maxX * 0.85) {
                              widget.onConfirmed();
                            }
                            setState(() => _dragX = 0);
                          }
                        : null,
                    child: Container(
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: widget.busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
