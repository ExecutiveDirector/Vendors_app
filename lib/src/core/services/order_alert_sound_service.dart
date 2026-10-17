// lib/src/core/services/order_alert_sound_service.dart
//
// Loops assets/sounds/order_alert.wav at full volume while the new-order sheet
// is open, like an incoming call, so a vendor in a busy shop can't miss an order.
// (Same alert the rider app plays on a job offer.) When the app is asleep or
// closed, the notification channel's insistent alarm sound covers it instead
// (see push_notification_service.dart).
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class OrderAlertSoundService {
  OrderAlertSoundService._();
  static final OrderAlertSoundService instance = OrderAlertSoundService._();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  /// Starts the loop. Safe to call repeatedly; never layers audio.
  Future<void> play() async {
    if (_isPlaying) return;
    _isPlaying = true;
    try {
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
      ));
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/order_alert.wav'));
    } catch (e) {
      debugPrint('[OrderAlertSound] Failed to play: $e');
      _isPlaying = false;
    }
  }

  /// Stops the loop. Call on accept, decline, snooze and sheet disposal.
  Future<void> stop() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[OrderAlertSound] Failed to stop: $e');
    }
  }
}
