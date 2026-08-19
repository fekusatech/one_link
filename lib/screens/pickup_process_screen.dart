import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/surat_jalan.dart';
import '../services/surat_jalan_service.dart';

class PickupProcessScreen extends StatefulWidget {
  final SuratJalan? suratJalan;
  final int? supplierIndex;

  const PickupProcessScreen({super.key, this.suratJalan, this.supplierIndex});

  @override
  State<PickupProcessScreen> createState() => _PickupProcessScreenState();
}

class _PickupProcessScreenState extends State<PickupProcessScreen> {
  final TextEditingController _volumeController = TextEditingController(text: '0');
  bool _isSubmitting = false;
  String _loadingMessage = 'Mengirim data...';

  // Photo
  File? _capturedPhoto;
  final ImagePicker _picker = ImagePicker();

  // Signature
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: AppColors.primaryGreen,
    exportBackgroundColor: Colors.white,
  );
  bool _hasSigned = false;

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

  @override
  void initState() {
    super.initState();
    _signatureController.addListener(() {
      if (mounted) setState(() => _hasSigned = _signatureController.isNotEmpty);
    });
    // Pre-fill volume from order qty
    final qtyOrder = _currentDetail?.qtyOrder ?? '0';
    _volumeController.text = qtyOrder;
  }

  @override
  void dispose() {
    _volumeController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  // ── Camera ───────────────────────────────────────────────
  Future<void> _takePicture() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (photo != null) {
      setState(() => _capturedPhoto = File(photo.path));
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (photo != null) {
      setState(() => _capturedPhoto = File(photo.path));
    }
  }

  // ── Signature export ─────────────────────────────────────
  Future<File?> _exportSignatureAsFile() async {
    final Uint8List? data = await _signatureController.toPngBytes();
    if (data == null) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(data);
    return file;
  }

  // ── Submit ───────────────────────────────────────────────
  bool get _canSubmit {
    final volume = double.tryParse(_volumeController.text) ?? 0;
    return volume > 0 && _capturedPhoto != null && _hasSigned;
  }

  Future<void> _submitPickup() async {
    if (!_canSubmit) {
      _showValidationError();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _loadingMessage = 'Mengekspor data...';
    });

    try {
      if (detailId.isEmpty) throw Exception('Detail ID tidak ditemukan');

      // 1. Export signature to Base64
      setState(() => _loadingMessage = 'Mengompres tanda tangan...');
      final Uint8List? sigBytes = await _signatureController.toPngBytes();
      if (sigBytes == null) throw Exception('Gagal memproses tanda tangan');
      final String sigBase64 = base64Encode(sigBytes);

      // 2. Export photo to Base64
      setState(() => _loadingMessage = 'Mengompres foto bukti...');
      final Uint8List photoBytes = await _capturedPhoto!.readAsBytes();
      final String photoBase64 = base64Encode(photoBytes);

      // 3. Get GPS Location (optional but recommended)
      double? lat, lng;
      try {
        setState(() => _loadingMessage = 'Mengambil lokasi GPS...');
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (gpsError) {
        print('⚠️ GPS Error (skipped): $gpsError');
      }

      final dId = int.parse(detailId);

      // STEP 1: Save TTD
      setState(() => _loadingMessage = 'Menyimpan tanda tangan (1/3)...');
      final ttdOk = await SuratJalanService.saveSignatureApi(
        detailId: dId,
        ttdBase64: sigBase64,
      );
      if (!ttdOk) throw Exception('Gagal menyimpan tanda tangan di server');

      // STEP 2: Save Photo
      setState(() => _loadingMessage = 'Mengupload foto bukti (2/3)...');
      final photoOk = await SuratJalanService.savePhotoApi(
        detailId: dId,
        photoBase64: photoBase64,
        lat: lat,
        lng: lng,
      );
      if (!photoOk) throw Exception('Gagal mengupload foto ke server');

      // STEP 3: Update Status
      setState(() => _loadingMessage = 'Memperbarui status selesai (3/3)...');
      final statusOk = await SuratJalanService.updateStatusApi(
        detailId: dId,
        status: 'done',
        qtyReal: _volumeController.text,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (statusOk) {
          _showSuccessDialog();
        } else {
          _showErrorSnackbar('Gagal memperbarui status akhir.');
        }
      }
    } catch (e) {
      print('❌ PickupProcess Error: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showErrorSnackbar(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _showValidationError() {
    final msgs = <String>[];
    final volume = double.tryParse(_volumeController.text) ?? 0;
    if (volume <= 0) msgs.add('• Masukkan volume yang valid');
    if (_capturedPhoto == null) msgs.add('• Foto bukti belum diambil');
    if (!_hasSigned) msgs.add('• Tanda tangan belum diisi');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lengkapi data berikut:\n${msgs.join('\n')}'),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
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
      barrierDismissible: !_isSubmitting,
      builder: (context) => AlertDialog(
        title: Text(
          'Batalkan Penjemputan',
          style: AppTextStyles.h5.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan alasan pembatalan untuk $supplierName:',
              style: AppTextStyles.bodySmall,
            ),
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
              Navigator.pop(context); // Close dialog
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
      _isSubmitting = true;
      _loadingMessage = 'Membatalkan penjemputan...';
    });
    try {
      final success = await SuratJalanService.updateStatusApi(
        detailId: int.parse(detailId),
        status: 'cancel',
        reason: reason,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (success) {
          _showCancelSuccessDialog(reason);
        } else {
          _showErrorSnackbar('Gagal membatalkan penjemputan.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showErrorSnackbar(e.toString().replaceAll('Exception: ', ''));
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
              style: AppTextStyles.h5.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Alasan: $reason',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pop(); // back to nav
              Navigator.of(context).pop(); // back to dashboard
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
              style: AppTextStyles.h5.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Volume: ${_volumeController.text} liter\nSupplier: $supplierName',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pop(); // back to nav
              Navigator.of(context).pop(); // back to dashboard
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
          style: AppTextStyles.h5.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryGreen),
        actions: [
          if (supplierStatus != 'done' && 
              supplierStatus != 'cancelled' && 
              supplierStatus != 'cancel')
            TextButton.icon(
              onPressed: _isSubmitting ? null : _showCancelDialog,
              icon: Icon(Icons.cancel_outlined, color: AppColors.error, size: 18),
              label: Text(
                'Batalkan',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // Volume
                  _buildSection(
                    icon: Icons.local_drink,
                    title: 'Volume Diterima (Liter)',
                    child: _buildVolumeInput(),
                  ),
                  const SizedBox(height: 20),

                  // Photo
                  _buildSection(
                    icon: Icons.camera_alt,
                    title: 'Foto Bukti Penjemputan',
                    required: true,
                    child: _buildPhotoCapture(),
                  ),
                  const SizedBox(height: 20),

                  // Signature
                  _buildSection(
                    icon: Icons.draw,
                    title: 'Tanda Tangan Pemilik',
                    required: true,
                    child: _buildSignaturePad(),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Bottom submit button
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            supplierName,
            style: AppTextStyles.h5.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            suratJalanKode,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
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
                Text(
                  'Order: ${_currentDetail!.qtyOrder} ${_currentDetail!.satuan}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
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
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text('*', style: TextStyle(color: AppColors.error, fontSize: 16)),
            ]
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildVolumeInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: TextFormField(
        controller: _volumeController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: AppTextStyles.h5.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: 'Masukkan volume',
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixText: 'liter',
          suffixStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildPhotoCapture() {
    return Column(
      children: [
        // Preview or placeholder
        GestureDetector(
          onTap: _takePicture,
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: _capturedPhoto != null ? Colors.transparent : AppColors.backgroundGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _capturedPhoto != null ? AppColors.primaryGreen : AppColors.borderColor,
                width: _capturedPhoto != null ? 2 : 1,
              ),
            ),
            child: _capturedPhoto != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.file(_capturedPhoto!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 48, color: AppColors.grey),
                      const SizedBox(height: 8),
                      Text(
                        'Ketuk untuk ambil foto',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _takePicture,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Kamera'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library, size: 18),
                label: const Text('Galeri'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (_capturedPhoto != null) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() => _capturedPhoto = null),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Hapus'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSignaturePad() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasSigned ? AppColors.primaryGreen : AppColors.borderColor,
              width: _hasSigned ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Column(
              children: [
                // Canvas
                Signature(
                  controller: _signatureController,
                  height: 180,
                  backgroundColor: Colors.white,
                ),
                // Divider + hint
                Container(
                  color: AppColors.backgroundGrey,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        _hasSigned ? Icons.check_circle : Icons.gesture,
                        size: 16,
                        color: _hasSigned ? AppColors.success : AppColors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _hasSigned ? 'Tanda tangan diterima' : 'Tanda tangan di area di atas',
                        style: AppTextStyles.caption.copyWith(
                          color: _hasSigned ? AppColors.success : AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              _signatureController.clear();
              setState(() => _hasSigned = false);
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Ulangi Tanda Tangan'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final ready = _canSubmit;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitPickup,
            style: ElevatedButton.styleFrom(
              backgroundColor: ready ? AppColors.primaryGreen : AppColors.grey,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: ready ? 4 : 0,
            ),
            child: _isSubmitting
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(_loadingMessage),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(ready ? Icons.check_circle : Icons.lock, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        ready ? 'Selesaikan Penjemputan' : 'Lengkapi semua data (*)',
                        style: AppTextStyles.button,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
