import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/surat_jalan.dart';

class PickupProcessScreen extends StatefulWidget {
  final SuratJalan? suratJalan;
  final int? supplierIndex;

  const PickupProcessScreen({super.key, this.suratJalan, this.supplierIndex});

  @override
  State<PickupProcessScreen> createState() => _PickupProcessScreenState();
}

class _PickupProcessScreenState extends State<PickupProcessScreen> {
  final TextEditingController _volumeController = TextEditingController(
    text: '0',
  );
  bool _isCompleting = false;

  // Dynamic supplier data
  String get supplierName {
    if (widget.suratJalan != null &&
        widget.supplierIndex != null &&
        widget.supplierIndex! < widget.suratJalan!.suratJalanDetail.length) {
      return widget
          .suratJalan!
          .suratJalanDetail[widget.supplierIndex!]
          .supplierName;
    }
    return 'Supplier Name';
  }

  String get supplierStatus {
    if (widget.suratJalan != null &&
        widget.supplierIndex != null &&
        widget.supplierIndex! < widget.suratJalan!.suratJalanDetail.length) {
      return widget.suratJalan!.suratJalanDetail[widget.supplierIndex!].status;
    }
    return 'pending';
  }

  String get suratJalanKode {
    return widget.suratJalan?.kode ?? 'SJ-XXXX';
  }

  @override
  void dispose() {
    _volumeController.dispose();
    super.dispose();
  }

  void _onSlideComplete() {
    setState(() {
      _isCompleting = true;
    });

    // Show completion process
    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Memproses pickup...',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );

    // Simulate API call
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop(); // Close loading dialog
      _showSuccessDialog();
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 16),
              Text(
                'Pickup Berhasil!',
                style: AppTextStyles.h5.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
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
                Navigator.of(context).pop(); // Close success dialog
                Navigator.of(context).pop(); // Go back to navigation
                // Update status would be done here via API
              },
              child: const Text(
                'Selesai',
                style: TextStyle(color: AppColors.primaryGreen),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Proses Penjemputan',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header - Store Name
                  Text(
                    supplierName,
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Surat Jalan info
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Surat Jalan: $suratJalanKode',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Status indicator
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        supplierStatus == 'done'
                            ? Icons.check_circle
                            : supplierStatus == 'pickup'
                            ? Icons.schedule
                            : Icons.pending,
                        size: 16,
                        color: supplierStatus == 'done'
                            ? Colors.green
                            : supplierStatus == 'pickup'
                            ? AppColors.accentOrange
                            : AppColors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Status: ${supplierStatus.toUpperCase()}',
                        style: AppTextStyles.caption.copyWith(
                          color: supplierStatus == 'done'
                              ? Colors.green
                              : supplierStatus == 'pickup'
                              ? AppColors.accentOrange
                              : AppColors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Volume Input Section
                  Text(
                    'Volume Diterima (Liter/Kg)',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _volumeController,
                    keyboardType: TextInputType.number,
                    style: AppTextStyles.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Masukkan volume',
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.grey.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.grey.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primaryGreen,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Proof Section
                  Text(
                    'Proof',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Camera capture container
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            // TODO: Implement camera functionality
                          },
                          child: Container(
                            height: 140,
                            decoration: BoxDecoration(
                              color: AppColors.lightGrey,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.grey.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt,
                                  size: 40,
                                  color: AppColors.grey,
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: Text(
                                    'Ambil Foto Bukti\n(Jerigen/Wadah)',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Jerrycan placeholder image
                      Expanded(
                        child: Container(
                          height: 140,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_drink,
                                size: 60,
                                color: AppColors.accentOrange,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Jerigen',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Signature Section
                  Text(
                    'Tanda Tangan',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      // TODO: Open signature pad
                    },
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.grey.withOpacity(0.5),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Dashed border effect
                          CustomPaint(
                            size: Size.infinite,
                            painter: DashedBorderPainter(),
                          ),

                          // Signature content
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Dummy signature curve
                                CustomPaint(
                                  size: const Size(120, 50),
                                  painter: SignaturePainter(),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tanda Tangan di sini\n(Pemilik Toko)',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 100), // Space for bottom slider
                ],
              ),
            ),
          ),

          // Bottom Slider Button
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SlideToConfirm(
              onConfirm: _onSlideComplete,
              isCompleting: _isCompleting,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for dashed border
class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.grey.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 5.0;

    // Top border
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }

    // Bottom border
    startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height),
        Offset(startX + dashWidth, size.height),
        paint,
      );
      startX += dashWidth + dashSpace;
    }

    // Left border
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }

    // Right border
    startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width, startY),
        Offset(size.width, startY + dashWidth),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for dummy signature
class SignaturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryGreen.withOpacity(0.3)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(10, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.2,
      size.width * 0.5,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.8,
      size.width - 10,
      size.height * 0.4,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Slide to Confirm Widget
class SlideToConfirm extends StatefulWidget {
  final VoidCallback onConfirm;
  final bool isCompleting;

  const SlideToConfirm({
    super.key,
    required this.onConfirm,
    this.isCompleting = false,
  });

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _dragPosition = 0.0;
  double _maxDrag = 0.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _maxDrag = constraints.maxWidth - 80;
        final threshold = _maxDrag * 0.9;

        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.accentOrange,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            children: [
              // Background text
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'GESER UNTUK SELESAIKAN',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.double_arrow,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),

              // Sliding button
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                left: _dragPosition,
                top: 5,
                bottom: 5,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragPosition = (_dragPosition + details.delta.dx).clamp(
                        0.0,
                        _maxDrag,
                      );
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_dragPosition >= threshold) {
                      widget.onConfirm();
                    } else {
                      setState(() {
                        _dragPosition = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: 70,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: AppColors.accentOrange,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
