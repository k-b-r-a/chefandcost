import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ad_service.dart';
import 'cloud_sync_provider.dart';
import 'monetization_provider.dart';
import 'settings_provider.dart';

class AdState {
  final DateTime? adFreeUntil;
  final bool hasActiveSubscription;
  final bool isLoadingRewardedAd;
  final String? errorMessage;
  final DateTime? lastRefreshed;

  const AdState({
    this.adFreeUntil,
    this.hasActiveSubscription = false,
    this.isLoadingRewardedAd = false,
    this.errorMessage,
    this.lastRefreshed,
  });

  /// Alias for isLoadingRewardedAd
  bool get isRewardedAdLoading => isLoadingRewardedAd;

  /// Exposes whether the user has an active Cloud Sync subscription.
  bool get isSubscribed => hasActiveSubscription;

  /// Int timestamp persisted in SharedPreferences.
  int? get adFreeUntilMillis => adFreeUntil?.millisecondsSinceEpoch;

  /// Evaluates isAdFree as true whenever the user has an active Cloud Sync subscription
  /// or a valid, non-expired adFreeUntil timestamp.
  bool get isAdFree {
    if (isSubscribed) return true;
    if (adFreeUntil != null && DateTime.now().isBefore(adFreeUntil!)) {
      return true;
    }
    return false;
  }

  /// Calculates the remaining ad-free duration.
  Duration get remainingAdFreeTime {
    if (isSubscribed) return Duration.zero;
    if (adFreeUntil == null) return Duration.zero;
    final diff = adFreeUntil!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  AdState copyWith({
    DateTime? adFreeUntil,
    bool clearAdFreeUntil = false,
    bool? hasActiveSubscription,
    bool? isLoadingRewardedAd,
    bool? isRewardedAdLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? lastRefreshed,
  }) {
    return AdState(
      adFreeUntil: clearAdFreeUntil ? null : (adFreeUntil ?? this.adFreeUntil),
      hasActiveSubscription:
          hasActiveSubscription ?? this.hasActiveSubscription,
      isLoadingRewardedAd: isLoadingRewardedAd ??
          isRewardedAdLoading ??
          this.isLoadingRewardedAd,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdState &&
          runtimeType == other.runtimeType &&
          adFreeUntil == other.adFreeUntil &&
          hasActiveSubscription == other.hasActiveSubscription &&
          isLoadingRewardedAd == other.isLoadingRewardedAd &&
          errorMessage == other.errorMessage &&
          lastRefreshed == other.lastRefreshed;

  @override
  int get hashCode => Object.hash(
        adFreeUntil,
        hasActiveSubscription,
        isLoadingRewardedAd,
        errorMessage,
        lastRefreshed,
      );
}

class AdNotifier extends Notifier<AdState> {
  static const String adFreeUntilPrefKey = 'ad_free_until';
  Timer? _periodicTimer;
  SharedPreferences? _prefs;

  @override
  AdState build() {
    final isCloudSubscribed =
        ref.watch(cloudSyncProvider.select((s) => s.isSubscribed));
    final monetization = ref.watch(monetizationProvider);

    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _tick();
    });

    ref.onDispose(() {
      _periodicTimer?.cancel();
    });

    DateTime? initialUntil = monetization.adFreeUntil;
    try {
      _prefs = ref.watch(sharedPreferencesProvider);
      final raw = _prefs?.getInt(adFreeUntilPrefKey) ??
          _prefs?.getInt(MonetizationNotifier.adFreeUntilPrefKey);
      if (raw != null && initialUntil == null) {
        final parsed = DateTime.fromMillisecondsSinceEpoch(raw);
        if (DateTime.now().isBefore(parsed)) {
          initialUntil = parsed;
        }
      }
    } catch (_) {
      _initAsyncPrefs();
    }

    return AdState(
      adFreeUntil: initialUntil,
      hasActiveSubscription:
          isCloudSubscribed || monetization.hasActiveSubscription,
      isLoadingRewardedAd: monetization.isLoadingRewardedAd,
      errorMessage: monetization.errorMessage,
      lastRefreshed: monetization.lastRefreshed ?? DateTime.now(),
    );
  }

  Future<void> _initAsyncPrefs() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs?.getInt(adFreeUntilPrefKey) ??
          _prefs?.getInt(MonetizationNotifier.adFreeUntilPrefKey);
      if (raw != null) {
        final parsed = DateTime.fromMillisecondsSinceEpoch(raw);
        if (DateTime.now().isBefore(parsed)) {
          state = state.copyWith(adFreeUntil: parsed);
        }
      }
    } catch (_) {}
  }

  void _tick() {
    state = state.copyWith(lastRefreshed: DateTime.now());
  }

  void refresh() => _tick();

  /// Unlocks an 8-hour ad-free window and persists the expiration timestamp.
  Future<void> unlockAdFreeFor8Hours() async {
    final until = DateTime.now().add(const Duration(hours: 8));
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setInt(adFreeUntilPrefKey, until.millisecondsSinceEpoch);
      await _prefs?.setInt(
        MonetizationNotifier.adFreeUntilPrefKey,
        until.millisecondsSinceEpoch,
      );
    } catch (_) {}

    await ref
        .read(monetizationProvider.notifier)
        .activateEightHourAdFreePass(explicitUntil: until);

    state = state.copyWith(
      adFreeUntil: until,
      isLoadingRewardedAd: false,
      clearErrorMessage: true,
      lastRefreshed: DateTime.now(),
    );
  }

  /// Backward-compatible alias for unlocking with optional duration.
  Future<void> unlockAdFreePass({
    Duration duration = const Duration(hours: 8),
    DateTime? explicitUntil,
  }) async {
    final until = explicitUntil ?? DateTime.now().add(duration);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setInt(adFreeUntilPrefKey, until.millisecondsSinceEpoch);
      await _prefs?.setInt(
        MonetizationNotifier.adFreeUntilPrefKey,
        until.millisecondsSinceEpoch,
      );
    } catch (_) {}

    await ref
        .read(monetizationProvider.notifier)
        .activateEightHourAdFreePass(explicitUntil: until);

    state = state.copyWith(
      adFreeUntil: until,
      isLoadingRewardedAd: false,
      clearErrorMessage: true,
      lastRefreshed: DateTime.now(),
    );
  }

  /// Clears active ad-free pass timestamp.
  Future<void> clearAdFreePass() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.remove(adFreeUntilPrefKey);
      await _prefs?.remove(MonetizationNotifier.adFreeUntilPrefKey);
    } catch (_) {}

    await ref.read(monetizationProvider.notifier).clearAdFreePass();

    state = state.copyWith(
      clearAdFreeUntil: true,
      lastRefreshed: DateTime.now(),
    );
  }

  /// Loads and shows a 30-second RewardedAd, calling [unlockAdFreeFor8Hours] upon user completion.
  Future<bool> watchRewardedAdFor8Hours({
    required VoidCallback onSuccess,
    required VoidCallback onError,
  }) async {
    state = state.copyWith(isLoadingRewardedAd: true, clearErrorMessage: true);
    final success = await AdService.showRewardedAd(
      onUserEarnedReward: () async {
        await unlockAdFreeFor8Hours();
        onSuccess();
      },
      onAdFailed: (error) {
        state = state.copyWith(
          isLoadingRewardedAd: false,
          errorMessage: error,
          lastRefreshed: DateTime.now(),
        );
        onError();
      },
    );

    if (!success && state.isLoadingRewardedAd) {
      state = state.copyWith(isLoadingRewardedAd: false);
    }
    return success;
  }

  /// Backward-compatible alias for watchRewardedAd
  Future<bool> watchRewardedAd({
    void Function()? onUnlocked,
    void Function(String error)? onError,
  }) async {
    return watchRewardedAdFor8Hours(
      onSuccess: () => onUnlocked?.call(),
      onError: () => onError?.call(state.errorMessage ?? 'Ad failed'),
    );
  }
}

final adNotifierProvider =
    NotifierProvider<AdNotifier, AdState>(AdNotifier.new);
final adProvider = adNotifierProvider;
