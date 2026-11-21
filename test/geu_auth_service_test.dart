import 'package:flutter_test/flutter_test.dart';
import 'package:one_link/services/geu/geu_auth_service.dart';

void main() {
  group('GeuAuthService.conflictTokenFrom', () {
    test('extracts the token when present', () {
      final token = GeuAuthService.conflictTokenFrom({
        'errors': {'conflict_token': 'tok-123'},
      });
      expect(token, 'tok-123');
    });

    test('returns null when absent', () {
      expect(GeuAuthService.conflictTokenFrom({'message': 'Invalid credentials'}), isNull);
    });
  });
}
