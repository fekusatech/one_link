// Helper methods untuk add supplier screen
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/dropdown_models.dart';
import '../models/geographic_models.dart';
import '../providers/supplier_form_provider.dart';
import '../widgets/custom_dropdown.dart';

mixin AddSupplierHelpers {
  Widget buildTextField(
    String label,
    TextEditingController controller, {
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: 'Enter...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primaryGreen),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
          ),
          validator: required
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '$label wajib diisi';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget buildJenisDropdown(
    SupplierFormProvider provider,
    Function(String) onGenerateKode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jenis POO *',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<JenisSupplier>(
          value: provider.selectedJenis,
          decoration: InputDecoration(
            hintText: '--Pilih Jenis Supplier--',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primaryGreen),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
          ),
          items: provider.jenisSupplier.map((jenis) {
            return DropdownMenuItem<JenisSupplier>(
              value: jenis,
              child: Text(jenis.name),
            );
          }).toList(),
          onChanged: (value) {
            provider.selectedJenis = value;
            if (value != null) {
              onGenerateKode(value.name);
            }
          },
          validator: (value) {
            if (value == null) {
              return 'Jenis POO wajib dipilih';
            }
            return null;
          },
        ),
      ],
    );
  }
}
