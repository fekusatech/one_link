import 'package:flutter_test/flutter_test.dart';
import 'package:one_link/services/geu/geu_api_client.dart';

void main() {
  group('GeuApiClient.unwrapData', () {
    test('unwraps the standard CRM success envelope', () {
      final result = GeuApiClient.unwrapData({
        'status': 'success',
        'code': 200,
        'data': [
          {'id': 1},
        ],
      });

      expect(result, [
        {'id': 1},
      ]);
    });

    test('keeps a legacy unwrapped response intact', () {
      final result = GeuApiClient.unwrapData({'id': 7, 'name': 'Supplier'});

      expect(result, {'id': 7, 'name': 'Supplier'});
    });
  });
}
