import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/tms/settlement_model.dart';
import '../../services/tms/tms_settlement_service.dart';
import '../../utils/image_compress_utils.dart';

class DriverSettlementFormScreen extends StatefulWidget {
  final int calculationId;
  final double plannedCost;

  const DriverSettlementFormScreen({
    super.key,
    required this.calculationId,
    required this.plannedCost,
  });

  @override
  State<DriverSettlementFormScreen> createState() => _DriverSettlementFormScreenState();
}

class _DriverSettlementFormScreenState extends State<DriverSettlementFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fuelController = TextEditingController(text: '0');
  final _parkingController = TextEditingController(text: '0');
  final _tollController = TextEditingController(text: '0');
  final _otherController = TextEditingController(text: '0');
  final _distanceController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  // Non-receipt expense
  bool _isNonReceipt = false;
  final _nonReceiptAmountController = TextEditingController(text: '0');
  final _nonReceiptReasonController = TextEditingController();

  List<SettlementItemEntry> _additionalItems = [];
  bool _isSubmitting = false;
  File? _receiptPhoto;

  double get _totalActual {
    final fuel = double.tryParse(_fuelController.text) ?? 0;
    final parking = double.tryParse(_parkingController.text) ?? 0;
    final toll = double.tryParse(_tollController.text) ?? 0;
    final other = double.tryParse(_otherController.text) ?? 0;
    final nonReceipt = _isNonReceipt ? (double.tryParse(_nonReceiptAmountController.text) ?? 0) : 0;

    double addItemsTotal = 0;
    for (var item in _additionalItems) {
      addItemsTotal += item.amount;
    }

    return fuel + parking + toll + other + nonReceipt + addItemsTotal;
  }

  double get _variance => widget.plannedCost - _totalActual;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked != null) {
      final compressed = await ImageCompressUtils.compressImage(File(picked.path));
      setState(() {
        _receiptPhoto = compressed;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isNonReceipt && _nonReceiptReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alasan pengeluaran tanpa nota wajib diisi!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await TmsSettlementService.submitSettlementBulk(
        calculationId: widget.calculationId,
        actualFuelCost: double.tryParse(_fuelController.text) ?? 0,
        actualParkingCost: double.tryParse(_parkingController.text) ?? 0,
        actualTollCost: double.tryParse(_tollController.text) ?? 0,
        actualDriverCost: 0,
        actualVehicleOperationalCost: 0,
        actualOtherCosts: double.tryParse(_otherController.text) ?? 0,
        actualNonReceiptCost: _isNonReceipt ? (double.tryParse(_nonReceiptAmountController.text) ?? 0) : 0,
        alasanNonReceipt: _isNonReceipt ? _nonReceiptReasonController.text : '',
        settlementNotes: _notesController.text,
        distanceTraveled: double.tryParse(_distanceController.text) ?? 0,
        items: _additionalItems,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pengajuan settlement uang jalan berhasil dikirim!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim settlement: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
          'Form Settlement Uang Jalan',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Card Uang Jalan Awal
            Card(
              color: AppColors.primaryGreen.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uang Jalan (Penyertaan)',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Target / Planned Cost',
                          style: TextStyle(color: AppColors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                    Text(
                      'Rp ${widget.plannedCost.toStringAsFixed(0)}',
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Rincian Biaya Operasional
            Text(
              'Biaya Operasional Realisasi (Rp)',
              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildNumberInput('Biaya BBM / Solar', _fuelController, Icons.local_gas_station),
            const SizedBox(height: 10),
            _buildNumberInput('Biaya Tol', _tollController, Icons.alt_route),
            const SizedBox(height: 10),
            _buildNumberInput('Biaya Parkir', _parkingController, Icons.local_parking),
            const SizedBox(height: 10),
            _buildNumberInput('Biaya Operasional Lainnya', _otherController, Icons.payments),
            const SizedBox(height: 10),
            _buildNumberInput('Jarak Tempuh (KM)', _distanceController, Icons.add_road),

            const SizedBox(height: 20),
            const Divider(),

            // Non-Receipt Checkbox
            SwitchListTile(
              title: const Text('Pengeluaran Tanpa Struk / Non-Receipt'),
              subtitle: const Text('Centang jika ada pengeluaran parkir liar / biaya tak terduga tanpa nota'),
              value: _isNonReceipt,
              activeColor: AppColors.accentOrange,
              onChanged: (val) {
                setState(() => _isNonReceipt = val);
              },
            ),

            if (_isNonReceipt) ...[
              const SizedBox(height: 10),
              _buildNumberInput('Nominal Non-Receipt (Rp)', _nonReceiptAmountController, Icons.money_off),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nonReceiptReasonController,
                decoration: const InputDecoration(
                  labelText: 'Alasan Tanpa Struk',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.comment),
                ),
                maxLines: 2,
              ),
            ],

            const SizedBox(height: 20),
            const Divider(),

            // Upload Foto Struk Kamera
            Text(
              'Foto Bukti Struk / Nota Physical',
              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.grey.withOpacity(0.4), style: BorderStyle.solid),
                ),
                child: _receiptPhoto != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(_receiptPhoto!, fit: BoxFit.cover, width: double.infinity),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 40, color: AppColors.primaryGreen),
                          SizedBox(height: 8),
                          Text('Ketuk untuk Ambil Foto Struk (Kamera)', style: TextStyle(color: AppColors.grey)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Catatan
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan Driver (Opsional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 24),

            // Summary Card
            Card(
              color: AppColors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Realisasi Pengeluaran:'),
                        Text(
                          'Rp ${_totalActual.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_variance >= 0 ? 'Sisa Uang Jalan (Kembali):' : 'Kekurangan Uang (Klaim Driver):'),
                        Text(
                          'Rp ${_variance.abs().toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _variance >= 0 ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Kirim Pengajuan Settlement',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberInput(String label, TextEditingController controller, IconData icon) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}
