import 'dart:async';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';
import '../utils/notification_service.dart';
import '../utils/audio_alarm_service.dart';

class KitchenTimerModel {
  final String id;
  final String name;
  final int totalSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final bool isFinished;
  final int colorIndex;
  final DateTime? finishedAt;

  KitchenTimerModel({
    required this.id,
    required this.name,
    required this.totalSeconds,
    required this.remainingSeconds,
    this.isRunning = true,
    this.isFinished = false,
    this.colorIndex = 0,
    this.finishedAt,
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

  KitchenTimerModel copyWith({
    String? id,
    String? name,
    int? totalSeconds,
    int? remainingSeconds,
    bool? isRunning,
    bool? isFinished,
    int? colorIndex,
    DateTime? finishedAt,
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
    );
  }
}

class KitchenTimersNotifier extends Notifier<List<KitchenTimerModel>> {
  Timer? _ticker;

  @override
  @override
  List<KitchenTimerModel> build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _ticker = null;
    });

    return [];
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
    bool stateChanged = false;
    final updatedList = state.map((timer) {
      if (timer.isRunning && timer.remainingSeconds > 0) {
        stateChanged = true;
        final newRemaining = timer.remainingSeconds - 1;
        if (newRemaining <= 0) {
          final now = DateTime.now();
          final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          AudioAlarmService().playAlarm();
          final l10n = lookupAppLocalizations(PlatformDispatcher.instance.locale);
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
          );
        }
        return timer.copyWith(remainingSeconds: newRemaining);
      }
      return timer;
    }).toList();

    if (stateChanged) {
      state = updatedList;
    }
    _syncTicker();
  }

  void addTimer(String name, int seconds, {int colorIndex = 0}) {
    if (seconds <= 0) return;
    const uuid = Uuid();
    final newTimer = KitchenTimerModel(
      id: uuid.v4(),
      name: name.trim().isEmpty ? 'Timer' : name.trim(),
      totalSeconds: seconds,
      remainingSeconds: seconds,
      isRunning: true,
      isFinished: false,
      colorIndex: colorIndex,
    );

    state = [...state, newTimer];
    _syncTicker();
  }

  void toggleTimer(String id) {
    state = state.map((timer) {
      if (timer.id == id && !timer.isFinished) {
        return timer.copyWith(isRunning: !timer.isRunning);
      }
      return timer;
    }).toList();
    _syncTicker();
  }

  void resetTimer(String id) {
    state = state.map((timer) {
      if (timer.id == id) {
        return timer.copyWith(
          remainingSeconds: timer.totalSeconds,
          isRunning: true,
          isFinished: false,
        );
      }
      return timer;
    }).toList();
    _syncTicker();
  }

  void addMinutes(String id, int minutes) {
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
        );
      }
      return timer;
    }).toList();
    _syncTicker();
  }

  void updateTimer(String id, String name, int totalSeconds, int colorIndex) {
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
        );
      }
      return timer;
    }).toList();
    _syncTicker();
  }

  void deleteTimer(String id) {
    state = state.where((timer) => timer.id != id).toList();
    _syncTicker();
  }

  void clearFinished() {
    state = state.where((timer) => !timer.isFinished).toList();
    _syncTicker();
  }
}

final kitchenTimersProvider =
    NotifierProvider<KitchenTimersNotifier, List<KitchenTimerModel>>(KitchenTimersNotifier.new);
