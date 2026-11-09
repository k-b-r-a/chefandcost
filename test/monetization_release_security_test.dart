import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/constants.dart';
import 'package:recipetools/provider/cloud_sync_provider.dart';
import 'package:recipetools/provider/monetization_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Monetization Release Security Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(() {
        MonetizationNotifier.debugAllowSandboxFallback = null;
        container.dispose();
      });
    });

    test('purchasePlan rejects fallback and fails securely when sandbox fallback is disabled', () async {
      // Simulate production release mode by explicitly disabling sandbox fallback
      MonetizationNotifier.debugAllowSandboxFallback = false;

      final notifier = container.read(monetizationProvider.notifier);
      final success = await notifier.purchasePlan(kMonthlySubscriptionId);

      expect(success, isFalse, reason: 'purchasePlan must not succeed via sandbox fallback in release mode');

      final state = container.read(monetizationProvider);
      expect(state.hasActiveSubscription, isFalse, reason: 'User must not receive free subscription');
      expect(state.errorMessage, equals('subscription_store_unavailable'));
      expect(state.isLoadingPurchase, isFalse);
    });

    test('purchasePlan permits fallback in test / debug environments when enabled', () async {
      // Enable sandbox fallback (standard behavior in debug / automated tests)
      MonetizationNotifier.debugAllowSandboxFallback = true;

      final notifier = container.read(monetizationProvider.notifier);
      final success = await notifier.purchasePlan(kMonthlySubscriptionId);

      expect(success, isTrue);

      final state = container.read(monetizationProvider);
      expect(state.hasActiveSubscription, isTrue);
      expect(state.activePlanId, equals(kMonthlySubscriptionId));
      expect(state.errorMessage, isNull);
    });

    test('CloudSyncNotifier.purchaseSubscription delegates securely to monetizationProvider', () async {
      MonetizationNotifier.debugAllowSandboxFallback = false;

      final cloudSyncNotifier = container.read(cloudSyncProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await cloudSyncNotifier.purchaseSubscription(kMonthlySubscriptionId);

      final cloudState = container.read(cloudSyncProvider);
      expect(cloudState.isSubscribed, isFalse);
      expect(cloudState.errorMessage, equals('subscription_store_unavailable'));

      final monetizationState = container.read(monetizationProvider);
      expect(monetizationState.hasActiveSubscription, isFalse);
    });
  });
}
