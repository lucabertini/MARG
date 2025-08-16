// lib/services/audio_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

// --- MODIFIED --- Import the specific models needed.
import '../models/tour_stop.dart';
import '../models/app_language.dart';

/// Manages all audio-related functionalities, including asset loading,
/// player creation, playback control, and state management.
class AudioService {
  // ... (rest of the file is unchanged)
  final Map<String, AudioPlayer> _audioPlayers = {};
  List<String> _availableSpeechAssets = [];
  List<String> _availableAmbientAssets = [];

  // This service now tracks which pins have failed to load.
  final Set<String> _failedPins = {};

  // This controller will broadcast the set of currently playing stop IDs.
  // The UI will listen to this stream to update itself reactively.
  final _playingIdsController = StreamController<Set<String>>.broadcast();
  final Set<String> _currentlyPlayingIds = {};

  /// A stream that emits the set of stop names whose audio is currently playing.
  Stream<Set<String>> get currentlyPlayingIdsStream => _playingIdsController.stream;

  /// Public getters for the lists of available audio assets.
  List<String> get availableSpeechAssets => _availableSpeechAssets;
  List<String> get availableAmbientAssets => _availableAmbientAssets;
  
  Set<String> get failedPins => _failedPins;

  /// Scans the asset manifest to find all available audio files for the given language.
  Future<void> loadAvailableAssets(AppLanguage language) async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      // Load speech assets for the selected language
      final speechPrefix = 'assets/audio/${language.name}/';
      _availableSpeechAssets = manifestMap.keys
          .where((key) => key.startsWith(speechPrefix) && (key.endsWith('.mp3') || key.endsWith('.wav')))
          .map((fullPath) => fullPath.substring(speechPrefix.length))
          .toList();

      // Load ambient assets
      const ambientPrefix = 'assets/sounds/';
      _availableAmbientAssets = manifestMap.keys
          .where((key) => key.startsWith(ambientPrefix) && (key.endsWith('.mp3') || key.endsWith('.wav')))
          .map((fullPath) => fullPath.substring(ambientPrefix.length))
          .toList();

    } catch (e) {
      debugPrint("[AudioService] Error loading available assets: $e");
      _availableSpeechAssets = [];
      _availableAmbientAssets = [];
    }
  }

  /// Creates and configures audio players for all provided tour stops.
  ///
  /// Returns a set of stop names for which audio setup failed.
  Future<Set<String>> setupPlayersForStops(List<TourStop> stops, AppLanguage language) async {
    // First, clear out any old players and state.
    _disposeAllPlayers();
    _failedPins.clear(); // Clear failed pins on a full setup.

    for (final stop in stops) {
      final success = await _setupSinglePlayer(stop, language);
      if (!success) {
        _failedPins.add(stop.name); // Track failure internally.
      }
    }
    // Still return the set for any immediate UI feedback (like a SnackBar).
    return _failedPins;
  }

  /// Creates or updates the audio player for a single tour stop.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> updatePlayerForStop(TourStop stop, AppLanguage language) async {
    final success = await _setupSinglePlayer(stop, language);
    // Update the internal state of failed pins.
    if (success) {
      _failedPins.remove(stop.name);
    } else {
      _failedPins.add(stop.name);
    }
    return success;
  }

  /// Internal helper to set up a single audio player.
  Future<bool> _setupSinglePlayer(TourStop stop, AppLanguage language) async {
    // Dispose of any existing player for this stop before creating a new one.
    await _audioPlayers[stop.name]?.dispose();

    try {
      final player = AudioPlayer();
      final String fullAssetPath = _getAssetPath(stop, language);

      debugPrint("[AudioService] Setting up player for '${stop.name}' with asset: $fullAssetPath");
      await player.setAsset(fullAssetPath);

      player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (_currentlyPlayingIds.contains(stop.name)) {
            _currentlyPlayingIds.remove(stop.name);
            _playingIdsController.add(Set.unmodifiable(_currentlyPlayingIds));
          }
        }
      });

      _audioPlayers[stop.name] = player;
      return true;
    } catch (e) {
      debugPrint("[AudioService] !!! ASSET ERROR for ${stop.name} (${stop.audioAsset}): $e");
      return false;
    }
  }

  /// Plays the audio for a given stop name.
  void play(String stopName) {
    final player = _audioPlayers[stopName];
    if (player == null || player.playing) return;

    _currentlyPlayingIds.add(stopName);
    _playingIdsController.add(Set.unmodifiable(_currentlyPlayingIds));

    player.seek(Duration.zero);
    player.setLoopMode(LoopMode.off);
    player.play();
  }

  /// Stops the audio for a given stop name.
  void stop(String stopName) {
    final player = _audioPlayers[stopName];
    if (player == null || !player.playing) return;

    _currentlyPlayingIds.remove(stopName);
    _playingIdsController.add(Set.unmodifiable(_currentlyPlayingIds));
    player.stop();
  }

  /// Disposes of the player associated with a specific stop.
  void removePlayer(String stopName) {
    _audioPlayers[stopName]?.dispose();
    _audioPlayers.remove(stopName);
    _failedPins.remove(stopName); // Clean up failed pin state.
    if (_currentlyPlayingIds.contains(stopName)) {
      _currentlyPlayingIds.remove(stopName);
      _playingIdsController.add(Set.unmodifiable(_currentlyPlayingIds));
    }
  }

  /// Releases all audio player resources and closes the stream controller.
  void dispose() {
    _disposeAllPlayers();
    _playingIdsController.close();
  }

  void _disposeAllPlayers() {
    for (final player in _audioPlayers.values) {
      player.dispose();
    }
    _audioPlayers.clear();
    if (_currentlyPlayingIds.isNotEmpty) {
      _currentlyPlayingIds.clear();
      _playingIdsController.add(Set.unmodifiable(_currentlyPlayingIds));
    }
  }

  String _getAssetPath(TourStop stop, AppLanguage language) {
    if (stop.behavior == AudioBehavior.speech) {
      return 'assets/audio/${language.name}/${stop.audioAsset}';
    } else { // Ambient
      return 'assets/sounds/${stop.audioAsset}';
    }
  }
}