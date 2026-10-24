import 'package:fitness_formulasi/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhone (matches backend rules)', () {
    test('accepts common Uzbek formats', () {
      expect(Validators.normalizePhone('+998 90 123-45-67'), '+998901234567');
      expect(Validators.normalizePhone('998901234567'), '+998901234567');
      expect(Validators.normalizePhone('90 123 45 67'), '+998901234567');
    });
    test('rejects invalid input', () {
      expect(Validators.normalizePhone(''), isNull);
      expect(Validators.normalizePhone('12345'), isNull);
      expect(Validators.normalizePhone('+99890123456'), isNull);
    });
  });

  test('password policy requires 8+ chars with letters and digits', () {
    expect(Validators.isStrongPassword('Secret123'), isTrue);
    expect(Validators.isStrongPassword('Пароль123'), isTrue);
    expect(Validators.isStrongPassword('short1'), isFalse);
    expect(Validators.isStrongPassword('onlyletters'), isFalse);
    expect(Validators.isStrongPassword('12345678'), isFalse);
  });

  test('loginId accepts phones and, in debug builds, short dev logins', () {
    expect(Validators.loginId('901234567'), '+998901234567');
    expect(Validators.loginId(' 1 '), '1');
    expect(Validators.loginId('abc'), isNull);
  });
}
