import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/provider/ad_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/services/ad_service.dart';
import 'package:recipetools/utils/ad_interleaving_helper.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:recipetools/widgets/inline_ad_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    AdService.debugIsSupportedPlatform = null;
  });

  tearDown(() {
    AdService.debugIsSupportedPlatform = null;
  });

  group('Ad Performance & Zero-Jank Architecture Tests', () {
    test('AndroidManifest.xml declares android:hardwareAccelerated="true" on <application>', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final content = manifestFile.readAsStringSync();

      final applicationTagMatch = RegExp(r'<application[^>]*android:hardwareAccelerated="true"[^>]*>', multiLine: true);
      expect(
        applicationTagMatch.hasMatch(content),
        isTrue,
        reason: '<application> node in AndroidManifest.xml must explicitly declare android:hardwareAccelerated="true"',
      );
    });

    test('AdInterleavingHelper generates deterministic slot keys for keepalive recycling', () {
      final keyRecipe = AdInterleavingHelper.getSlotKey('recipe', 5);
      final keyIngredient = AdInterleavingHelper.getSlotKey('ingredient', 11);

      expect(keyRecipe, equals('recipe_ad_slot_5'));
      expect(keyIngredient, equals('ingredient_ad_slot_11'));
    });

    testWidgets('InlineAdCard keeps state alive across scrolling via AutomaticKeepAliveClientMixin', (tester) async {
      AdService.debugIsSupportedPlatform = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: InlineAdCard(style: InlineAdCardStyle.recipe),
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(InlineAdCard));
      expect(state, isA<AutomaticKeepAliveClientMixin>());
      expect((state as dynamic).wantKeepAlive, isTrue);
    });

    testWidgets('SmartBannerAdWidget keeps state alive across scrolling via AutomaticKeepAliveClientMixin', (tester) async {
      AdService.debugIsSupportedPlatform = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: InlineAdCard(style: InlineAdCardStyle.ingredient),
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(InlineAdCard));
      expect(state, isA<AutomaticKeepAliveClientMixin>());
      expect((state as dynamic).wantKeepAlive, isTrue);
    });

    testWidgets('InlineAdCard pre-allocates exact 320x50 target ad dimensions (Zero-CLS)', (tester) async {
      AdService.debugIsSupportedPlatform = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: InlineAdCard(style: InlineAdCardStyle.recipe),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Card is built immediately without zero-height delay
      expect(find.byType(Card), findsOneWidget);

      // Pre-allocated SizedBox inside ad container with full inner width and locked adaptive height
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final hasPreallocatedSlot = sizedBoxes.any(
        (box) => box.width == double.infinity && (box.height ?? 0) >= 50.0,
      );
      expect(hasPreallocatedSlot, isTrue, reason: 'Target banner ad slot must be pre-allocated');
    });

    testWidgets('InlineAdCard pre-allocates native card bounds for ingredient style (Zero-CLS)', (tester) async {
      AdService.debugIsSupportedPlatform = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: InlineAdCard(style: InlineAdCardStyle.ingredient),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Card), findsOneWidget);
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final hasPreallocatedSlot = sizedBoxes.any(
        (box) => box.width == double.infinity && (box.height ?? 0) >= 96.0,
      );
      expect(hasPreallocatedSlot, isTrue, reason: 'InlineAdCard must pre-allocate native slot height');
    });

    testWidgets('InlineAdCard hides completely when user unlocks ad-free pass', (tester) async {
      AdService.debugIsSupportedPlatform = true;

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      try {
        // Unlock 8-hour ad-free pass
        await container.read(adNotifierProvider.notifier).unlockAdFreeFor8Hours();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: InlineAdCard(style: InlineAdCardStyle.recipe),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(Card), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      }
    });

    test('Ad audio policy mutes banner ads and only allows sound on rewarded ads', () async {
      // Audio for banners is muted by default
      expect(AdService.isAppMuted, isTrue);

      // Explicitly enabling audio sets isAppMuted to false
      await AdService.enableRewardedAdAudio();
      expect(AdService.isAppMuted, isFalse);

      // Muting inline ads sets isAppMuted back to true
      await AdService.muteInlineAds();
      expect(AdService.isAppMuted, isTrue);

      // Triggering native ad creation enforces muted policy
      await AdService.enableRewardedAdAudio();
      expect(AdService.isAppMuted, isFalse);
      AdService.createNativeAd(
        nativeTemplateStyle: NativeTemplateStyle(templateType: TemplateType.small),
        onAdLoaded: (_) {},
        onAdFailedToLoad: (_) {},
      );
      expect(AdService.isAppMuted, isTrue);
    });
  });
}
