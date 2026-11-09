import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/services/play_integrity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayIntegrityService Unit Tests', () {
    const channel = MethodChannel('com.chefandcost.app/play_integrity');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('generateSha256Digest produces URL-safe unpadded base64 hash', () {
      final digest1 = PlayIntegrityService.generateSha256Digest('test_input');
      expect(digest1, isNotEmpty);
      expect(digest1.contains('='), isFalse);
      expect(digest1.contains('+'), isFalse);
      expect(digest1.contains('/'), isFalse);

      final digest2 = PlayIntegrityService.generateSha256Digest('test_input');
      expect(digest1, equals(digest2));
    });

    test('generateDefaultRequestHash produces non-empty unpadded hash', () {
      final hash = PlayIntegrityService.generateDefaultRequestHash();
      expect(hash, isNotEmpty);
      expect(hash.contains('='), isFalse);
    });

    test('requestIntegrityToken returns simulated debug token in test environment', () async {
      final result = await PlayIntegrityService.requestIntegrityToken(
        requestHash: 'test_hash_abc',
      );
      expect(result.isSuccess, isTrue);
      expect(result.token, contains('simulated_debug_integrity_token'));
      expect(result.type, equals('simulated'));
      expect(result.requestHash, equals('test_hash_abc'));
    });

    test('requestTokenForAction calculates hash and returns result', () async {
      final result = await PlayIntegrityService.requestTokenForAction(
        action: 'billing_checkout',
        userId: 'user_12345',
        metadata: {'planId': 'chefy_monthly'},
      );
      expect(result.isSuccess, isTrue);
      expect(result.requestHash, isNotNull);
      expect(result.requestHash!.length, greaterThan(10));
    });
  });
}
