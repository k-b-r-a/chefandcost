import 'dart:async';
import 'package:flutter/widgets.dart';
import '../services/ad_service.dart';

/// Lightweight [NavigatorObserver] that evaluates whether ads need preloading
/// or refreshing after a pushed route is popped, waiting for the route
/// transition animation to finish so back-swipes never stutter.
class AdNavigationObserver extends NavigatorObserver {
  final bool Function()? isAdFreeProvider;
  final Duration transitionDelay;
  final Future<bool> Function()? onEvaluateAds;

  AdNavigationObserver({
    this.isAdFreeProvider,
    this.transitionDelay = const Duration(milliseconds: 350),
    this.onEvaluateAds,
  });

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute == null) return;

    unawaited(
      Future<void>.delayed(transitionDelay, () async {
        if (onEvaluateAds != null) {
          await onEvaluateAds!();
        } else {
          await AdService.evaluateAndPreloadAdsIfNeeded(
            isAdFree: isAdFreeProvider?.call(),
          );
        }
      }),
    );
  }
}
