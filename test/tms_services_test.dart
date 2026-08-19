import 'package:flutter_test/flutter_test.dart';
import 'package:one_link/models/tms/settlement_model.dart';
import 'package:one_link/models/tms/movement_model.dart';
import 'package:one_link/models/tms/tms_notification_model.dart';

void main() {
  group('TMS Settlement Models Test', () {
    test('SettlementMappingItem.fromJson should parse correctly', () {
      final json = {
        'id': 101,
        'kode': 'ST-2026-001',
        'tgl_kalkulasi': '2026-08-20',
        'gudang_id': 5,
        'gudang_name': 'Gudang Surabaya',
        'driver_id': 12,
        'driver_name': 'Budi Driver',
        'total_cost_planned': 500000.0,
        'total_cost_actual': 480000.0,
        'variance_amount': 20000.0,
        'settlement_status': 'submitted',
      };

      final item = SettlementMappingItem.fromJson(json);

      expect(item.id, equals(101));
      expect(item.kode, equals('ST-2026-001'));
      expect(item.gudangName, equals('Gudang Surabaya'));
      expect(item.totalCostPlanned, equals(500000.0));
      expect(item.settlementStatus, equals('submitted'));
    });

    test('SettlementItemEntry.toJson should format properly', () {
      final entry = SettlementItemEntry(
        category: 'Parkir',
        amount: 15000.0,
        notes: 'Parkir gudang',
      );

      final json = entry.toJson();

      expect(json['category'], equals('Parkir'));
      expect(json['amount'], equals(15000.0));
      expect(json['notes'], equals('Parkir gudang'));
    });
  });

  group('TMS Movement Models Test', () {
    test('MovementItem.fromJson should parse correctly', () {
      final json = {
        'id': 202,
        'kode': 'MOV-2026-088',
        'dari_gudang': 'Gudang Malang',
        'tujuan_gudang': 'Pabrik Pasuruan',
        'fleet_name': 'Hino Dutro',
        'fleet_plat': 'N 9999 AB',
        'total_biaya': 750000.0,
        'progress': 'loading',
        'total_qty': 5000.0,
        'total_sys_qty': 5000.0,
      };

      final item = MovementItem.fromJson(json);

      expect(item.id, equals(202));
      expect(item.kode, equals('MOV-2026-088'));
      expect(item.fleetPlat, equals('N 9999 AB'));
      expect(item.progress, equals('loading'));
    });
  });

  group('TMS Notification Models Test', () {
    test('TmsNotificationInbox.fromJson should parse item list and count', () {
      final json = {
        'unread_count': 3,
        'items': [
          {
            'id': 1,
            'message': 'Surat Jalan baru ditugaskan',
            'link': '/surat-jalan/1',
            'is_read': false,
            'created_at': '2026-08-20 08:00:00',
          },
          {
            'id': 2,
            'message': 'Settlement Uang Jalan Disetujui',
            'link': '/settlement/2',
            'is_read': true,
            'created_at': '2026-08-19 14:00:00',
          }
        ]
      };

      final inbox = TmsNotificationInbox.fromJson(json);

      expect(inbox.unreadCount, equals(3));
      expect(inbox.items.length, equals(2));
      expect(inbox.items[0].message, equals('Surat Jalan baru ditugaskan'));
      expect(inbox.items[0].isRead, isFalse);
    });
  });
}
