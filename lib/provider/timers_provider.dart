import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';
import '../utils/notification_service.dart';
import '../utils/audio_alarm_service.dart';
import 'settings_provider.dart';

class KitchenTimerModel {
  final String id;
  final String name;
  final int totalSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final bool isFinished;
  final int colorIndex;
  final DateTime? finishedAt;
  final DateTime? targetEndTime;

  KitchenTimerModel({
    required this.id,
    required this.name,
    required this.totalSeconds,
    required this.remainingSeconds,
    this.isRunning = true,
    this.isFinished = false,
    this.colorIndex = 0,
    this.finishedAt,
    this.targetEndTime,
  });

  double get progress => totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;

  String get formattedTime {
    final hours = remainingSeconds ~/ 3600;
    final minutes = (remainingSeconds % 3600) ~/ 60;
    final seconds = remainingSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedFinishedTime {
    if (finishedAt == null) return '';
    final h = finishedAt!.hour.toString().padLeft(2, '0');
    final m = finishedAt!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'totalSeconds': totalSeconds,
        'remainingSeconds': remainingSeconds,
        'isRunning': isRunning,
        'isFinished': isFinished,
        'colorIndex': colorIndex,
        'finishedAt': finishedAt?.toIso8601String(),
        'targetEndTime': targetEndTime?.toIso8601String(),
      };

  factory KitchenTimerModel.fromJson(Map<String, dynamic> json) {
    return KitchenTimerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      totalSeconds: (json['totalSeconds'] as num).toInt(),
      remainingSeconds: (json['remainingSeconds'] as num).toInt(),
      isRunning: json['isRunning'] as bool? ?? false,
      isFinished: json['isFinished'] as bool? ?? false,
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      finishedAt: json['finishedAt'] != null
          ? DateTime.tryParse(json['finishedAt'] as String)
          : null,
      targetEndTime: json['targetEndTime'] != null
          ? DateTime.tryParse(json['targetEndTime'] as String)
          : null,
    );
  }

  KitchenTimerModel copyWith({
    String? id,
    String? name,
    int? totalSeconds,
    int? remainingSeconds,
    bool? isRunning,
    bool? isFinished,
    int? colorIndex,
    DateTime? finishedAt,
    DateTime? targetEndTime,
    bool clearTargetEndTime = false,
  }) {
    return KitchenTimerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      isFinished: isFinished ?? this.isFinished,
      colorIndex: colorIndex ?? this.colorIndex,
      finishedAt: finishedAt ?? this.finishedAt,
      targetEndTime:
          clearTargetEndTime ? null : (targetEndTime ?? this.targetEndTime),
    );
  }
}

class KitchenTimersNotifier extends Notifier<List<KitchenTimerModel>> {
  static const String _prefsKey = 'active_kitchen_timers_v1';
  Timer? _ticker;

  @override
  List<KitchenTimerModel> build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _ticker = null;
    });

    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = (jsonDecode(raw) as List<dynamic>)
            .whereType<Map>()
            .map((e) => KitchenTimerModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (decoded.isNotEmpty) {
          Future.microtask(() {
            _tick();
            _syncTicker();
          });
          return decoded;
        }
      }
    } catch (_) {}

    return [];
  }

  AppLocalizations _resolveL10n() {
    Locale? preferred;
    try {
      preferred = ref.read(settingsProvider).locale;
    } catch (_) {}
    final candidate = preferred ?? PlatformDispatcher.instance.locale;
    try {
      return lookupAppLocalizations(candidate);
    } catch (_) {
      try {
        return lookupAppLocalizations(Locale(candidate.languageCode));
      } catch (_) {
        return lookupAppLocalizations(const Locale('en'));
      }
    }
  }

  void _persistTimers() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final encoded = jsonEncode(state.map((t) => t.toJson()).toList());
      unawaited(prefs.setString(_prefsKey, encoded));
    } catch (_) {}
  }

  void _syncTicker() {
    final hasRunning = state.any((t) => t.isRunning && t.remainingSeconds > 0);
    if (hasRunning) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        _tick();
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _tick() {
    final now = DateTime.now();
    bool stateChanged = false;
    final updatedList = state.map((timer) {
      if (timer.isRunning && timer.remainingSeconds > 0) {
        stateChanged = true;
        final endTime =
            timer.targetEndTime ?? now.add(Duration(seconds: timer.remainingSeconds));
        final remainingMs = endTime.difference(now).inMilliseconds;
        final newRemaining = remainingMs <= 0 ? 0 : (remainingMs / 1000).ceil();

        if (newRemaining <= 0) {
          final timeStr =
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          AudioAlarmService().playAlarm();
          final l10n = _resolveL10n();
          NotificationService().showTimerFinishedNotification(
            id: timer.id.hashCode,
            title: l10n.timer_finished_notification_title,
            body: l10n.timer_finished_notification_body(timer.name, timeStr),
          );

          return timer.copyWith(
            remainingSeconds: 0,
            isRunning: false,
            isFinished: true,
            finishedAt: now,
            clearTargetEndTime: true,
          );
        }
        return timer.copyWith(
          remainingSeconds: newRemaining,
          targetEndTime: endTime,
        );
      }
      return timer;
    }).toList();

    if (stateChanged) {
      state = updatedList;
      _persistTimers();
    }
    _syncTicker();
  }

  void addTimer(String name, int seconds, {int colorIndex = 0}) {
    if (seconds <= 0) return;
    const uuid = Uuid();
    final now = DateTime.now();
    final newTimer = KitchenTimerModel(
      id: uuid.v4(),
      name: name.trim().isEmpty ? 'Timer' : name.trim(),
      totalSeconds: seconds,
      remainingSeconds: seconds,
      isRunning: true,
      isFinished: false,
      colorIndex: colorIndex,
      targetEndTime: now.add(Duration(seconds: seconds)),
    );

    state = [...state, newTimer];
    _persistTimers();
    _syncTicker();
  }

  void toggleTimer(String id) {
    final now = DateTime.now();
    state = state.map((timer) {
      if (timer.id == id && !timer.isFinished) {
        final nextRunning = !timer.isRunning;
        if (nextRunning) {
          return timer.copyWith(
            isRunning: true,
            targetEndTime: now.add(Duration(seconds: timer.remainingSeconds)),
          );
        } else {
          final remMs = timer.targetEndTime != null
              ? timer.targetEndTime!.difference(now).inMilliseconds
              : timer.remainingSeconds * 1000;
          final rem = remMs <= 0 ? 0 : (remMs / 1000).ceil();
          return timer.copyWith(
            isRunning: false,
            remainingSeconds: rem,
            clearTargetEndTime: true,
          );
        }
      }
      return timer;
    }).toList();
    _persistTimers();
    _syncTicker();
  }

  void resetTimer(String id) {
    final now = DateTime.now();
    state = state.map((timer) {
      if (timer.id == id) {
        return timer.copyWith(
          remainingSeconds: timer.totalSeconds,
          isRunning: true,
          isFinished: false,
          targetEndTime: now.add(Duration(seconds: timer.totalSeconds)),
        );
      }
      return timer;
    }).toList();
    _persistTimers();
    _syncTicker();
  }

  void addMinutes(String id, int minutes) {
    final now = DateTime.now();
    state = state.map((timer) {
      if (timer.id == id) {
        final addedSeconds = minutes * 60;
        final newRemaining = timer.remainingSeconds + addedSeconds;
        final newTotal = timer.totalSeconds + addedSeconds;
        return timer.copyWith(
          remainingSeconds: newRemaining,
          totalSeconds: newTotal,
          isFinished: false,
          isRunning: true,
          targetEndTime: now.add(Duration(seconds: newRemaining)),
        );
      }
      return timer;
    }).toList();
    _persistTimers();
    _syncTicker();
  }

  void updateTimer(String id, String name, int totalSeconds, int colorIndex) {
    final now = DateTime.now();
    state = state.map((timer) {
      if (timer.id == id) {
        final newName = name.trim().isEmpty ? timer.name : name.trim();
        return timer.copyWith(
          name: newName,
          totalSeconds: totalSeconds,
          remainingSeconds: totalSeconds,
          colorIndex: colorIndex,
          isFinished: false,
          isRunning: true,
          targetEndTime: now.add(Duration(seconds: totalSeconds)),
        );
      }
      return timer;
    }).toList();
    _persistTimers();
    _syncTicker();
  }

  void deleteTimer(String id) {
    state = state.where((timer) => timer.id != id).toList();
    _persistTimers();
    _syncTicker();
  }

  void clearFinished() {
    state = state.where((timer) => !timer.isFinished).toList();
    _persistTimers();
    _syncTicker();
  }
}

final kitchenTimersProvider =
    NotifierProvider<KitchenTimersNotifier, List<KitchenTimerModel>>(KitchenTimersNotifier.new);
