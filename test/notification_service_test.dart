import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/utils/notification_service.dart';
import 'package:recipetools/screens/kitchen_timers_screen.dart';
import 'package:recipetools/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService', () {
    setUp(() {
      NotificationService().resetForTesting();
    });

    test('initialize completes without error', () async {
      await expectLater(NotificationService().initialize(), completes);
    });

    test('initialize is idempotent', () async {
      await NotificationService().initialize();
      await expectLater(NotificationService().initialize(), completes);
    });

    test('requestPermission returns safely without throwing', () async {
      final result = await NotificationService().requestPermission();
      expect(result, isA<bool>());
    });

    test('requestNotificationsPermission alias returns safely', () async {
      final result = await NotificationService().requestNotificationsPermission();
      expect(result, anyOf(isNull, isA<bool>()));
    });

    test('showTimerFinishedNotification does not throw uncaught exceptions', () async {
      await expectLater(
        NotificationService().showTimerFinishedNotification(
          id: 1234,
          title: 'Timer Done',
          body: 'Your pasta timer is ready',
        ),
        completes,
      );
    });

    test('cancelNotification does not throw uncaught exceptions', () async {
      await expectLater(
        NotificationService().cancelNotification(1234),
        completes,
      );
    });
  });

  group('KitchenTimersScreen Notification Integration', () {
    testWidgets('renders KitchenTimersScreen and handles post-frame permission request safely', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: KitchenTimersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(KitchenTimersScreen), findsOneWidget);
    });
  });
}
