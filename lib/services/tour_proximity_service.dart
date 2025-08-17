// START OF CODE FOR lib/services/tour_proximity_service.dart

import 'package:geolocator/geolocator.dart';
// --- MODIFIED --- Import the specific model needed.
import '../models/tour_stop.dart';

// --- Command Pattern: Decouples the logic service from the audio service ---
// The proximity service will return a list of these commands, and the UI layer will execute them.

/// Abstract base class for commands related to audio playback.
abstract class AudioCommand {
  final String stopName;
  AudioCommand(this.stopName);
}

/// A command instructing the audio service to play a specific track.
class PlayAudioCommand extends AudioCommand {
  PlayAudioCommand(super.stopName);
}

/// A command instructing the audio service to stop a specific track.
class StopAudioCommand extends AudioCommand {
  StopAudioCommand(super.stopName);
}


/// Manages the core business logic of the audio tour.
///
/// This service determines when audio should be played or stopped based on the
/// user's proximity to tour stops, playback history, and audio behavior rules.
/// It is completely decoupled from the audio and UI layers, returning abstract
/// commands to be executed by a controller.
class TourProximityService {
  // ... (rest of the file is unchanged)
  // --- STATE: This service now owns the state related to playback logic. ---
  final Set<String> _playedSpeechIds = {};
  final Set<String> _triggeredAmbientIds = {};

  /// Processes the user's current position and returns a list of audio commands.
  ///
  /// Takes the user's [position], the list of all [stops], the set of
  /// [currentlyPlayingIds] to avoid issuing redundant commands, and the
  /// set of [failedAudioPins] to ignore them.
  List<AudioCommand> processPositionUpdate({
    required Position position,
    required List<TourStop> stops,
    required Set<String> currentlyPlayingIds,
    required Set<String> failedAudioPins,
  }) {
    final commands = <AudioCommand>[];

    for (final stop in stops) {
      if (failedAudioPins.contains(stop.name)) continue;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        stop.latitude,
        stop.longitude,
      );
      final isPlaying = currentlyPlayingIds.contains(stop.name);
      final isInRange = distance <= stop.triggerRadius;

      if (stop.behavior == AudioBehavior.speech) {
        final hasAlreadyPlayed = _playedSpeechIds.contains(stop.name);
        if (isInRange && !isPlaying && !hasAlreadyPlayed) {
          commands.add(PlayAudioCommand(stop.name));
          _playedSpeechIds.add(stop.name);
        }
      } else { // Ambient Logic
        final hasBeenTriggered = _triggeredAmbientIds.contains(stop.name);
        if (isInRange) {
          if (!isPlaying && !hasBeenTriggered) {
            commands.add(PlayAudioCommand(stop.name));
            _triggeredAmbientIds.add(stop.name);
          }
        } else {
          if (hasBeenTriggered) {
            _triggeredAmbientIds.remove(stop.name);
          }
          if (isPlaying) {
            commands.add(StopAudioCommand(stop.name));
          }
        }
      }
    }

    return commands;
  }
  
  /// Resets the playback history state.
  ///
  /// This should be called when the tour is reset or when exiting edit mode.
  void reset() {
    _playedSpeechIds.clear();
    _triggeredAmbientIds.clear();
  }
}
// END OF FILE