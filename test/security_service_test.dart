import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:applock/services/security_service.dart';
import 'package:applock/models/security_question.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecurityService securityService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    securityService = SecurityService();
    await securityService.init();
  });

  group('SecurityService Cryptographic Hashing Tests', () {
    test('Hash produces consistent SHA-256 output with identical salt', () {
      const pin = '4829';
      const salt = 'random_secure_salt_123';

      final hash1 = SecurityService.hashCredential(pin, salt);
      final hash2 = SecurityService.hashCredential(pin, salt);

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // 32 bytes in hex = 64 characters
    });

    test('Different salts produce different hashes for same input', () {
      const pin = '1234';
      final salt1 = SecurityService.generateSalt();
      final salt2 = SecurityService.generateSalt();

      final hash1 = SecurityService.hashCredential(pin, salt1);
      final hash2 = SecurityService.hashCredential(pin, salt2);

      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('Progressive Lockout Escalation Tests (Exact User Specification)', () {
    test('1 to 4 failed attempts do not trigger lockout', () {
      for (int i = 1; i <= 4; i++) {
        final status = securityService.recordFailedAttempt();
        expect(status.failedAttempts, equals(i));
        expect(status.remainingSeconds, equals(0));
        expect(status.isSecurityQuestionsRequired, isFalse);
      }
    });

    test('5th failed attempt triggers exactly 30 seconds lockout (Tier 1)', () {
      // 1 to 4
      for (int i = 1; i <= 4; i++) {
        securityService.recordFailedAttempt();
      }

      // 5th attempt
      final status = securityService.recordFailedAttempt();
      expect(status.failedAttempts, equals(5));
      expect(status.remainingSeconds, equals(30));
      expect(status.isSecurityQuestionsRequired, isFalse);
    });

    test('8th failed attempt triggers exactly 120 seconds lockout (Tier 2: +3 after Tier 1)', () {
      // 1 to 7
      for (int i = 1; i <= 7; i++) {
        securityService.recordFailedAttempt();
      }

      // 8th attempt (5 + 3)
      final status = securityService.recordFailedAttempt();
      expect(status.failedAttempts, equals(8));
      expect(status.remainingSeconds, equals(120));
      expect(status.isSecurityQuestionsRequired, isFalse);
    });

    test('11th failed attempt triggers 300 seconds lockout and Security Questions (Tier 3: +3 after Tier 2)', () {
      // 1 to 10
      for (int i = 1; i <= 10; i++) {
        securityService.recordFailedAttempt();
      }

      // 11th attempt (8 + 3)
      final status = securityService.recordFailedAttempt();
      expect(status.failedAttempts, equals(11));
      expect(status.remainingSeconds, equals(300));
      expect(status.isSecurityQuestionsRequired, isTrue);
    });

    test('Attempts beyond 11 continue requiring Security Questions', () {
      for (int i = 1; i <= 12; i++) {
        securityService.recordFailedAttempt();
      }

      expect(securityService.isSecurityQuestionsRequired(), isTrue);
      expect(securityService.getFailedAttempts(), equals(12));
    });

    test('resetFailedAttempts completely resets counter and lockout timers', () {
      for (int i = 1; i <= 11; i++) {
        securityService.recordFailedAttempt();
      }

      expect(securityService.getFailedAttempts(), equals(11));
      expect(securityService.isSecurityQuestionsRequired(), isTrue);

      securityService.resetFailedAttempts();

      expect(securityService.getFailedAttempts(), equals(0));
      expect(securityService.getRemainingLockoutSeconds(), equals(0));
      expect(securityService.isSecurityQuestionsRequired(), isFalse);
    });
  });

  group('Security Questions Normalization & Verification Tests', () {
    test('Answers match regardless of uppercase, lowercase or leading/trailing whitespace', () {
      const rawAnswer = '  Fluffy  ';
      final salt = SecurityService.generateSalt();
      final hashedAnswer = SecurityService.hashCredential(
        rawAnswer.trim().toLowerCase(),
        salt,
      );

      final question = SecurityQuestion(
        id: '1',
        question: 'What is your pet name?',
        answerHash: hashedAnswer,
        salt: salt,
      );

      // Verify various casing and whitespace formats
      expect(
        securityService.verifySecurityQuestionAnswer(
          question: question,
          enteredAnswer: 'fluffy',
        ),
        isTrue,
      );

      expect(
        securityService.verifySecurityQuestionAnswer(
          question: question,
          enteredAnswer: 'FLUFFY',
        ),
        isTrue,
      );

      expect(
        securityService.verifySecurityQuestionAnswer(
          question: question,
          enteredAnswer: '  FlUfFy  ',
        ),
        isTrue,
      );

      expect(
        securityService.verifySecurityQuestionAnswer(
          question: question,
          enteredAnswer: 'WrongAnswer',
        ),
        isFalse,
      );
    });
  });
}
