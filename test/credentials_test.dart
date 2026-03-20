import 'package:test/test.dart';
import 'package:dart_desk_cli/src/credentials.dart';

void main() {
  group('Credentials', () {
    test('isExpired returns true for past dates', () {
      final creds = Credentials(
        token: 'test',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(creds.isExpired, isTrue);
    });

    test('isExpired returns false for future dates', () {
      final creds = Credentials(
        token: 'test',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );
      expect(creds.isExpired, isFalse);
    });
  });
}
