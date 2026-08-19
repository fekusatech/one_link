import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class CustomDropdown<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final T? value;
  final String Function(T) getTitle;
  final void Function(T?) onChanged;
  final bool isLoading;
  final String? hint;
  final bool enabled;
  final String? errorText;

  const CustomDropdown({
    super.key,
    required this.label,
    required this.items,
    this.value,
    required this.getTitle,
    required this.onChanged,
    this.isLoading = false,
    this.hint,
    this.enabled = true,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: errorText != null ? Colors.red : AppColors.borderColor,
            ),
            color: enabled ? AppColors.white : AppColors.backgroundGrey,
          ),
          child: isLoading
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading...',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownButtonFormField<T>(
                  value: value,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    hintText: hint ?? 'Pilih $label',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  items: items.map((item) {
                    return DropdownMenuItem<T>(
                      value: item,
                      child: Text(
                        getTitle(item),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: enabled ? onChanged : null,
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: enabled ? AppColors.textSecondary : AppColors.grey,
                  ),
                  dropdownColor: AppColors.white,
                  isExpanded: true,
                ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: AppTextStyles.caption.copyWith(color: Colors.red),
          ),
        ],
      ],
    );
  }
}

// Loading dropdown widget
class LoadingDropdown extends StatelessWidget {
  final String label;

  const LoadingDropdown({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return CustomDropdown<String>(
      label: label,
      items: const [],
      getTitle: (item) => item,
      onChanged: (value) {},
      isLoading: true,
      enabled: false,
    );
  }
}
