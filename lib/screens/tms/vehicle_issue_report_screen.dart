import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../services/location_service.dart';
import '../../utils/image_compress_utils.dart';

class VehicleIssueReportScreen extends StatefulWidget {
  const VehicleIssueReportScreen({super.key});

  @override
  State<VehicleIssueReportScreen> createState() => _VehicleIssueReportScreenState();
}

class _VehicleIssueReportScreenState extends State<VehicleIssueReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _platController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedIssueType = 'Ban Bocor / Meletus';
  final List<String> _issueTypes = [
    'Ban Bocor / Meletus',
    'Mesin Mogok / Overheat',
    'Rem Aus / Bermasalah',
    'Kecelakaan / Terperosok',
    'Masalah Kelistrikan / Baterai',
    'Lainnya',
  ];

  File? _issuePhoto;
  bool _isLocating = true;
  double? _latitude;
  double? _longitude;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _getCurrentGps();
  }

  Future<void> _getCurrentGps() async {
    setState(() => _isLocating = true);
    final pos = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        if (pos != null) {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
        }
        _isLocating = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked != null) {
      final compressed = await ImageCompressUtils.compressImage(File(picked.path));
      setState(() {
        _issuePhoto = compressed;
      });
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    if (_issuePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto bukti kendala kendaraan wajib diambil!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1)); // Simulate network request

    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan kendala kendaraan berhasil dikirim ke tim TMS!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Laporan Kendala Kendaraan',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // GPS Location Card
            Card(
              color: AppColors.error.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.error, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lokasi GPS Darurat terkini:',
                            style: TextStyle(fontSize: 12, color: AppColors.grey),
                          ),
                          const SizedBox(height: 4),
                          _isLocating
                              ? const Text('Mencari posisi GPS...', style: TextStyle(fontWeight: FontWeight.bold))
                              : Text(
                                  _latitude != null
                                      ? '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'
                                      : 'GPS tidak terdeteksi',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppColors.error),
                      onPressed: _getCurrentGps,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nomor Plat Truk
            TextFormField(
              controller: _platController,
              decoration: const InputDecoration(
                labelText: 'Nomor Plat Kendaraan (mis. N 1234 AB)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_bus),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Nomor plat wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // Jenis Kendala Dropdown
            DropdownButtonFormField<String>(
              value: _selectedIssueType,
              decoration: const InputDecoration(
                labelText: 'Jenis Kendala',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning_amber),
              ),
              items: _issueTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedIssueType = v);
              },
            ),
            const SizedBox(height: 16),

            // Deskripsi Kendala
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Deskripsi Kendala Lapangan',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              validator: (val) => val == null || val.trim().isEmpty ? 'Deskripsi kendala wajib diisi' : null,
            ),
            const SizedBox(height: 20),

            // Upload Foto Kendala
            Text(
              'Foto Bukti Kendala Kendaraan',
              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.grey.withOpacity(0.4)),
                ),
                child: _issuePhoto != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(_issuePhoto!, fit: BoxFit.cover, width: double.infinity),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 44, color: AppColors.error),
                          SizedBox(height: 8),
                          Text('Ambil Foto Kondisi Kendaraan (Kamera)', style: TextStyle(color: AppColors.grey)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 28),

            // Submit Button
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Kirim Laporan Darurat',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
