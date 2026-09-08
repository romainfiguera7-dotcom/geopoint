import 'dart:async';

import 'package:flutter/services.dart';

import '../../passport/settings/passport_display_preferences.dart';
import '../../passport/settings/passport_display_preferences_storage.dart';

abstract final class GameplayFeedback {
  static bool _soundEffectsEnabled = true;
  static bool _hapticsEnabled = true;

  static Future<void> initialize() async {
    try {
      apply(await PassportDisplayPreferencesStorage.load());
    } on Object catch (_) {
      // Les valeurs par défaut permettent toujours de démarrer l’application.
    }
  }

  static void apply(PassportDisplayPreferences preferences) {
    _soundEffectsEnabled = preferences.soundEffectsEnabled;
    _hapticsEnabled = preferences.hapticsEnabled;
  }

  static void answer({required bool isCorrect}) {
    final List<Future<void>> operations = <Future<void>>[];

    if (_soundEffectsEnabled) {
      operations.add(
        SystemSound.play(
          isCorrect ? SystemSoundType.click : SystemSoundType.alert,
        ),
      );
    }

    if (_hapticsEnabled) {
      operations.add(
        isCorrect
            ? HapticFeedback.lightImpact()
            : HapticFeedback.mediumImpact(),
      );
    }

    for (final Future<void> operation in operations) {
      _ignoreFailure(operation);
    }
  }

  static void previewSound() {
    if (_soundEffectsEnabled) {
      _ignoreFailure(SystemSound.play(SystemSoundType.click));
    }
  }

  static void previewHaptic() {
    if (_hapticsEnabled) {
      _ignoreFailure(HapticFeedback.selectionClick());
    }
  }

  static void _ignoreFailure(Future<void> operation) {
    unawaited(operation.catchError((Object _) {}));
  }
}
