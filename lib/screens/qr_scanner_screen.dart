import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isScanning = true;
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onQRViewCreated() {
    // TODO: Implement actual QR scanner
    // For now, simulate scanning after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (_isScanning && mounted) {
        _handleScanResult('PICKUP_LOC_001_WARUNG_BU_SARI');
      }
    });
  }

  void _handleScanResult(String result) {
    if (!_isScanning) return;

    setState(() {
      _isScanning = false;
    });
    _animationController.stop();

    // Parse QR result and show details
    _showScanResultDialog(result);
  }

  void _showScanResultDialog(String qrData) {
    // Parse QR code data (simulate parsing pickup location data)
    final locationData = _parseQRData(qrData);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    size: 40,
                    color: AppColors.primaryGreen,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'QR Code Terdeteksi!',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Informasi lokasi penjemputan berhasil dipindai',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Location Details Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              locationData['name'] ?? 'Unknown Location',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        locationData['address'] ?? 'No address',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.local_gas_station,
                            size: 14,
                            color: AppColors.accentOrange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Estimasi: ${locationData['volume']}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.accentOrange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _resetScanner();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.grey,
                      side: const BorderSide(color: AppColors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Scan Lagi',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context, locationData);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Tambahkan',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Map<String, String> _parseQRData(String qrData) {
    // Simulate parsing QR data
    // In real implementation, you would parse actual QR format
    return {
      'id': 'LOC_001',
      'name': 'Warung Bu Sari',
      'address': 'Jl. Soekarno Hatta No. 123, Malang',
      'volume': '5-8L',
      'contact': '081234567890',
      'category': 'Warung Makan',
    };
  }

  void _resetScanner() {
    setState(() {
      _isScanning = true;
    });
    _animationController.repeat(reverse: true);
    _onQRViewCreated(); // Restart scanning simulation
  }

  void _toggleFlash() {
    setState(() {
      _flashOn = !_flashOn;
    });
    // TODO: Implement actual flash toggle
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Scan QR Code',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _flashOn ? Icons.flash_on : Icons.flash_off,
              color: AppColors.white,
            ),
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview Placeholder
          Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.black,
            child: const Center(
              child: Text(
                'Camera Preview\n(Simulasi)',
                style: TextStyle(color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Scanning Overlay
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5)),
            child: Stack(
              children: [
                // Scanning Area
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primaryGreen,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // Corner indicators
                        ...List.generate(4, (index) {
                          return Positioned(
                            top: index < 2 ? 0 : null,
                            bottom: index >= 2 ? 0 : null,
                            left: index % 2 == 0 ? 0 : null,
                            right: index % 2 == 1 ? 0 : null,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen,
                                borderRadius: BorderRadius.only(
                                  topLeft: index == 0
                                      ? const Radius.circular(10)
                                      : Radius.zero,
                                  topRight: index == 1
                                      ? const Radius.circular(10)
                                      : Radius.zero,
                                  bottomLeft: index == 2
                                      ? const Radius.circular(10)
                                      : Radius.zero,
                                  bottomRight: index == 3
                                      ? const Radius.circular(10)
                                      : Radius.zero,
                                ),
                              ),
                            ),
                          );
                        }),

                        // Scanning Line Animation
                        if (_isScanning)
                          AnimatedBuilder(
                            animation: _animation,
                            builder: (context, child) {
                              return Positioned(
                                left: 10,
                                right: 10,
                                top: 10 + (230 * _animation.value),
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryGreen
                                            .withOpacity(0.5),
                                        blurRadius: 5,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // Instructions
                Positioned(
                  bottom: 120,
                  left: 20,
                  right: 20,
                  child: Column(
                    children: [
                      if (_isScanning) ...[
                        Text(
                          'Arahkan kamera ke QR Code',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pastikan QR Code berada dalam frame',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        Text(
                          'Memproses hasil scan...',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),

                // Manual Input Button
                Positioned(
                  bottom: 40,
                  left: 20,
                  right: 20,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Show manual input dialog
                      _showManualInputDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.white.withOpacity(0.1),
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.white),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.keyboard),
                    label: Text(
                      'Input Manual',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showManualInputDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Input QR Code Manual',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Masukkan kode QR atau ID lokasi',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Contoh: LOC_001 atau WARUNG_BU_SARI',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryGreen),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                _handleScanResult(controller.text.toUpperCase());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Proses'),
          ),
        ],
      ),
    );
  }
}
