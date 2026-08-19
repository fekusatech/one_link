/// Converts a stored phone number into WhatsApp's expected digits-only
/// international format (62xxxxxxxxxx, no leading +), mirroring
/// crm-react's src/lib/wa.ts so mobile and web produce identical links.
String formatWA(String phone) {
  if (phone.isEmpty) return '';
  final cleaned = phone.replaceAll(RegExp(r'\D'), '');
  if (cleaned.isEmpty) return phone;
  if (cleaned.startsWith('0')) return '62${cleaned.substring(1)}';
  if (cleaned.startsWith('8')) return '62$cleaned';
  return cleaned;
}

/// Builds a wa.me deep link for [phone], optionally pre-filling [text].
String waUrl(String phone, {String? text}) {
  final base = 'https://wa.me/${formatWA(phone)}';
  if (text == null || text.isEmpty) return base;
  return '$base?text=${Uri.encodeComponent(text)}';
}
