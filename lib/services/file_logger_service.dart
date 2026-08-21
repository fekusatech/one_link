import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Rotating daily debug-log file, written to the app's internal storage.
/// Hooked into every print()/debugPrint() call app-wide via a Zone print
/// override in main.dart, so no call sites need to change. One file per
/// day (`log-ddMMyy.log`), files older than [_retentionDays] are deleted
/// automatically. Purely for field debugging — see
/// [DebugLogUploadService] for the "send today's log" button.
class FileLoggerService {
  FileLoggerService._();
  static final FileLoggerService instance = FileLoggerService._();

  static const int _retentionDays = 7;

  Directory? _logDir;
  IOSink? _sink;
  String? _currentFileDateKey;

  bool get isReady => _logDir != null;

  Future<void> init() async {
    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${baseDir.path}/logs');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _logDir = dir;
      await _rotateIfNeeded();
      unawaited(_cleanupOldLogs());
    } catch (_) {
      // Logging must never crash app startup — fail silently and stay
      // uninitialized; write() below becomes a harmless no-op.
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}${d.month.toString().padLeft(2, '0')}${(d.year % 100).toString().padLeft(2, '0')}';

  File _fileFor(DateTime d) => File('${_logDir!.path}/log-${_dateKey(d)}.log');

  Future<void> _rotateIfNeeded() async {
    final todayKey = _dateKey(DateTime.now());
    if (_currentFileDateKey == todayKey && _sink != null) return;
    await _sink?.flush();
    await _sink?.close();
    _currentFileDateKey = todayKey;
    _sink = _fileFor(DateTime.now()).openWrite(mode: FileMode.append);
  }

  Future<void> _cleanupOldLogs() async {
    final dir = _logDir;
    if (dir == null) return;
    final cutoff = DateTime.now().subtract(const Duration(days: _retentionDays));
    final cutoffDay = DateTime(cutoff.year, cutoff.month, cutoff.day);
    final pattern = RegExp(r'^log-(\d{2})(\d{2})(\d{2})\.log$');
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final match = pattern.firstMatch(entity.uri.pathSegments.last);
        if (match == null) continue;
        final fileDate = DateTime(
          2000 + int.parse(match.group(3)!),
          int.parse(match.group(2)!),
          int.parse(match.group(1)!),
        );
        if (fileDate.isBefore(cutoffDay)) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  /// Fire-and-forget — logging must never block or throw into caller code
  /// (this runs on every single print()/debugPrint() in the app).
  void write(String message) {
    if (_logDir == null) return;
    unawaited(_writeAsync(message));
  }

  Future<void> _writeAsync(String message) async {
    try {
      await _rotateIfNeeded();
      final now = DateTime.now();
      final ts = '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}.'
          '${now.millisecond.toString().padLeft(3, '0')}';
      _sink?.writeln('[$ts] $message');
    } catch (_) {}
  }

  /// Today's log file — null if logging never initialized or nothing was
  /// written yet today.
  File? get todayLogFile {
    final dir = _logDir;
    if (dir == null) return null;
    final f = _fileFor(DateTime.now());
    return f.existsSync() ? f : null;
  }

  Future<void> flush() async {
    await _sink?.flush();
  }
}
