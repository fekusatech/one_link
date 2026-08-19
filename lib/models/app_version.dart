class AppVersion {
  final String versionName;
  final int versionCode;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;

  AppVersion({
    required this.versionName,
    required this.versionCode,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      versionName: json['latest_version'] ?? json['version_name'] ?? '',
      versionCode: json['version_code'] ?? 0,
      downloadUrl: json['download_url'] ?? '',
      releaseNotes: json['release_notes'] ?? '',
      forceUpdate: json['force_update'] ?? false,
    );
  }
}
