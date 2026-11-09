import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../services/ad_service.dart';
import '../services/play_integrity_service.dart';
import '../utils/firestore_sync_service.dart';
import 'cloud_sync_provider.dart';
import 'settings_provider.dart';

class MonetizationState {
  final bool hasActiveSubscription;
  final String? activePlanId;
  final DateTime? subscriptionExpiresAt;
  final DateTime? adFreeUntil;
  final bool isLoadingPurchase;
  final bool isRewardedAdReady;
  final bool isLoadingRewardedAd;
  final String? errorMessage;
  final String? successMessage;
  final DateTime? lastRefreshed;

  const MonetizationState({
    this.hasActiveSubscription = false,
    this.activePlanId,
    this.subscriptionExpiresAt,
    this.adFreeUntil,
    this.isLoadingPurchase = false,
    this.isRewardedAdReady = false,
    this.isLoadingRewardedAd = false,
    this.errorMessage,
    this.successMessage,
    this.lastRefreshed,
  });

  bool get canUseCloudSync => hasActiveSubscription;
  bool get isSubscribed => hasActiveSubscription;

  bool get isRewardedPassActive =>
      adFreeUntil != null && DateTime.now().isBefore(adFreeUntil!);

  bool get isAdFree => hasActiveSubscription || isRewardedPassActive;

  Duration get remainingAdFreeTime {
    if (!isRewardedPassActive) return Duration.zero;
    final diff = adFreeUntil!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  int? get adFreeUntilMillis => adFreeUntil?.millisecondsSinceEpoch;

  bool get isAnnualPlan =>
      activePlanId != null && activePlanId!.toLowerCase().contains('annual');

  bool get isMonthlyPlan =>
      activePlanId != null && activePlanId!.toLowerCase().contains('monthly');

  MonetizationState copyWith({
    bool? hasActiveSubscription,
    String? activePlanId,
    bool clearActivePlanId = false,
    DateTime? subscriptionExpiresAt,
    bool clearSubscriptionExpiresAt = false,
    DateTime? adFreeUntil,
    bool clearAdFreeUntil = false,
    bool? isLoadingPurchase,
    bool? isRewardedAdReady,
    bool? isLoadingRewardedAd,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? successMessage,
    bool clearSuccessMessage = false,
    DateTime? lastRefreshed,
  }) {
    return MonetizationState(
      hasActiveSubscription:
          hasActiveSubscription ?? this.hasActiveSubscription,
      activePlanId:
          clearActivePlanId ? null : (activePlanId ?? this.activePlanId),
      subscriptionExpiresAt: clearSubscriptionExpiresAt
          ? null
          : (subscriptionExpiresAt ?? this.subscriptionExpiresAt),
      adFreeUntil: clearAdFreeUntil ? null : (adFreeUntil ?? this.adFreeUntil),
      isLoadingPurchase: isLoadingPurchase ?? this.isLoadingPurchase,
      isRewardedAdReady: isRewardedAdReady ?? this.isRewardedAdReady,
      isLoadingRewardedAd: isLoadingRewardedAd ?? this.isLoadingRewardedAd,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccessMessage ? null : (successMessage ?? this.successMessage),
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonetizationState &&
          runtimeType == other.runtimeType &&
          hasActiveSubscription == other.hasActiveSubscription &&
          activePlanId == other.activePlanId &&
          subscriptionExpiresAt == other.subscriptionExpiresAt &&
          adFreeUntil == other.adFreeUntil &&
          isLoadingPurchase == other.isLoadingPurchase &&
          isRewardedAdReady == other.isRewardedAdReady &&
          isLoadingRewardedAd == other.isLoadingRewardedAd &&
          errorMessage == other.errorMessage &&
          successMessage == other.successMessage &&
          lastRefreshed == other.lastRefreshed;

  @override
  int get hashCode => Object.hash(
        hasActiveSubscription,
        activePlanId,
        subscriptionExpiresAt,
        adFreeUntil,
        isLoadingPurchase,
        isRewardedAdReady,
        isLoadingRewardedAd,
        errorMessage,
        successMessage,
        lastRefreshed,
      );
}

class MonetizationNotifier extends Notifier<MonetizationState> {
  static const String hasActiveSubPrefKey = 'monetization_has_active_sub';
  static const String activePlanIdPrefKey = 'monetization_active_plan_id';
  static const String adFreeUntilPrefKey = 'monetization_ad_free_until_ms';
  static const String legacyAdFreeUntilPrefKey = 'ad_free_until';
  static const String legacyCloudSubPrefKey = 'cloud_sync_is_subscribed';
  static const String legacyCloudPlanPrefKey = 'cloud_sync_subscription_plan';
  static const String legacyCloudExpiresPrefKey =
      'cloud_sync_subscription_expires_at';

  Timer? _periodicTimer;
  Timer? _expirationTimer;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  VoidCallback? _adReadyListener;
  SharedPreferences? _prefs;
  bool _disposed = false;

  static bool get _canUseNativeStore {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// For automated testing: allows overriding sandbox fallback behavior.
  @visibleForTesting
  static bool? debugAllowSandboxFallback;

  /// Whether sandbox / fallback activation is permitted.
  /// Strictly prohibited in release builds (!kReleaseMode) unless running in an automated test environment.
  static bool get allowSandboxFallback => _allowSandboxFallback;

  static bool get _allowSandboxFallback {
    if (debugAllowSandboxFallback != null) {
      return debugAllowSandboxFallback!;
    }
    if (kIsWeb) {
      return !kReleaseMode;
    }
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
      return !kReleaseMode;
    } catch (_) {
      return !kReleaseMode;
    }
  }

  @override
  MonetizationState build() {
    _disposed = false;

    final cloudSubTuple = ref.watch(
      cloudSyncProvider.select(
        (s) => (s.isSubscribed, s.subscriptionPlan, s.subscriptionExpiresAt),
      ),
    );

    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _tick();
    });

    _adReadyListener = () {
      if (!_disposed) {
        state = state.copyWith(
          isRewardedAdReady: AdService.isRewardedAdReady,
        );
      }
    };
    AdService.rewardedAdReadyNotifier.addListener(_adReadyListener!);

    _initPurchaseStream();
    AdService.preloadRewardedAd();
    if (_canUseNativeStore) {
      unawaited(PlayIntegrityService.prepareTokenProvider());
    }

    ref.onDispose(() {
      _disposed = true;
      _periodicTimer?.cancel();
      _expirationTimer?.cancel();
      _purchaseSubscription?.cancel();
      if (_adReadyListener != null) {
        AdService.rewardedAdReadyNotifier.removeListener(_adReadyListener!);
      }
    });

    bool initialSub = cloudSubTuple.$1;
    String? initialPlan = cloudSubTuple.$2;
    DateTime? initialExpires = cloudSubTuple.$3;
    DateTime? initialAdFreeUntil;

    try {
      _prefs = ref.watch(sharedPreferencesProvider);
      if (_prefs != null) {
        final hydrated = _readFromPrefs(_prefs!, cloudSubTuple);
        initialSub = hydrated.hasSub;
        initialPlan = hydrated.planId;
        initialExpires = hydrated.expiresAt;
        initialAdFreeUntil = hydrated.adFreeUntil;
      }
    } catch (_) {
      _initAsyncPrefs();
    }

    _scheduleExpirationTimer(initialAdFreeUntil);

    return MonetizationState(
      hasActiveSubscription: initialSub,
      activePlanId: initialPlan,
      subscriptionExpiresAt: initialExpires,
      adFreeUntil: initialAdFreeUntil,
      isRewardedAdReady: AdService.isRewardedAdReady,
      lastRefreshed: DateTime.now(),
    );
  }

  ({
    bool hasSub,
    String? planId,
    DateTime? expiresAt,
    DateTime? adFreeUntil,
  }) _readFromPrefs(
    SharedPreferences prefs,
    (bool, String?, DateTime?) cloudSubTuple,
  ) {
    final now = DateTime.now();

    final prefSub = prefs.getBool(hasActiveSubPrefKey) ??
        prefs.getBool(legacyCloudSubPrefKey) ??
        false;
    bool hasSub = cloudSubTuple.$1 || prefSub;
    String? planId = cloudSubTuple.$2 ??
        prefs.getString(activePlanIdPrefKey) ??
        prefs.getString(legacyCloudPlanPrefKey);

    final expiresMs = prefs.getInt(legacyCloudExpiresPrefKey);
    DateTime? expiresAt = cloudSubTuple.$3 ??
        (expiresMs != null
            ? DateTime.fromMillisecondsSinceEpoch(expiresMs)
            : null);

    if (hasSub && expiresAt != null && expiresAt.isBefore(now)) {
      hasSub = false;
      planId = null;
    }

    final rawUntil = prefs.getInt(adFreeUntilPrefKey) ??
        prefs.getInt(legacyAdFreeUntilPrefKey);
    DateTime? adFreeUntil;
    if (rawUntil != null) {
      final parsed = DateTime.fromMillisecondsSinceEpoch(rawUntil);
      if (now.isBefore(parsed)) {
        adFreeUntil = parsed;
      }
    }

    return (
      hasSub: hasSub,
      planId: hasSub ? planId : null,
      expiresAt: expiresAt,
      adFreeUntil: adFreeUntil,
    );
  }

  Future<void> _initAsyncPrefs() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (_disposed || _prefs == null) return;
      final cloudState = ref.read(cloudSyncProvider);
      final hydrated = _readFromPrefs(
        _prefs!,
        (
          cloudState.isSubscribed,
          cloudState.subscriptionPlan,
          cloudState.subscriptionExpiresAt,
        ),
      );
      _scheduleExpirationTimer(hydrated.adFreeUntil);
      state = state.copyWith(
        hasActiveSubscription: hydrated.hasSub,
        activePlanId: hydrated.planId,
        clearActivePlanId: hydrated.planId == null,
        subscriptionExpiresAt: hydrated.expiresAt,
        adFreeUntil: hydrated.adFreeUntil,
        clearAdFreeUntil: hydrated.adFreeUntil == null,
        lastRefreshed: DateTime.now(),
      );
    } catch (_) {}
  }

  void _scheduleExpirationTimer(DateTime? until) {
    _expirationTimer?.cancel();
    if (until == null) return;
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) {
      return;
    }
    _expirationTimer = Timer(remaining, () {
      if (_disposed) return;
      _onPassExpired();
    });
  }

  Future<void> _onPassExpired() async {
    if (_disposed) return;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.remove(adFreeUntilPrefKey);
      await _prefs?.remove(legacyAdFreeUntilPrefKey);
    } catch (_) {}
    if (_disposed) return;
    state = state.copyWith(
      clearAdFreeUntil: true,
      lastRefreshed: DateTime.now(),
    );
  }

  void _tick() {
    if (_disposed) return;
    final until = state.adFreeUntil;
    if (until != null && !DateTime.now().isBefore(until)) {
      _onPassExpired();
      return;
    }
    state = state.copyWith(lastRefreshed: DateTime.now());
  }

  void refresh() => _tick();

  void _initPurchaseStream() {
    if (!_canUseNativeStore) return;
    try {
      _purchaseSubscription?.cancel();
      _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
        _onPurchaseUpdates,
        onError: (Object error) {
          if (!_disposed) {
            state = state.copyWith(
              isLoadingPurchase: false,
              errorMessage: error.toString(),
            );
          }
        },
      );
    } catch (_) {}
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        if (!_disposed) {
          state = state.copyWith(isLoadingPurchase: true);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        if (purchase.pendingCompletePurchase) {
          try {
            await InAppPurchase.instance.completePurchase(purchase);
          } catch (_) {}
        }
        if (!_disposed) {
          state = state.copyWith(
            isLoadingPurchase: false,
            errorMessage:
                purchase.error?.message ?? 'subscription_store_unavailable',
          );
        }
      } else if (purchase.status == PurchaseStatus.canceled) {
        if (purchase.pendingCompletePurchase) {
          try {
            await InAppPurchase.instance.completePurchase(purchase);
          } catch (_) {}
        }
        if (!_disposed) {
          state = state.copyWith(
            isLoadingPurchase: false,
            errorMessage: 'subscription_purchase_canceled',
          );
        }
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (purchase.pendingCompletePurchase) {
          try {
            await InAppPurchase.instance.completePurchase(purchase);
          } catch (_) {}
        }
        final isAnnual = purchase.productID.contains('annual');
        final normalizedPlan =
            isAnnual ? kAnnualSubscriptionId : kMonthlySubscriptionId;
        final expiresAt = DateTime.now().add(
          isAnnual ? const Duration(days: 365) : const Duration(days: 30),
        );
        await setSubscription(
          isSubscribed: true,
          planId: normalizedPlan,
          expiresAt: expiresAt,
          successMessage: purchase.status == PurchaseStatus.restored
              ? 'subscription_restored_success'
              : 'subscription_activated_success',
        );
      }
    }
  }

  /// Activates or updates the subscription state and synchronizes with CloudSyncNotifier & SharedPreferences.
  Future<void> setSubscription({
    required bool isSubscribed,
    String? planId,
    DateTime? expiresAt,
    String? successMessage,
    bool syncToCloudNotifier = true,
  }) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setBool(hasActiveSubPrefKey, isSubscribed);
      await _prefs?.setBool(legacyCloudSubPrefKey, isSubscribed);
      if (isSubscribed && planId != null) {
        await _prefs?.setString(activePlanIdPrefKey, planId);
        await _prefs?.setString(legacyCloudPlanPrefKey, planId);
      } else if (!isSubscribed) {
        await _prefs?.remove(activePlanIdPrefKey);
        await _prefs?.remove(legacyCloudPlanPrefKey);
      }
      if (isSubscribed && expiresAt != null) {
        await _prefs?.setInt(
          legacyCloudExpiresPrefKey,
          expiresAt.millisecondsSinceEpoch,
        );
      } else if (!isSubscribed) {
        await _prefs?.remove(legacyCloudExpiresPrefKey);
      }
    } catch (_) {}

    if (syncToCloudNotifier && !_disposed) {
      try {
        await ref.read(cloudSyncProvider.notifier).setSubscription(
              isSubscribed: isSubscribed,
              plan: isSubscribed ? planId : null,
              expiresAt: isSubscribed ? expiresAt : null,
              syncToMonetization: false,
            );
      } catch (_) {}
    }

    if (!_disposed) {
      state = state.copyWith(
        hasActiveSubscription: isSubscribed,
        activePlanId: isSubscribed ? planId : null,
        clearActivePlanId: !isSubscribed || planId == null,
        subscriptionExpiresAt: isSubscribed ? expiresAt : null,
        clearSubscriptionExpiresAt: !isSubscribed || expiresAt == null,
        isLoadingPurchase: false,
        clearErrorMessage: true,
        successMessage: successMessage,
        lastRefreshed: DateTime.now(),
      );
    }
  }

  /// Initiates purchase of the $1.99/month Cloud Sync & Ad-Free plan.
  Future<bool> buyMonthly() => purchasePlan(kMonthlySubscriptionId);

  /// Initiates purchase of the $14.99/year Cloud Sync & Ad-Free plan.
  Future<bool> buyAnnual() => purchasePlan(kAnnualSubscriptionId);

  /// Generates a deterministic, privacy-preserving 64-character hex SHA-256 string
  /// for Google Play Billing fraud prevention (obfuscatedAccountId & obfuscatedProfileId).
  static String generateObfuscatedId(String input, {String salt = ''}) {
    final raw = '$input::$salt';
    final bytes = utf8.encode(raw);
    return sha256.convert(bytes).toString();
  }

  /// Resolves the current user account identifier (Firebase Auth UID or persistent anonymous device UUID).
  Future<String> _resolveUserAccountId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid.isNotEmpty) {
        return user.uid;
      }
    } catch (_) {}

    try {
      _prefs ??= await SharedPreferences.getInstance();
      var anonId = _prefs?.getString('security_anon_account_id');
      if (anonId == null || anonId.isEmpty) {
        anonId = const Uuid().v4();
        await _prefs?.setString('security_anon_account_id', anonId);
      }
      return anonId;
    } catch (_) {
      return 'anonymous_user_device';
    }
  }

  /// Purchases a subscription plan via Store Billing or falls back to sandbox mode
  /// when running on Web/Desktop, test environments, or debug builds without live SKUs.
  Future<bool> purchasePlan(String planId) async {
    state = state.copyWith(
      isLoadingPurchase: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );

    final isAnnual = planId.toLowerCase().contains('annual');
    final normalizedSku =
        isAnnual ? kAnnualSubscriptionId : kMonthlySubscriptionId;

    if (_canUseNativeStore) {
      try {
        final available = await InAppPurchase.instance.isAvailable();
        if (available) {
          final response = await InAppPurchase.instance.queryProductDetails({
            normalizedSku,
            planId,
          });
          if (response.productDetails.isNotEmpty) {
            final productDetails = response.productDetails.first;

            // Generate cryptographically safe obfuscated account and profile IDs
            // to enable Google Play Billing Fraud & Abuse monitoring, Gift Card protection,
            // Location Spoofing protection, and Offer Usage Limits.
            final rawAccountId = await _resolveUserAccountId();
            final obfuscatedAccountId = generateObfuscatedId(
              rawAccountId,
              salt: 'chefy_billing_account',
            );
            final obfuscatedProfileId = generateObfuscatedId(
              rawAccountId,
              salt: 'chefy_billing_profile',
            );

            // Concurrently obtain Play Integrity Token for checkout attestation
            try {
              unawaited(
                PlayIntegrityService.requestTokenForAction(
                  action: 'billing_checkout',
                  userId: obfuscatedAccountId,
                  metadata: {'planId': planId, 'sku': productDetails.id},
                ).then((result) {
                  if (result.isSuccess && result.token != null) {
                    debugPrint(
                      '[PlayBillingSecurity] Pre-checkout integrity token obtained (${result.type}).',
                    );
                  }
                }).catchError((_) {}),
              );
            } catch (_) {}

            // Android-specific: Pass obfuscatedAccountId and obfuscatedProfileId in BillingFlowParams
            if (!kIsWeb &&
                Platform.isAndroid &&
                InAppPurchasePlatform.instance is InAppPurchaseAndroidPlatform) {
              final androidPlatform =
                  InAppPurchasePlatform.instance as InAppPurchaseAndroidPlatform;
              String? offerToken;
              if (productDetails is GooglePlayProductDetails) {
                offerToken = productDetails.offerToken;
              }

              // ignore: invalid_use_of_visible_for_testing_member
              final manager = androidPlatform.billingClientManager;
              final billingResult = await manager.runWithClient(
                (BillingClient client) => client.launchBillingFlow(
                  product: productDetails.id,
                  offerToken: offerToken,
                  accountId: obfuscatedAccountId,
                  obfuscatedProfileId: obfuscatedProfileId,
                ),
              );

              if (billingResult.responseCode == BillingResponse.ok) {
                debugPrint(
                  '[PlayBillingSecurity] Successfully launched BillingFlowParams with obfuscatedAccountId & obfuscatedProfileId.',
                );
                return true;
              }
            }

            // Universal fallback (cross-platform PurchaseParam)
            final param = PurchaseParam(
              productDetails: productDetails,
              applicationUserName: obfuscatedAccountId,
            );
            final launched = await InAppPurchase.instance.buyNonConsumable(
              purchaseParam: param,
            );
            if (launched) {
              return true;
            }
          }
        }
        debugPrint(
          'Store products not found or store unavailable; checking sandbox fallback permission.',
        );
      } catch (e) {
        debugPrint(
          'Error querying store products ($e); checking sandbox fallback permission.',
        );
      }

      // If native store was queried but failed, and sandbox fallback is not permitted, fail securely
      if (!_allowSandboxFallback) {
        state = state.copyWith(
          isLoadingPurchase: false,
          errorMessage: 'subscription_store_unavailable',
        );
        return false;
      }
    }

    // Security Hardening: Never grant free subscriptions in release builds!
    if (!_allowSandboxFallback) {
      debugPrint('[Security] Sandbox subscription fallback blocked in release mode.');
      state = state.copyWith(
        isLoadingPurchase: false,
        errorMessage: 'subscription_store_unavailable',
      );
      return false;
    }

    // Sandbox / Fallback Testing Mode (Debug / Profile builds, Flutter Test)
    final expiresAt = DateTime.now().add(
      isAnnual ? const Duration(days: 365) : const Duration(days: 30),
    );
    await setSubscription(
      isSubscribed: true,
      planId: normalizedSku,
      expiresAt: expiresAt,
      successMessage: 'subscription_activated_success',
    );
    return true;
  }

  /// Restores previous subscriptions from the Store or local cache.
  Future<bool> restorePurchases() async {
    state = state.copyWith(
      isLoadingPurchase: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );

    if (_canUseNativeStore) {
      try {
        final available = await InAppPurchase.instance.isAvailable();
        if (available) {
          await InAppPurchase.instance.restorePurchases();
          if (!_disposed && state.isLoadingPurchase) {
            state = state.copyWith(isLoadingPurchase: false);
          }
          return state.hasActiveSubscription;
        }
      } catch (e) {
        debugPrint('Error during store restorePurchases ($e); checking local cache.');
      }
    }

    // Check Firestore remote entitlement (owner/lifetime/VIP grants)
    try {
      final firestoreService = FirestoreSyncService();
      final remote = await firestoreService.checkRemoteEntitlement();
      if (remote.isGranted) {
        await setSubscription(
          isSubscribed: true,
          planId: remote.plan,
          expiresAt: null,
          successMessage: 'subscription_restored_success',
        );
        return true;
      }
    } catch (e) {
      debugPrint('Error checking remote Firestore entitlement on restore: $e');
    }

    // Check SharedPreferences in sandbox/offline/test mode
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final savedSub = _prefs?.getBool(hasActiveSubPrefKey) ??
          _prefs?.getBool(legacyCloudSubPrefKey) ??
          false;
      final savedPlan = _prefs?.getString(activePlanIdPrefKey) ??
          _prefs?.getString(legacyCloudPlanPrefKey);
      if (savedSub) {
        await setSubscription(
          isSubscribed: true,
          planId: savedPlan ?? kMonthlySubscriptionId,
          successMessage: 'subscription_restored_success',
        );
        return true;
      }
    } catch (_) {}

    if (!_disposed) {
      state = state.copyWith(
        isLoadingPurchase: false,
        errorMessage: 'subscription_restore_none_found',
      );
    }
    return false;
  }

  /// Cancels active subscription (used in tests/debug).
  Future<void> cancelSubscription() async {
    await setSubscription(isSubscribed: false, planId: null, expiresAt: null);
  }

  /// Unlocks an 8-hour ad-free window and persists the expiration timestamp immediately.
  Future<void> activateEightHourAdFreePass({
    Duration duration = const Duration(hours: 8),
    DateTime? explicitUntil,
  }) async {
    final until = explicitUntil ?? DateTime.now().add(duration);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setInt(adFreeUntilPrefKey, until.millisecondsSinceEpoch);
      await _prefs?.setInt(
        legacyAdFreeUntilPrefKey,
        until.millisecondsSinceEpoch,
      );
    } catch (_) {}

    _scheduleExpirationTimer(until);

    if (!_disposed) {
      state = state.copyWith(
        adFreeUntil: until,
        isLoadingRewardedAd: false,
        clearErrorMessage: true,
        successMessage: 'ad_free_pass_unlocked_snackbar',
        lastRefreshed: DateTime.now(),
      );
    }
  }

  /// Alias for [activateEightHourAdFreePass].
  Future<void> unlockAdFreeFor8Hours() => activateEightHourAdFreePass();

  /// Clears active ad-free pass timestamp.
  Future<void> clearAdFreePass() async {
    _expirationTimer?.cancel();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.remove(adFreeUntilPrefKey);
      await _prefs?.remove(legacyAdFreeUntilPrefKey);
    } catch (_) {}

    if (!_disposed) {
      state = state.copyWith(
        clearAdFreeUntil: true,
        lastRefreshed: DateTime.now(),
      );
    }
  }

  /// Shows a Rewarded Video Ad and grants the 8-hour pass strictly inside [onUserEarnedReward].
  Future<bool> watchRewardedAdFor8Hours({
    VoidCallback? onSuccess,
    VoidCallback? onError,
    bool simulateWhenUnsupported = true,
  }) async {
    state = state.copyWith(
      isLoadingRewardedAd: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );

    bool rewardGranted = false;
    final success = await AdService.showRewardedAd(
      simulateWhenUnsupported: simulateWhenUnsupported,
      onUserEarnedReward: () async {
        rewardGranted = true;
        await activateEightHourAdFreePass();
        onSuccess?.call();
      },
      onAdFailed: (error) {
        if (!_disposed) {
          state = state.copyWith(
            isLoadingRewardedAd: false,
            errorMessage: error,
            lastRefreshed: DateTime.now(),
          );
        }
        onError?.call();
      },
    );

    if ((!success || !rewardGranted) && !_disposed && state.isLoadingRewardedAd) {
      state = state.copyWith(isLoadingRewardedAd: false);
    }
    return success && rewardGranted;
  }
}

final monetizationProvider =
    NotifierProvider<MonetizationNotifier, MonetizationState>(
  MonetizationNotifier.new,
);
