import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../services/geu/work_order_service.dart' show WorkOrderAttachment;

/// One evidence photo staged locally before the WO exists yet - the actual
/// upload (POST /api/work-orders/:id/attachments) only happens after WO
/// creation succeeds and an id is known.
class StagedAttachment {
  final String type;
  final Uint8List bytes;
  const StagedAttachment({required this.type, required this.bytes});

  String get base64DataUri => 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

const _attachmentTypes = [
  ('chat_screenshot', 'Screenshot Chat', Icons.chat_bubble_outline),
  ('call_proof', 'Bukti Telpon', Icons.call_outlined),
  ('other', 'Lainnya', Icons.image_outlined),
];

/// Optional multi-photo picker for "bukti chat/telpon" - screenshots aren't
/// camera-only proof-of-presence like checkin/checkout, so this picks from
/// gallery or camera and skips the watermark/GPS stamp CheckinPhotoService
/// adds.
class WorkOrderAttachmentPicker extends StatefulWidget {
  final ValueChanged<List<StagedAttachment>> onChanged;
  const WorkOrderAttachmentPicker({super.key, required this.onChanged});

  @override
  State<WorkOrderAttachmentPicker> createState() =>
      _WorkOrderAttachmentPickerState();
}

class _WorkOrderAttachmentPickerState
    extends State<WorkOrderAttachmentPicker> {
  final List<StagedAttachment> _staged = [];
  bool _picking = false;

  Future<void> _addAttachment() async {
    final type = await _pickType();
    if (type == null || !mounted) return;
    final source = await _pickSource();
    if (source == null || !mounted) return;

    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;
      final raw = await picked.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        raw,
        minWidth: 1080,
        minHeight: 1080,
        quality: 80,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (!mounted) return;
      setState(() {
        _staged.add(
          StagedAttachment(type: type, bytes: Uint8List.fromList(compressed)),
        );
      });
      widget.onChanged(_staged);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat foto: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<String?> _pickType() => showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Jenis Bukti',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          for (final (value, label, icon) in _attachmentTypes)
            ListTile(
              leading: Icon(icon, color: AppColors.primaryGreen),
              title: Text(label),
              onTap: () => Navigator.pop(context, value),
            ),
        ],
      ),
    ),
  );

  Future<ImageSource?> _pickSource() => showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Dari Galeri'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Ambil Foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    ),
  );

  void _remove(int index) {
    setState(() => _staged.removeAt(index));
    widget.onChanged(_staged);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Bukti Chat/Telpon (Opsional)',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      Text(
        'Upload screenshot chat WhatsApp atau bukti riwayat telpon dengan '
        'supplier kalau ada — bisa lebih dari satu foto.',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 10),
      if (_staged.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _staged.length; i++)
              _StagedThumb(
                attachment: _staged[i],
                onRemove: () => _remove(i),
              ),
          ],
        ),
      if (_staged.isNotEmpty) const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _picking ? null : _addAttachment,
        icon: _picking
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_photo_alternate_outlined, size: 18),
        label: Text(
          _staged.isEmpty ? 'Tambah Bukti' : 'Tambah Bukti Lainnya',
        ),
      ),
    ],
  );
}

class _StagedThumb extends StatelessWidget {
  final StagedAttachment attachment;
  final VoidCallback onRemove;
  const _StagedThumb({required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          attachment.bytes,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
        ),
      ),
      Positioned(
        left: 2,
        bottom: 2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            WorkOrderAttachment.typeLabel(attachment.type),
            style: const TextStyle(color: Colors.white, fontSize: 9),
          ),
        ),
      ),
      Positioned(
        right: -6,
        top: -6,
        child: IconButton(
          icon: const Icon(Icons.cancel, size: 20, color: AppColors.error),
          onPressed: onRemove,
        ),
      ),
    ],
  );
}
