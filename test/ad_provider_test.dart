import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/ad_provider.dart';
import 'package:recipetools/provider/cloud_sync_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/services/ad_service.dart';
import 'package:recipetools/utils/ad_interleaving_helper.dart';
import 'package:recipetools/widgets/ad_free_pass_button.dart';
import 'package:recipetools/widgets/inline_ad_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        if (methodCall.method == 'getTemporaryDirectory') {
          return '.';
        }
        return null;
      },
    );
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('AdState & AdNotifier Unit Tests', () {
    test('Initial state: ads are active when unsubscribed and no pass unlocked', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final adState = container.read(adProvider);

      expect(adState.isAdFree, isFalse);
      expect(adState.hasActiveSubscription, isFalse);
      expect(adState.isSubscribed, isFalse);
      expect(adState.adFreeUntil, isNull);
      expect(adState.adFreeUntilMillis, isNull);
      expect(adState.remainingAdFreeTime, Duration.zero);
      expect(adState.isLoadingRewardedAd, isFalse);
    });

    test('Calling unlockAdFreeFor8Hours() sets isAdFree to true and persists adFreeUntilMillis in SharedPreferences', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(adProvider.notifier);

      final beforeUnlock = DateTime.now();
      await notifier.unlockAdFreeFor8Hours();

      final state = container.read(adProvider);

      expect(state.isAdFree, isTrue);
      expect(state.adFreeUntil, isNotNull);
      expect(state.adFreeUntilMillis, isNotNull);
      expect(state.adFreeUntil!.isAfter(beforeUnlock.add(const Duration(hours: 7, minutes: 59))), isTrue);
      expect(state.remainingAdFreeTime.inMinutes, greaterThan(470)); // ~480 minutes (8 hours)

      // Verify persistence in SharedPreferences
      final persistedMs = prefs.getInt(AdNotifier.adFreeUntilPrefKey);
      expect(persistedMs, isNotNull);
      expect(persistedMs, state.adFreeUntilMillis);
    });

    test('Timestamp expiration: isAdFree evaluates to false when pass has expired', () async {
      final pastTime = DateTime.now().subtract(const Duration(minutes: 5));
      await prefs.setInt(AdNotifier.adFreeUntilPrefKey, pastTime.millisecondsSinceEpoch);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(adProvider);

      // Expired pass does not grant ad-free status
      expect(state.isAdFree, isFalse);
      expect(state.remainingAdFreeTime, Duration.zero);

      // Directly set an expired timestamp to verify dynamic calculation
      final explicitState = AdState(adFreeUntil: pastTime);
      expect(explicitState.isAdFree, isFalse);
      expect(explicitState.remainingAdFreeTime, Duration.zero);
    });

    test('Active Cloud Sync subscription sets isAdFree to true and provides subscriber ad exemption', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Verify initially ads are active
      expect(container.read(adProvider).isAdFree, isFalse);

      // Subscribe user to Cloud Sync ($1.99 monthly plan)
      final cloudSyncNotifier = container.read(cloudSyncProvider.notifier);
      await cloudSyncNotifier.setSubscription(
        isSubscribed: true,
        plan: CloudSyncNotifier.monthlySubscriptionId,
      );

      final adState = container.read(adProvider);
      expect(adState.isSubscribed, isTrue);
      expect(adState.hasActiveSubscription, isTrue);
      expect(adState.isAdFree, isTrue);
    });

    test('Annual Cloud Sync subscription (\$14.99) automatically grants ad-free status', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final cloudSyncNotifier = container.read(cloudSyncProvider.notifier);
      await cloudSyncNotifier.setSubscription(
        isSubscribed: true,
        plan: CloudSyncNotifier.annualSubscriptionId,
      );

      final adState = container.read(adProvider);
      expect(adState.isSubscribed, isTrue);
      expect(adState.isAdFree, isTrue);
    });

    test('Restricting Firestore cloud synchronization to active subscribers', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final cloudSyncNotifier = container.read(cloudSyncProvider.notifier);

      // Drain microtasks from build()
      await Future<void>.delayed(Duration.zero);

      // Free user attempts Firestore sync -> blocked
      final res = await cloudSyncNotifier.syncFirestore();
      expect(res, isNull);
      final freeState = container.read(cloudSyncProvider);
      expect(freeState.errorMessage, 'cloud_sync_subscription_required');

      // Active subscriber attempts Firestore sync -> allowed to proceed
      await cloudSyncNotifier.setSubscription(
        isSubscribed: true,
        plan: CloudSyncNotifier.monthlySubscriptionId,
      );
      expect(container.read(cloudSyncProvider).hasActiveSubscription, isTrue);
    });

    test('Local calculation tools and SQLite backups remain completely free without subscription', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final cloudSyncNotifier = container.read(cloudSyncProvider.notifier);

      // Local database backups to custom directory are 100% free
      await cloudSyncNotifier.createBackup();
      final state = container.read(cloudSyncProvider);
      expect(state.errorMessage, isNull);
    });

    test('AdService platform restriction prevents native calls during testing', () {
      expect(AdService.isSupportedPlatform, isFalse);
      expect(AdService.bannerAdUnitId, isEmpty);
      expect(AdService.rewardedAdUnitId, isEmpty);
    });
  });

  group('AdInterleavingHelper Virtual Indexing Tests', () {
    test('Virtual count calculation with kAdInterval = 5', () {
      // When ads are disabled (e.g. ad-free or unsupported platform)
      expect(AdInterleavingHelper.getVisualCount(0, false), 0);
      expect(AdInterleavingHelper.getVisualCount(4, false), 4);
      expect(AdInterleavingHelper.getVisualCount(5, false), 5);
      expect(AdInterleavingHelper.getVisualCount(12, false), 12);

      // When ads are enabled
      expect(AdInterleavingHelper.getVisualCount(0, true), 0);
      expect(AdInterleavingHelper.getVisualCount(4, true), 4); // 0 ads
      expect(AdInterleavingHelper.getVisualCount(5, true), 6); // 1 ad (at index 5)
      expect(AdInterleavingHelper.getVisualCount(9, true), 10); // 1 ad
      expect(AdInterleavingHelper.getVisualCount(10, true), 12); // 2 ads (at index 5 and 11)
      expect(AdInterleavingHelper.getVisualCount(15, true), 18); // 3 ads (at index 5, 11, 17)
    });

    test('Ad slot detection with kAdInterval = 5', () {
      // Items 0..4 are data items
      for (int i = 0; i < 5; i++) {
        expect(AdInterleavingHelper.isAdIndex(i), isFalse, reason: 'Index $i should be data');
      }
      // Index 5 is Ad 1
      expect(AdInterleavingHelper.isAdIndex(5), isTrue, reason: 'Index 5 should be an ad');

      // Items 6..10 are data items
      for (int i = 6; i <= 10; i++) {
        expect(AdInterleavingHelper.isAdIndex(i), isFalse, reason: 'Index $i should be data');
      }
      // Index 11 is Ad 2
      expect(AdInterleavingHelper.isAdIndex(11), isTrue, reason: 'Index 11 should be an ad');

      // Index 17 is Ad 3
      expect(AdInterleavingHelper.isAdIndex(17), isTrue, reason: 'Index 17 should be an ad');
    });

    test('Virtual to data index mapping resolves every item without off-by-one errors', () {
      const int dataCount = 15;
      final int visualCount = AdInterleavingHelper.getVisualCount(dataCount, true);
      expect(visualCount, 18);

      final List<int> mappedDataIndices = [];

      for (int visualIndex = 0; visualIndex < visualCount; visualIndex++) {
        if (AdInterleavingHelper.isAdIndex(visualIndex)) {
          continue; // Ad slot
        }
        final int dataIndex = AdInterleavingHelper.getDataIndex(visualIndex);
        mappedDataIndices.add(dataIndex);
      }

      // Verify that every single data index from 0 to 14 was resolved in exact sequential order
      expect(mappedDataIndices.length, dataCount);
      for (int i = 0; i < dataCount; i++) {
        expect(mappedDataIndices[i], i, reason: 'Expected mapped index $i at position $i');
      }
    });

    test('Virtual mapping never mutates database or Drift collections', () {
      final List<String> mockRecipes = ['Pizza', 'Burger', 'Pasta', 'Salad', 'Soup', 'Tacos', 'Steak'];
      final List<String> renderedItems = [];

      final int visualCount = AdInterleavingHelper.getVisualCount(mockRecipes.length, true);

      for (int v = 0; v < visualCount; v++) {
        if (AdInterleavingHelper.isAdIndex(v)) {
          renderedItems.add('AD_SLOT');
        } else {
          final d = AdInterleavingHelper.getDataIndex(v);
          renderedItems.add(mockRecipes[d]);
        }
      }

      expect(renderedItems, [
        'Pizza',
        'Burger',
        'Pasta',
        'Salad',
        'Soup',
        'AD_SLOT',
        'Tacos',
        'Steak',
      ]);

      // Original recipe list remains completely pristine
      expect(mockRecipes.length, 7);
      expect(mockRecipes.first, 'Pizza');
      expect(mockRecipes.last, 'Steak');
    });
  });

  group('Ad Widgets Tests', () {
    testWidgets('AdFreePassButton and InlineAdCard hide completely on unsupported platforms', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  AdFreePassButton(),
                  InlineAdCard(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ActionChip), findsNothing);
      expect(find.byType(Chip), findsNothing);
      expect(find.byType(Card), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('AdFreePassButton renders ad block icon button on supported platform when ads active', (tester) async {
      AdService.debugIsSupportedPlatform = true;
      addTearDown(() {
        AdService.debugIsSupportedPlatform = null;
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(
              body: AdFreePassButton(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('AdFreePassButton switches to shield icon without countdown text when ad-free pass is active', (tester) async {
      AdService.debugIsSupportedPlatform = true;
      addTearDown(() {
        AdService.debugIsSupportedPlatform = null;
      });

      final futurePass = DateTime.now().add(const Duration(hours: 4, minutes: 30));
      await prefs.setInt(AdNotifier.adFreeUntilPrefKey, futurePass.millisecondsSinceEpoch);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(
              body: AdFreePassButton(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
      // Verify countdown text is NOT rendered directly as visible text in the button
      expect(find.textContaining('4h 30m'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('AdFreePassButton hides completely when user is an active subscriber', (tester) async {
      AdService.debugIsSupportedPlatform = true;
      addTearDown(() {
        AdService.debugIsSupportedPlatform = null;
      });

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cloudSyncProvider.notifier).setSubscription(
        isSubscribed: true,
        plan: CloudSyncNotifier.monthlySubscriptionId,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(
              body: AdFreePassButton(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IconButton), findsNothing);
      expect(find.byIcon(Icons.block_rounded), findsNothing);
      expect(find.byIcon(Icons.shield_rounded), findsNothing);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  });
}
