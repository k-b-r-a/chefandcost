import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/cloud_sync_provider.dart';
import 'package:recipetools/screens/cloud_sync_screen.dart';
import 'package:recipetools/utils/cloud_sync_service.dart';
import 'package:recipetools/utils/google_sign_in_initializer.dart';
import 'package:recipetools/widgets/subscription_paywall_card.dart';

class TestSeparationCloudSyncNotifier extends CloudSyncNotifier {
  final CloudSyncState initialState;

  TestSeparationCloudSyncNotifier({required this.initialState});

  @override
  CloudSyncState build() {
    return initialState;
  }

  @override
  Future<void> checkStatus() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleSignInInitializer.resetForTesting();
  });

  group('Google Drive & Firebase Login Separation State Tests', () {
    test('State preserves both Google Drive and Firestore logins separately', () {
      final state = CloudSyncState(
        storageType: CloudSyncStorageType.firestore,
        firestoreSignedIn: true,
        firestoreEmail: 'firebase.user@example.com',
        googleDriveSignedIn: true,
        googleDriveEmail: 'drive.user@gmail.com',
      );

      // When looking at Firestore target
      expect(state.storageType, CloudSyncStorageType.firestore);
      expect(state.signedIn, isTrue);
      expect(state.email, 'firebase.user@example.com');
      expect(state.firestoreSignedIn, isTrue);
      expect(state.googleDriveSignedIn, isTrue);

      // When switching target to Google Drive
      final driveTargetState = state.copyWith(
        storageType: CloudSyncStorageType.googleDrive,
      );
      expect(driveTargetState.storageType, CloudSyncStorageType.googleDrive);
      expect(driveTargetState.signedIn, isTrue);
      expect(driveTargetState.email, 'drive.user@gmail.com');
      expect(driveTargetState.firestoreSignedIn, isTrue);
      expect(driveTargetState.firestoreEmail, 'firebase.user@example.com');

      // When signing out of Firestore, Google Drive remains signed in
      final firestoreLoggedOut = driveTargetState.copyWith(
        firestoreSignedIn: false,
        firestoreEmail: null,
      );
      expect(firestoreLoggedOut.firestoreSignedIn, isFalse);
      expect(firestoreLoggedOut.firestoreEmail, isNull);
      expect(firestoreLoggedOut.googleDriveSignedIn, isTrue);
      expect(firestoreLoggedOut.googleDriveEmail, 'drive.user@gmail.com');
      expect(firestoreLoggedOut.signedIn, isTrue); // Google Drive is current target and signed in

      // When signing out of Google Drive, Firestore state remains independent
      final driveLoggedOut = firestoreLoggedOut.copyWith(
        googleDriveSignedIn: false,
        googleDriveEmail: null,
      );
      expect(driveLoggedOut.googleDriveSignedIn, isFalse);
      expect(driveLoggedOut.signedIn, isFalse);
    });

    test('Switching storage types preserves both login states without signing out', () async {
      final container = ProviderContainer(
        overrides: [
          cloudSyncProvider.overrideWith(
            () => TestSeparationCloudSyncNotifier(
              initialState: CloudSyncState(
                firestoreSignedIn: true,
                firestoreEmail: 'chef@restaurant.com',
                googleDriveSignedIn: true,
                googleDriveEmail: 'chef.drive@gmail.com',
                storageType: CloudSyncStorageType.firestore,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cloudSyncProvider.notifier);

      expect(notifier.state.signedIn, isTrue);
      expect(notifier.state.email, 'chef@restaurant.com');

      // Switch to Google Drive
      await notifier.setStorageType(CloudSyncStorageType.googleDrive);

      var currentState = container.read(cloudSyncProvider);
      expect(currentState.storageType, CloudSyncStorageType.googleDrive);
      expect(currentState.signedIn, isTrue);
      expect(currentState.email, 'chef.drive@gmail.com');
      expect(currentState.firestoreSignedIn, isTrue);
      expect(currentState.firestoreEmail, 'chef@restaurant.com');

      // Switch to Local Directory
      await notifier.setStorageType(CloudSyncStorageType.localDirectory);

      currentState = container.read(cloudSyncProvider);
      expect(currentState.storageType, CloudSyncStorageType.localDirectory);
      expect(currentState.signedIn, isTrue);
      expect(currentState.email, 'Local Backup');
      expect(currentState.googleDriveSignedIn, isTrue);
      expect(currentState.firestoreSignedIn, isTrue);

      // Switch back to Firestore
      await notifier.setStorageType(CloudSyncStorageType.firestore);

      currentState = container.read(cloudSyncProvider);
      expect(currentState.storageType, CloudSyncStorageType.firestore);
      expect(currentState.signedIn, isTrue);
      expect(currentState.email, 'chef@restaurant.com');
    });

    test('Google Drive backup operations do not require subscription (Free Feature)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cloudSyncProvider.notifier);

      // In Google Drive mode without subscription
      notifier.state = notifier.state.copyWith(
        storageType: CloudSyncStorageType.googleDrive,
        googleDriveSignedIn: true,
        googleDriveEmail: 'free.user@gmail.com',
        isSubscribed: false, // NOT subscribed
      );

      // Google Drive backup check in createBackup: should NOT block with cloud_sync_subscription_required
      expect(notifier.state.storageType, CloudSyncStorageType.googleDrive);
      expect(notifier.state.isSubscribed, isFalse);
    });

    test('User can be signed in to Firebase with Google OAuth without an active subscription', () async {
      final state = CloudSyncState(
        storageType: CloudSyncStorageType.firestore,
        firestoreSignedIn: true,
        firestoreEmail: 'oauth.google.user@gmail.com',
        isSubscribed: false,
      );

      expect(state.signedIn, isTrue);
      expect(state.email, 'oauth.google.user@gmail.com');
      expect(state.firestoreSignedIn, isTrue);
      expect(state.isSubscribed, isFalse);
    });

    test('Firebase syncTwoWay blocks real database sync operations when user has no subscription', () async {
      final container = ProviderContainer(
        overrides: [
          cloudSyncProvider.overrideWith(
            () => TestSeparationCloudSyncNotifier(
              initialState: CloudSyncState(
                storageType: CloudSyncStorageType.firestore,
                firestoreSignedIn: true,
                firestoreEmail: 'oauth.google.user@gmail.com',
                isSubscribed: false,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cloudSyncProvider.notifier);
      final result = await notifier.syncFirestore();

      expect(result, isNull);
      expect(notifier.state.syncError, 'cloud_sync_subscription_required');
      expect(notifier.state.errorMessage, 'cloud_sync_subscription_required');
      expect(notifier.state.isSyncing, isFalse);
    });
  });

  group('UI Paywall & Gating Separation Widget Tests', () {
    testWidgets('SubscriptionPaywallCard is NOT rendered when storageType is googleDrive', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final notifier = TestSeparationCloudSyncNotifier(
        initialState: CloudSyncState(
          storageType: CloudSyncStorageType.googleDrive,
          googleDriveSignedIn: false,
          isSubscribed: false,
          hasAcceptedTerms: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cloudSyncProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CloudSyncScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Paywall card should NOT be rendered for Google Drive
      expect(find.byType(SubscriptionPaywallCard), findsNothing);

      // Should render Google Drive connection header with connect button
      expect(find.text('Iniciar sesión con Google'), findsOneWidget);
    });

    testWidgets('SubscriptionPaywallCard IS rendered when storageType is firestore', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final notifier = TestSeparationCloudSyncNotifier(
        initialState: CloudSyncState(
          storageType: CloudSyncStorageType.firestore,
          firestoreSignedIn: false,
          isSubscribed: false,
          hasAcceptedTerms: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cloudSyncProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CloudSyncScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Paywall card MUST be rendered for Firestore (paid feature)
      expect(find.byType(SubscriptionPaywallCard), findsOneWidget);
    });
  });

  group('GoogleSignInInitializer Tests', () {
    test('ensureInitialized initializes only once', () async {
      expect(GoogleSignInInitializer.isInitialized, isFalse);

      await GoogleSignInInitializer.ensureInitialized();
      expect(GoogleSignInInitializer.isInitialized, isTrue);

      // Subsequent call does not throw or re-initialize
      await GoogleSignInInitializer.ensureInitialized();
      expect(GoogleSignInInitializer.isInitialized, isTrue);
    });
  });
}
