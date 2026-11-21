import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/dropdown_models.dart';
import '../../models/geographic_models.dart';
import '../../services/api/supplier_api_service.dart';
import '../../services/geu/reverse_geocoding_service.dart';
import '../../services/geu/visit_planner_service.dart';

T? _byId<T>(List<T> list, int Function(T) idOf, int? id) {
  if (id == null) return null;
  for (final item in list) {
    if (idOf(item) == id) return item;
  }
  return null;
}

String _normalizeRegionName(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

String _normalizeRegionAlias(String value) => _normalizeRegionName(value)
    .replaceAll(
      RegExp(r'\b(provinsi|province|kota|kabupaten|kab|city|regency)\b'),
      '',
    )
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

T? _byName<T>(List<T> list, String? Function(T) nameOf, String? name) {
  if (name == null || name.trim().isEmpty) return null;
  final normalized = _normalizeRegionName(name);
  final exactMatches = list
      .where((item) => _normalizeRegionName(nameOf(item) ?? '') == normalized)
      .toList();
  if (exactMatches.length == 1) return exactMatches.single;
  if (exactMatches.length > 1) return null;

  // Prefix-free matching is only safe when it identifies one master row.
  // For example, "Malang" alone must not choose arbitrarily between
  // "Kota Malang" and "Kabupaten Malang".
  final alias = _normalizeRegionAlias(name);
  final aliasMatches = list
      .where((item) => _normalizeRegionAlias(nameOf(item) ?? '') == alias)
      .toList();
  return aliasMatches.length == 1 ? aliasMatches.single : null;
}

void _showDialogErrorToast(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => Positioned(
      top: MediaQuery.viewPaddingOf(overlayContext).top + 12,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Material(
          color: const Color(0xFF303633),
          elevation: 14,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(seconds: 4)).then((_) {
    if (entry.mounted) entry.remove();
  });
}

/// Registers a prospect/scanned location as a real supplier and adds it to
/// today's mission. Shared by the map screen's "Daftarkan supplier" FAB and
/// by mission items that are still unregistered scanned places (supplier_id
/// 0) — those must be converted to a real supplier before check-in/WO
/// creation, since the backend requires a non-zero SupplierID for both.
Future<({int supplierId, String name})?> showRegisterSupplierDialog(
  BuildContext context, {
  required double latitude,
  required double longitude,
  String initialName = '',
  String initialAddress = '',
  String initialPhone = '',
}) async {
  List<BankOption> banks = const [];
  List<JenisSupplier> supplierTypes = const [];
  try {
    banks = await VisitPlannerService.getBanks();
  } catch (_) {
    // The optional account section remains usable after a later retry.
  }

  // Provinsi/Kota/Kecamatan are pre-selected from the same GPS-based lookup
  // RegisterProspect runs server-side, so the RO sees (and can correct) what
  // would otherwise be silently auto-detected on submit.
  List<Province> provinces = const [];
  List<City> cities = const [];
  List<District> districts = const [];
  Province? selectedProvince;
  City? selectedCity;
  District? selectedDistrict;
  var regionAutoDetected = false;
  var showManualRegion = false;
  var regionOptionsUnavailable = false;
  var loadingRegionOptions = false;
  var regionStatus = '';

  Future<void> loadRegionFromGps() async {
    try {
      final dropdowns = await SupplierApiService.getDropdownOptions();
      if (!dropdowns.status || dropdowns.data == null) {
        throw StateError('Dropdown wilayah tidak dapat dimuat.');
      }
      supplierTypes =
          (dropdowns.data!['jenis_supplier'] as List?)
              ?.map((e) => JenisSupplier.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [];
      provinces =
          (dropdowns.data!['provinces'] as List?)
              ?.map((e) => Province.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [];
      if (provinces.isEmpty) throw StateError('Daftar provinsi kosong.');

      DetectedRegion detected;
      try {
        detected = await VisitPlannerService.detectRegion(
          latitude: latitude,
          longitude: longitude,
        );
      } catch (_) {
        detected = const DetectedRegion();
      }
      final reverseGeocoded =
          await ReverseGeocodingService.resolveAdministrativeRegion(
            latitude,
            longitude,
          );
      final provinceName = reverseGeocoded.province?.trim().isNotEmpty == true
          ? reverseGeocoded.province
          : detected.provinsiName;
      selectedProvince =
          _byName(provinces, (p) => p.name, provinceName) ??
          _byId(provinces, (p) => p.id, detected.provinsiId);
      final provinceForCities = selectedProvince;
      if (provinceForCities != null) {
        final citiesRes = await SupplierApiService.getCities(
          provinceForCities.id,
        );
        if (citiesRes.status && citiesRes.data != null)
          cities = citiesRes.data!;
      }
      final cityName = reverseGeocoded.city?.trim().isNotEmpty == true
          ? reverseGeocoded.city
          : detected.kotaName;
      selectedCity =
          _byName(cities, (c) => c.name, cityName) ??
          _byId(cities, (c) => c.id, detected.kotaId);
      final cityForDistricts = selectedCity;
      if (cityForDistricts != null) {
        final districtsRes = await SupplierApiService.getDistricts(
          cityForDistricts.id,
        );
        if (districtsRes.status && districtsRes.data != null) {
          districts = districtsRes.data!;
        }
        final districtName = reverseGeocoded.district?.trim().isNotEmpty == true
            ? reverseGeocoded.district
            : detected.kecamatanName;
        selectedDistrict =
            _byName(districts, (d) => d.name, districtName) ??
            _byId(districts, (d) => d.id, detected.kecamatanId);
      }
      regionAutoDetected =
          selectedProvince != null &&
          selectedCity != null &&
          selectedDistrict != null;
      showManualRegion = !regionAutoDetected;
      regionOptionsUnavailable = false;
      regionStatus = regionAutoDetected
          ? 'Wilayah terdeteksi dari GPS. Jika tidak sesuai alamat, ubah pilihan di daftar.'
          : 'Wilayah belum lengkap. Pilih Provinsi, Kota, dan Kecamatan secara manual.';
    } catch (_) {
      regionAutoDetected = false;
      showManualRegion = true;
      regionOptionsUnavailable = provinces.isEmpty;
      regionStatus = regionOptionsUnavailable
          ? 'Daftar wilayah gagal dimuat. Coba muat ulang untuk memilih manual.'
          : 'Wilayah belum terdeteksi lengkap. Pilih manual dari daftar.';
    }
  }

  await loadRegionFromGps();
  if (!context.mounted) return null;

  final name = TextEditingController(text: initialName);
  final address = TextEditingController(text: initialAddress);
  final employee = TextEditingController();
  final position = TextEditingController();
  final phone = TextEditingController(text: initialPhone);
  final accountName = TextEditingController();
  final accountNumber = TextEditingController();
  var submitting = false;
  var isIsccCertified = false;
  var validatingAccount = false;
  var loadingCities = false;
  var loadingDistricts = false;
  int? registeredSupplierId;
  BankOption? selectedBank;
  JenisSupplier? selectedSupplierType;
  String? accountValidationMessage;
  ({int supplierId, String name})? result;

  await showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.black54,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> onProvinceChanged(Province? province) async {
          setDialogState(() {
            selectedProvince = province;
            selectedCity = null;
            selectedDistrict = null;
            cities = const [];
            districts = const [];
            loadingCities = province != null;
            regionAutoDetected = false;
            regionStatus = 'Wilayah diubah manual. Pastikan sesuai alamat.';
          });
          if (province == null) return;
          try {
            final res = await SupplierApiService.getCities(province.id);
            if (res.status && res.data != null) {
              cities = res.data!;
            } else {
              regionStatus =
                  'Daftar kabupaten/kota gagal dimuat. Coba muat ulang.';
            }
          } catch (_) {
            regionStatus =
                'Daftar kabupaten/kota gagal dimuat. Coba muat ulang.';
          } finally {
            if (dialogContext.mounted)
              setDialogState(() => loadingCities = false);
          }
        }

        Future<void> onCityChanged(City? city) async {
          setDialogState(() {
            selectedCity = city;
            selectedDistrict = null;
            districts = const [];
            loadingDistricts = city != null;
            regionAutoDetected = false;
            regionStatus = 'Wilayah diubah manual. Pastikan sesuai alamat.';
          });
          if (city == null) return;
          try {
            final res = await SupplierApiService.getDistricts(city.id);
            if (res.status && res.data != null) {
              districts = res.data!;
            } else {
              regionStatus = 'Daftar kecamatan gagal dimuat. Coba muat ulang.';
            }
          } catch (_) {
            regionStatus = 'Daftar kecamatan gagal dimuat. Coba muat ulang.';
          } finally {
            if (dialogContext.mounted)
              setDialogState(() => loadingDistricts = false);
          }
        }

        Future<void> retryRegionLoading() async {
          setDialogState(() => loadingRegionOptions = true);
          await loadRegionFromGps();
          if (dialogContext.mounted) {
            setDialogState(() => loadingRegionOptions = false);
          }
        }

        Future<void> submit() async {
          if (submitting) return;
          if (name.text.trim().isEmpty ||
              selectedSupplierType == null ||
              employee.text.trim().isEmpty ||
              position.text.trim().isEmpty)
            return;
          setDialogState(() => submitting = true);
          try {
            final supplierId = registeredSupplierId ??=
                await VisitPlannerService.registerProspect(
                  name: name.text.trim(),
                  jenis: selectedSupplierType!.name,
                  address: address.text.trim(),
                  phone: phone.text.trim(),
                  latitude: latitude,
                  longitude: longitude,
                  employeeName: employee.text.trim(),
                  employeePosition: position.text.trim(),
                  accountName: accountName.text.trim(),
                  accountNumber: accountNumber.text.trim(),
                  bankId: selectedBank?.id,
                  provinsiId: selectedProvince?.id,
                  kotaId: selectedCity?.id,
                  kecamatanId: selectedDistrict?.id,
                  isIsccCertified: isIsccCertified,
                );
            await VisitPlannerService.addSupplierToMission(supplierId);
            result = (supplierId: supplierId, name: name.text.trim());
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
          } catch (error) {
            if (dialogContext.mounted) {
              final rawMessage = error.toString();
              final message =
                  rawMessage.toLowerCase().contains('duplicate supplier')
                  ? 'Supplier dengan nama ini sudah terdaftar.'
                  : rawMessage;
              _showDialogErrorToast(dialogContext, message);
            }
          } finally {
            if (dialogContext.mounted) setDialogState(() => submitting = false);
          }
        }

        Widget supplierTypeField() => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _SearchableDropdownField<JenisSupplier>(
            label: 'Jenis Supplier *',
            selectedValue: selectedSupplierType,
            options: supplierTypes,
            itemLabel: (type) => type.name,
            enabled: !submitting && supplierTypes.isNotEmpty,
            onSelected: (type) =>
                setDialogState(() => selectedSupplierType = type),
          ),
        );

        final regionComplete =
            selectedProvince != null &&
            selectedCity != null &&
            selectedDistrict != null;

        final useTwoColumns = MediaQuery.sizeOf(context).width >= 380;
        return Dialog.fullscreen(
          backgroundColor: Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Kembali',
                        onPressed: submitting
                            ? null
                            : () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Expanded(
                        child: Text(
                          'Daftarkan supplier',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lokasi: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (useTwoColumns)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _field(name, 'Nama Supplier *')),
                              const SizedBox(width: 10),
                              Expanded(child: supplierTypeField()),
                            ],
                          )
                        else ...[
                          _field(name, 'Nama Supplier *'),
                          supplierTypeField(),
                        ],
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('ISCC Certified'),
                          subtitle: Text(isIsccCertified ? 'Ya' : 'Tidak'),
                          value: isIsccCertified,
                          onChanged: submitting
                              ? null
                              : (value) => setDialogState(
                                  () => isIsccCertified = value,
                                ),
                        ),
                        _field(address, 'Alamat', maxLines: 2),
                        const SizedBox(height: 16),
                        _dialogSectionHeader(Icons.map_outlined, 'Wilayah'),
                        if (regionComplete && !showManualRegion)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${selectedDistrict!.name}, ${selectedCity!.name}, ${selectedProvince!.name}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => setDialogState(() {
                                    showManualRegion = true;
                                    regionStatus =
                                        'Pilih wilayah yang sesuai dengan alamat.';
                                  }),
                                  child: const Text('Ubah'),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              regionStatus.isEmpty
                                  ? 'Pilih wilayah yang sesuai dengan alamat supplier.'
                                  : regionStatus,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (regionOptionsUnavailable)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: loadingRegionOptions
                                    ? null
                                    : retryRegionLoading,
                                icon: loadingRegionOptions
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh),
                                label: const Text('Muat ulang daftar wilayah'),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _SearchableDropdownField<Province>(
                              label: 'Provinsi',
                              selectedValue: selectedProvince,
                              options: provinces,
                              itemLabel: (province) => province.name,
                              enabled: !submitting && provinces.isNotEmpty,
                              onSelected: onProvinceChanged,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _SearchableDropdownField<City>(
                              label: 'Kabupaten/Kota',
                              selectedValue: selectedCity,
                              options: cities,
                              itemLabel: (city) => city.name,
                              enabled:
                                  !submitting &&
                                  selectedProvince != null &&
                                  cities.isNotEmpty,
                              suffixIcon: loadingCities
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : selectedProvince != null && cities.isEmpty
                                  ? IconButton(
                                      tooltip: 'Muat ulang daftar kota',
                                      onPressed: () =>
                                          onProvinceChanged(selectedProvince),
                                      icon: const Icon(Icons.refresh),
                                    )
                                  : null,
                              onSelected: onCityChanged,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _SearchableDropdownField<District>(
                              label: 'Kecamatan',
                              selectedValue: selectedDistrict,
                              options: districts,
                              itemLabel: (district) => district.name,
                              enabled:
                                  !submitting &&
                                  selectedCity != null &&
                                  districts.isNotEmpty,
                              suffixIcon: loadingDistricts
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : selectedCity != null && districts.isEmpty
                                  ? IconButton(
                                      tooltip: 'Muat ulang daftar kecamatan',
                                      onPressed: () =>
                                          onCityChanged(selectedCity),
                                      icon: const Icon(Icons.refresh),
                                    )
                                  : null,
                              onSelected: (district) => setDialogState(() {
                                selectedDistrict = district;
                                regionAutoDetected = false;
                                regionStatus =
                                    'Wilayah diubah manual. Pastikan sesuai alamat.';
                              }),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _dialogSectionHeader(
                          Icons.contact_phone_outlined,
                          'Kontak PIC',
                        ),
                        if (useTwoColumns)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _field(employee, 'Nama PIC *')),
                              const SizedBox(width: 10),
                              Expanded(child: _field(position, 'Jabatan *')),
                            ],
                          )
                        else ...[
                          _field(employee, 'Nama PIC *'),
                          _field(position, 'Jabatan *'),
                        ],
                        _field(
                          phone,
                          'Nomor Telepon',
                          keyboard: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          leading: const Icon(
                            Icons.account_balance_outlined,
                            color: AppColors.primaryGreen,
                          ),
                          title: const Text(
                            'Rekening (opsional)',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          children: [
                            if (useTwoColumns)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _field(accountName, 'Nama pemilik'),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _field(
                                      accountNumber,
                                      'Nomor rekening',
                                      keyboard: TextInputType.number,
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _field(accountName, 'Nama pemilik'),
                              _field(
                                accountNumber,
                                'Nomor rekening',
                                keyboard: TextInputType.number,
                              ),
                            ],
                            const SizedBox(height: 10),
                            _SearchableDropdownField<BankOption>(
                              label: 'Pilih Bank',
                              selectedValue: selectedBank,
                              options: banks,
                              itemLabel: (bank) =>
                                  '${bank.name} (${bank.code})',
                              enabled:
                                  !submitting &&
                                  !validatingAccount &&
                                  banks.isNotEmpty,
                              onSelected: (bank) => setDialogState(() {
                                selectedBank = bank;
                                accountValidationMessage = null;
                              }),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: validatingAccount
                                  ? null
                                  : () async {
                                      if (accountNumber.text.trim().isEmpty ||
                                          selectedBank == null) {
                                        setDialogState(
                                          () => accountValidationMessage =
                                              'Isi nomor rekening dan pilih bank terlebih dahulu.',
                                        );
                                        return;
                                      }
                                      setDialogState(() {
                                        validatingAccount = true;
                                        accountValidationMessage = null;
                                      });
                                      try {
                                        final validation =
                                            await VisitPlannerService.validateBankAccount(
                                              accountNumber: accountNumber.text
                                                  .trim(),
                                              bankCode: selectedBank!.code,
                                              accountName: accountName.text
                                                  .trim(),
                                            );
                                        if (!dialogContext.mounted) return;
                                        setDialogState(
                                          () => accountValidationMessage =
                                              validation.valid
                                              ? '✓ ${validation.accountName}'
                                              : '✗ Rekening tidak valid.',
                                        );
                                      } catch (error) {
                                        if (dialogContext.mounted)
                                          setDialogState(
                                            () => accountValidationMessage =
                                                '✗ ${error.toString()}',
                                          );
                                      } finally {
                                        if (dialogContext.mounted)
                                          setDialogState(
                                            () => validatingAccount = false,
                                          );
                                      }
                                    },
                              icon: validatingAccount
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.verified_outlined),
                              label: Text(
                                validatingAccount
                                    ? 'Memvalidasi...'
                                    : 'Validasi rekening',
                              ),
                            ),
                            if (accountValidationMessage != null)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    accountValidationMessage!,
                                    style: TextStyle(
                                      color:
                                          accountValidationMessage!.startsWith(
                                            '✓',
                                          )
                                          ? AppColors.success
                                          : AppColors.error,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: submitting
                              ? null
                              : () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: submitting || selectedSupplierType == null
                              ? null
                              : submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: AppColors.primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            submitting ? 'Menyimpan...' : 'Tambah ke Mission',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  name.dispose();
  address.dispose();
  employee.dispose();
  position.dispose();
  phone.dispose();
  accountName.dispose();
  accountNumber.dispose();
  return result;
}

class _SearchableDropdownField<T> extends StatelessWidget {
  const _SearchableDropdownField({
    required this.label,
    required this.selectedValue,
    required this.options,
    required this.itemLabel,
    required this.enabled,
    required this.onSelected,
    this.suffixIcon,
  });

  final String label;
  final T? selectedValue;
  final List<T> options;
  final String Function(T) itemLabel;
  final bool enabled;
  final ValueChanged<T> onSelected;
  final Widget? suffixIcon;

  String get _plainLabel => label.replaceAll('*', '').trim();

  @override
  Widget build(BuildContext context) {
    final selectedText = selectedValue == null
        ? null
        : itemLabel(selectedValue as T);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.primaryGreen.withOpacity(.2)),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label${selectedText == null ? '' : ', $selectedText'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () async {
                  final selected = await showModalBottomSheet<T>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    useRootNavigator: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (sheetContext) => FractionallySizedBox(
                      heightFactor: .92,
                      child: _SearchableOptionsSheet<T>(
                        label: _plainLabel,
                        options: options,
                        itemLabel: itemLabel,
                        selectedValue: selectedValue,
                      ),
                    ),
                  );
                  if (selected != null) onSelected(selected);
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            // The child always contains either the selected value or a hint.
            // Marking it empty makes InputDecorator center the label over that
            // text, which causes the two strings to overlap on compact phones.
            isEmpty: false,
            decoration: InputDecoration(
              labelText: label,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabled: enabled,
              border: border,
              enabledBorder: border,
              disabledBorder: border,
              suffixIcon:
                  suffixIcon ??
                  Icon(
                    Icons.arrow_drop_down,
                    color: enabled ? AppColors.textSecondary : Colors.grey,
                  ),
            ),
            child: Text(
              selectedText ?? 'Pilih ${_plainLabel.toLowerCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selectedText == null
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchableOptionsSheet<T> extends StatefulWidget {
  const _SearchableOptionsSheet({
    required this.label,
    required this.options,
    required this.itemLabel,
    required this.selectedValue,
  });

  final String label;
  final List<T> options;
  final String Function(T) itemLabel;
  final T? selectedValue;

  @override
  State<_SearchableOptionsSheet<T>> createState() =>
      _SearchableOptionsSheetState<T>();
}

class _SearchableOptionsSheetState<T>
    extends State<_SearchableOptionsSheet<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filteredOptions = query.isEmpty
        ? widget.options
        : widget.options
              .where(
                (option) =>
                    widget.itemLabel(option).toLowerCase().contains(query),
              )
              .toList(growable: false);

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6DAD8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pilih ${widget.label}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Cari ${widget.label.toLowerCase()}...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: const Color(0xFFF5F7F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: filteredOptions.isEmpty
              ? Center(
                  child: Text(
                    query.isEmpty
                        ? 'Belum ada pilihan.'
                        : 'Tidak ada hasil untuk “${_query.trim()}”.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: filteredOptions.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 20, endIndent: 20),
                  itemBuilder: (context, index) {
                    final option = filteredOptions[index];
                    final isSelected = option == widget.selectedValue;
                    return ListTile(
                      minVerticalPadding: 10,
                      title: Text(
                        widget.itemLabel(option),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primaryGreen,
                      trailing: isSelected
                          ? const Icon(
                              Icons.check,
                              color: AppColors.primaryGreen,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, option),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

Widget _field(
  TextEditingController controller,
  String label, {
  int maxLines = 1,
  TextInputType? keyboard,
}) => Padding(
  padding: const EdgeInsets.only(top: 10),
  child: TextField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboard,
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primaryGreen.withOpacity(0.18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primaryGreen.withOpacity(0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
      ),
    ),
  ),
);

Widget _dialogSectionHeader(IconData icon, String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        Icon(icon, size: 17, color: AppColors.primaryGreen),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: .3,
          ),
        ),
      ],
    ),
  );
}
