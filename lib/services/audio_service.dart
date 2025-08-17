////////////////////////////////// START OF CODE FOR 
///// lib/services/audio_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:collection/collection.dart'; // <-- STEP 1: IMPORT THE COLLECTION PACKAGE
import '../models/tour_stop.dart';
import '../models/app_language.dart';
import 'tour_state_service.dart'; 

/// Manages all audio-related functionalities, including asset loading,
/// player creation, playback control, and state management.
class AudioService {
  final TourStateService _tourStateService;

  final Map<String, AudioPlayer> _audioPlayers = {};
  Map<TourStopLabel, List<String>> _availableAssetsByLabel = {};

  final Set<String> _failedPins = {};
  final _playingIdsController = StreamController<Set<String>>.broadcast();
  final Set<String> _currentlyPlayingIds = {};
  
  AudioService({required TourStateService tourStateService})
    : _tourStateService = tourStateService;

  Stream<Set<String>> get currentlyPlayingIdsStream => _playingIdsController.stream;
  Map<TourStopLabel, List<String>> get availableAssetsByLabel => _availableAssetsByLabel;
  Set<String> get failedPins => _failedPins;

  /// Scans the asset manifest to find all available audio files, organized by label.
  Future<void> loadAvailableAssets(AppLanguage language) async {
  _availableAssetsByLabel = {}; // Clear previous assets
  try {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    final allKeys = manifestMap.keys;

    for (final label in TourStopLabel.values) {
      String prefix;
      if (label == TourStopLabel.music) {
        prefix = 'assets/sounds/';
      } else {
        // --- FIX #1: Update the prefix here ---
        prefix = 'assets/audio/lang_${language.name}/${label.name}/';
      }

      final assetsForLabel = allKeys
          .where((key) => key.startsWith(prefix) && (key.endsWith('.mp3') || key.endsWith('.wav')))
          .map((fullPath) => fullPath.substring(prefix.length))
          .toList();
      
      _availableAssetsByLabel[label] = assetsForLabel;
    }
  } catch (e) {
    debugPrint("[AudioService] Error loading available assets: $e");
    _availableAssetsByLabel = {};
  }
}


  /// Creates and configures audio players for all provided tour stops.
  Future<Set<String>> setupPlayersForStops(List<TourStop> stops, AppLanguage language) async {
    _disposeAllPlayers();
    _failedPins.clear();

    for (final stop in stops) {
      final success = await _setupSinglePlayer(stop, language);
      if (!success) {
        _failedPins.add(stop.name);
      }
    }
    return _failedPins;
  }

  /// Creates or updates the audio player for a single tour stop.
  Future<bool> updatePlayerForStop(TourStop stop, AppLanguage language) async {
    final success = await _setupSinglePlayer(stop, language);
    if (success) {
      _failedPins.remove(stop.name);
    } else {
      _failedPins.add(stop.name);
    }
    return success;
  }
  
  /// Internal helper to set up a single audio player.
  Future<bool> _setupSinglePlayer(TourStop stop, AppLanguage language) async {
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
  
  String _getAssetPath(TourStop stop, AppLanguage language) {
  if (stop.label == TourStopLabel.music) {
    return 'assets/sounds/${stop.audioAsset}';
  } else {
    // --- FIX #2: Update the path construction here ---
    return 'assets/audio/lang_${language.name}/${stop.label.name}/${stop.audioAsset}';
  }
}

  void play(String stopName) {
    final player = _audioPlayers[stopName];
    if (player == null || player.playing) return;

    final tourStops = _tourStateService.tourStops;
    
    // --- THIS IS THE FIX ---
    // STEP 2: Declare `stop` as nullable (TourStop?)
    // STEP 3: Use `firstWhereOrNull` which correctly returns TourStop?
    final TourStop? stop = tourStops.firstWhereOrNull((s) => s.name == stopName);

    if (stop == null) {
      debugPrint("[AudioService] Could not play '$stopName' because it was not found in TourStateService.");
      return;
    }

    _currentlyPlayingIds.add(stopName);
    _playingIdsController.add(Set.unmodifiable(_currentlyPlayingIds));
    
    player.seek(Duration.zero);
    if (stop.behavior == AudioBehavior.ambient) {
        player.setLoopMode(LoopMode.one);
    } else {
        player.setLoopMode(LoopMode.off);
    }
    player.play();
  }

  void stop(String stopName) {
    final player = _audioPlayers[stopName];
    if (player == null || !player.playing) return;

    _currentlyPlayingIds.remove(stopName);
    _playingIdsController.add(Set.unmodifiable(_currentlyPlayingIds));
    player.stop();
  }

  void removePlayer(String stopName) {
    _audioPlayers[stopName]?.dispose();
    _audioPlayers.remove(stopName);
    _failedPins.remove(stopName);
    if (_currentlyPlayingIds.contains(stopName)) {
      _currentlyPlayingIds.remove(stopName);
      _playingIdsController.add(Set.unmodifiable(_currentlyPlayingIds));
    }
  }

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
}