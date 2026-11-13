import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/utils/audio_alarm_service.dart';
import 'package:recipetools/utils/notification_service.dart';
import 'package:recipetools/services/ad_service.dart';
import 'package:recipetools/services/play_integrity_service.dart';
import 'package:recipetools/utils/google_sign_in_initializer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cold Start Deferred Services Warmup Tests', () {
    test('AudioAlarmService init initializes without throwing on host runner', () async {
      final service = AudioAlarmService();
      await expectLater(service.init(), completes);
    });

    test('NotificationService init initializes without throwing on host runner', () async {
      final service = NotificationService();
      await expectLater(service.init(), completes);
    });

    test('Concurrent execution of deferred startup initializers completes safely', () async {
      // Ensure all deferred calls execute without race conditions or uncaught asynchronous errors
      await expectLater(
        Future.wait<void>([
          NotificationService().init(),
          AudioAlarmService().init(),
          AdService.initialize(),
          PlayIntegrityService.prepareTokenProvider(),
          GoogleSignInInitializer.ensureInitialized(),
        ]),
        completes,
      );
    });

    test('AdService request before or during deferred warmup handles non-supported platform gracefully', () {
      expect(AdService.isSupportedPlatform, isFalse);
      expect(AdService.bannerAdUnitId, isEmpty);
      expect(AdService.rewardedAdUnitId, isEmpty);
      expect(AdService.isRewardedAdReady, isFalse);
    });
  });
}
