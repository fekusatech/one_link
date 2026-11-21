import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:ndef_record/ndef_record.dart';

import 'device_identity_service.dart';
import 'geu_api_client.dart';

class NfcRecoveryCard {
  final String cardId;
  final String token;
  final int warehouseId;
  final String warehouseName;
  final DateTime expiresAt;

  const NfcRecoveryCard({
    required this.cardId,
    required this.token,
    required this.warehouseId,
    required this.warehouseName,
    required this.expiresAt,
  });

  factory NfcRecoveryCard.fromJson(Map json) => NfcRecoveryCard(
    cardId: '${json['card_id'] ?? ''}',
    token: '${json['token'] ?? ''}',
    warehouseId: int.tryParse('${json['warehouse_id'] ?? ''}') ?? 0,
    warehouseName: '${json['warehouse_name'] ?? 'Gudang'}',
    expiresAt:
        DateTime.tryParse('${json['expires_at'] ?? ''}') ?? DateTime.now(),
  );
}

class NfcRecoveryService {
  static void _log(String message) => debugPrint('[NFC_RECOVERY] $message');

  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    return await NfcManager.instance.checkAvailability() ==
        NfcAvailability.enabled;
  }

  static Future<void> startRecoveryListener({
    required Future<void> Function(Map<String, String> card) onCard,
    required void Function(Object error) onError,
  }) async {
    if (!await isAvailable()) {
      throw Exception('NFC tidak tersedia atau belum diaktifkan.');
    }
    _log('login listener start');
    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443},
      alertMessageIos: 'Tempelkan kartu NFC untuk masuk.',
      invalidateAfterFirstReadIos: false,
      onDiscovered: (tag) async {
        _log('login listener tag discovered');
        try {
          final card = await _readPayload(tag);
          await onCard(card);
        } catch (error) {
          _log('login listener read/recovery error=$error');
          onError(error);
        }
      },
      onSessionErrorIos: (error) {
        _log('login listener session error=${error.message}');
        onError(Exception(error.message));
      },
    );
  }

  static Future<void> stopRecoveryListener() async {
    _log('login listener stop');
    await NfcManager.instance.stopSession();
  }

  static Future<List<Map<String, dynamic>>> loadWarehouses() async {
    final response = await (await GeuApiClient.instance).get(
      '/api/suppliers/dropdowns',
    );
    final body = response.data;
    final data = body is Map && body['data'] is Map
        ? body['data'] as Map
        : body;
    final items = body is Map
        ? (body['gudang'] as List? ??
              (data is Map ? data['gudang'] as List? : null) ??
              const [])
        : const [];
    if (response.statusCode != 200 || items.isEmpty) {
      throw Exception(
        body is Map
            ? body['message']?.toString() ?? 'Daftar gudang tidak tersedia.'
            : 'Daftar gudang tidak tersedia.',
      );
    }
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<NfcRecoveryCard> issueCard(int warehouseId) async {
    final response = await (await GeuApiClient.instance).post(
      '/api-admin/device-recovery-cards',
      data: {'warehouse_id': warehouseId},
    );
    final body = response.data;
    if ((response.statusCode ?? 500) < 200 ||
        (response.statusCode ?? 500) >= 300 ||
        body is! Map ||
        body['data'] is! Map) {
      throw Exception(
        body is Map
            ? body['message']?.toString() ?? 'Gagal membuat kartu NFC.'
            : 'Gagal membuat kartu NFC.',
      );
    }
    return NfcRecoveryCard.fromJson(body['data'] as Map);
  }

  static Future<void> recover({
    required String email,
    required String password,
    required String cardId,
    required String token,
  }) async {
    final deviceId = await DeviceIdentityService.getDeviceId();
    _log(
      'recovery request card=$cardId device_available=${deviceId.isNotEmpty}',
    );
    final response = await (await GeuApiClient.instance).post(
      '/api-auth/mobile/device-recovery',
      data: {
        'email': email,
        'password': password,
        'card_id': cardId,
        'token': token,
      },
      options: Options(
        headers: {'X-Client-Type': 'mobile', 'X-Device-ID': deviceId},
      ),
    );
    final body = response.data;
    if (response.statusCode != 200 ||
        body is! Map ||
        body['status'] != 'success') {
      _log(
        'recovery rejected http=${response.statusCode} message=${body is Map ? body['message'] : 'invalid_response'}',
      );
      throw Exception(
        body is Map
            ? body['message']?.toString() ??
                  'Kartu tidak valid atau sudah kedaluwarsa.'
            : 'Kartu tidak valid atau sudah kedaluwarsa.',
      );
    }
    _log('recovery accepted');
  }

  static Future<void> writeTag(NfcRecoveryCard card) async {
    _log('write start card=${card.cardId} warehouse=${card.warehouseId}');
    await _withTag((tag) async {
      final ndef = Ndef.from(tag);
      final json = jsonEncode({
        'version': 1,
        'card_id': card.cardId,
        'token': card.token,
        'warehouse_id': card.warehouseId,
        'warehouse_name': card.warehouseName,
        'expires_at': card.expiresAt.toUtc().toIso8601String(),
      });
      final language = ascii.encode('id');
      final text = utf8.encode(json);
      final payload = Uint8List.fromList([
        language.length,
        ...language,
        ...text,
      ]);
      final record = NdefRecord(
        typeNameFormat: TypeNameFormat.wellKnown,
        type: Uint8List.fromList(ascii.encode('T')),
        identifier: Uint8List(0),
        payload: payload,
      );
      final message = NdefMessage(records: [record]);

      if (ndef != null) {
        _log(
          'write path=ndef writable=${ndef.isWritable} max_bytes=${ndef.maxSize} message_bytes=${message.byteLength}',
        );
        if (!ndef.isWritable) {
          throw Exception('Kartu NDEF ini terkunci dan tidak dapat ditulis.');
        }
        if (message.byteLength > ndef.maxSize) {
          throw Exception('Kapasitas kartu terlalu kecil.');
        }
        await ndef.write(message: message);
        _log('write complete path=ndef');
        return;
      }

      // MIFARE Classic tags may expose NdefFormatable before their first
      // NDEF write. Format and write in one step so no separate utility app
      // is needed to prepare the card.
      final formatable = NdefFormatableAndroid.from(tag);
      if (formatable == null) {
        _log('write failed reason=not_ndef_and_not_formatable');
        throw Exception('Kartu bukan NDEF dan tidak mendukung format NDEF.');
      }
      _log('write path=formatable message_bytes=${message.byteLength}');
      await formatable.format(message);
      _log('write format complete; remove card and scan again to verify');
    }, alert: 'Tempelkan kartu NFC untuk ditulis.');
  }

  static Future<Map<String, String>> readTag() async {
    Map<String, String>? result;
    await _withTag((tag) async {
      result = await _readPayload(tag);
    }, alert: 'Tempelkan kartu NFC untuk dibaca.');
    if (result == null) throw Exception('Kartu NFC tidak terbaca.');
    return result!;
  }

  static Future<Map<String, String>> _readPayload(NfcTag tag) async {
    final ndef = Ndef.from(tag);
    if (ndef == null) {
      final formatable = NdefFormatableAndroid.from(tag) != null;
      _log('read failed ndef=false formatable=$formatable');
      throw Exception(
        formatable
            ? 'Kartu masih terdeteksi belum terformat NDEF. Jauhkan kartu setelah menulis, lalu tempelkan kembali.'
            : 'Kartu tidak mendukung NDEF pada sesi baca ini.',
      );
    }
    _log('read path=ndef max_bytes=${ndef.maxSize}');
    final message = await ndef.read();
    if (message == null || message.records.isEmpty) {
      _log('read failed ndef=true message_empty=true');
      throw Exception(
        'Kartu NDEF kosong. Tulis ulang kartu, lalu pindai kembali.',
      );
    }
    _log(
      'read message records=${message.records.length} bytes=${message.byteLength}',
    );
    for (final record in message.records) {
      if (record.typeNameFormat != TypeNameFormat.wellKnown ||
          ascii.decode(record.type, allowInvalid: true) != 'T' ||
          record.payload.isEmpty) {
        continue;
      }
      final languageLength = record.payload.first & 0x3f;
      if (record.payload.length <= languageLength + 1) continue;
      final text = utf8.decode(record.payload.sublist(languageLength + 1));
      final decoded = jsonDecode(text);
      if (decoded is Map &&
          decoded['card_id'] != null &&
          decoded['token'] != null) {
        _log('read payload parsed successfully');
        return {
          'card_id': decoded['card_id'].toString(),
          'token': decoded['token'].toString(),
          if (decoded['warehouse_id'] != null)
            'warehouse_id': decoded['warehouse_id'].toString(),
          if (decoded['warehouse_name'] != null)
            'warehouse_name': decoded['warehouse_name'].toString(),
          if (decoded['expires_at'] != null)
            'expires_at': decoded['expires_at'].toString(),
        };
      }
    }
    throw Exception('Format kartu NFC tidak dikenali.');
  }

  static Future<void> _withTag(
    Future<void> Function(NfcTag tag) operation, {
    required String alert,
  }) async {
    if (!await isAvailable())
      throw Exception(
        'NFC tidak tersedia atau belum diaktifkan di perangkat ini.',
      );
    final completer = Completer<void>();
    Timer? timeout;
    _log('session start mode=$alert');
    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443},
      alertMessageIos: alert,
      onDiscovered: (tag) async {
        if (completer.isCompleted) return;
        _log('tag discovered');
        try {
          await operation(tag);
          _log('tag operation complete');
          if (!completer.isCompleted) completer.complete();
        } catch (error, stack) {
          _log('tag operation failed error=$error');
          if (!completer.isCompleted) completer.completeError(error, stack);
        } finally {
          _log('session stop');
          await NfcManager.instance.stopSession();
        }
      },
      onSessionErrorIos: (error) {
        _log('session error=${error.message}');
        if (!completer.isCompleted)
          completer.completeError(Exception(error.message));
      },
    );
    timeout = Timer(const Duration(seconds: 45), () {
      _log('session timeout');
      if (!completer.isCompleted)
        completer.completeError(Exception('Waktu pemindaian NFC habis.'));
      unawaited(NfcManager.instance.stopSession());
    });
    try {
      await completer.future;
    } finally {
      timeout.cancel();
    }
  }
}
