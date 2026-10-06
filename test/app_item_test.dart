import 'package:flutter_test/flutter_test.dart';
import 'package:applock/models/app_item.dart';

void main() {
  group('AppItem Model & Classification Tests', () {
    test('Detects WhatsApp and Instagram as Social/Messenger', () {
      const whatsapp = AppItem(
        name: 'WhatsApp',
        packageName: 'com.whatsapp',
      );
      const instagram = AppItem(
        name: 'Instagram',
        packageName: 'com.instagram.android',
      );
      const calculator = AppItem(
        name: 'Calculator',
        packageName: 'com.android.calculator2',
      );

      expect(whatsapp.isSocialOrMessenger, isTrue);
      expect(instagram.isSocialOrMessenger, isTrue);
      expect(calculator.isSocialOrMessenger, isFalse);
    });

    test('Detects Banking, Gallery, and Settings as Sensitive apps', () {
      const settings = AppItem(
        name: 'Settings',
        packageName: 'com.android.settings',
      );
      const photos = AppItem(
        name: 'Photos',
        packageName: 'com.google.android.apps.photos',
      );
      const bank = AppItem(
        name: 'Mobile Banking',
        packageName: 'com.chase.sig.android',
      );
      const notes = AppItem(
        name: 'Simple Notes',
        packageName: 'com.example.notes',
      );

      expect(settings.isSensitiveOrFinancial, isTrue);
      expect(photos.isSensitiveOrFinancial, isTrue);
      expect(bank.isSensitiveOrFinancial, isTrue);
      expect(notes.isSensitiveOrFinancial, isFalse);
    });

    test('copyWith updates lock status and attributes', () {
      const app = AppItem(
        name: 'Instagram',
        packageName: 'com.instagram.android',
        isLocked: false,
      );

      final lockedApp = app.copyWith(isLocked: true);

      expect(lockedApp.isLocked, isTrue);
      expect(lockedApp.name, equals('Instagram'));
      expect(lockedApp.packageName, equals('com.instagram.android'));
    });
  });
}
