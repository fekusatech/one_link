import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/dropdown_models.dart';
import '../models/supplier_model.dart';
import '../services/api/supplier_api_service.dart';

Future<bool?> showQuickAddSupplierSheet(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _QuickAddSupplierSheet(),
    );

class _QuickAddSupplierSheet extends StatefulWidget {
  const _QuickAddSupplierSheet();

  @override
  State<_QuickAddSupplierSheet> createState() => _QuickAddSupplierSheetState();
}

class _QuickAddSupplierSheetState extends State<_QuickAddSupplierSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pic = TextEditingController();
  final _position = TextEditingController();
  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _address = TextEditingController();
  List<JenisSupplier> _types = const [];
  JenisSupplier? _type;
  bool _loading = true;
  bool _saving = false;
  bool _isIsccCertified = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pic.dispose();
    _position.dispose();
    _accountName.dispose();
    _accountNumber.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    final response = await SupplierApiService.getDropdownOptions();
    if (!mounted) return;
    final rows = response.data?['jenis_supplier'] as List? ?? const [];
    setState(() {
      _types = rows
          .whereType<Map>()
          .map((row) => JenisSupplier.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      _type = _types.isNotEmpty ? _types.first : null;
      _loading = false;
      if (!response.status) _error = response.message;
    });
  }

  Future<void> _save() async {
    if (_type == null ||
        _name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _pic.text.trim().isEmpty ||
        _position.text.trim().isEmpty ||
        _accountName.text.trim().isEmpty ||
        _accountNumber.text.trim().isEmpty) {
      setState(() => _error = 'Lengkapi semua data bertanda wajib.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final response = await SupplierApiService.createSupplier(
      Supplier(
        jenis: _type!.id.toString(),
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        karyawan: _pic.text.trim(),
        jabatan: _position.text.trim(),
        namaRek: _accountName.text.trim(),
        nomorRek: _accountNumber.text.trim(),
        alamat: _address.text.trim().isEmpty ? null : _address.text.trim(),
        isIsccCertified: _isIsccCertified,
      ),
    );
    if (!mounted) return;
    if (response.status) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = response.message;
      });
    }
  }

  InputDecoration _field(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _textField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _field(label),
    ),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tambah supplier',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              DropdownButtonFormField<JenisSupplier>(
                initialValue: _type,
                decoration: _field('Jenis supplier *'),
                items: _types
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type.name)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _type = value),
              ),
              const SizedBox(height: 12),
              _textField(_name, 'Nama supplier *'),
              _textField(
                _phone,
                'Nomor telepon *',
                keyboardType: TextInputType.phone,
              ),
              _textField(_pic, 'Nama PIC *'),
              _textField(_position, 'Jabatan PIC *'),
              _textField(_accountName, 'Nama rekening *'),
              _textField(
                _accountNumber,
                'Nomor rekening *',
                keyboardType: TextInputType.number,
              ),
              _textField(_address, 'Alamat (opsional)'),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('ISCC Certified'),
                subtitle: Text(_isIsccCertified ? 'Ya' : 'Tidak'),
                value: _isIsccCertified,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _isIsccCertified = value),
              ),
            ],
            if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading || _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_saving ? 'Menyimpan…' : 'Simpan supplier'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
