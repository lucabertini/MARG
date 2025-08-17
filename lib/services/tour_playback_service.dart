////////////////////////////////// START OF CODE FOR 
// lib/services/tour_playback_service.dart

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'location_service.dart';
import 'audio_service.dart';
import 'tour_proximity_service.dart';
import 'tour_state_service.dart';

/// Orchestrates the active tour playback session.
///
/// This service acts as the "brain" that connects location updates to audio
/// playback logic. It listens for the user's position and coordinates with
/// other services to determine which audio clips should be played or stopped.
class TourPlaybackService {
  final LocationService _locationService;
  final AudioService _audioService;
  final TourProximityService _tourProximityService;
  final TourStateService _tourStateService;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<Set<String>>? _playingIdsSubscription;

  // --- THIS IS THE FIX ---
  // Start in an inactive state. Playback will only be triggered after
  // the UI explicitly calls `setPlaybackActive(true)`.
  bool _isPlaybackActive = false;
  Set<String> _currentlyPlayingIds = {};

  TourPlaybackService({
    required LocationService locationService,
    required AudioService audioService,
    required TourProximityService tourProximityService,
    required TourStateService tourStateService,
  })  : _locationService = locationService,
        _audioService = audioService,
        _tourProximityService = tourProximityService,
        _tourStateService = tourStateService;

  /// Initializes the service, checks for permissions, and starts listening to location updates.
  ///
  /// Returns `true` if permissions are granted and tracking starts, `false` otherwise.
  Future<bool> start() async {
    // Keep track of the currently playing IDs from the AudioService.
    _playingIdsSubscription =
        _audioService.currentlyPlayingIdsStream.listen((playingIds) {
      _currentlyPlayingIds = playingIds;
    });

    final hasPermission = await _locationService.handlePermission();
    if (hasPermission) {
      _listenToLocation();
      return true;
    } else {
      return false;
    }
  }

  /// Toggles whether the service should process location updates for audio playback.
  ///
  /// This is typically called when entering/exiting an 'edit mode' in the UI,
  /// and now also when the HomePage is first displayed.
  void setPlaybackActive(bool isActive) {
    _isPlaybackActive = isActive;
    debugPrint("[TourPlaybackService] Playback active state set to: $_isPlaybackActive");
  }

  /// Subscribes to the location stream and processes updates.
  void _listenToLocation() {
    _positionSubscription = _locationService.getPositionStream().listen(
      (Position position) {
        // Only process if playback is active (i.e., not in edit mode and HomePage is visible)
        if (!_isPlaybackActive) return;

        // Get the current state from the respective services.
        final tourStops = _tourStateService.tourStops;
        final failedPins = _audioService.failedPins;

        if (tourStops.isEmpty) return;

        // 1. Delegate the complex proximity logic to the TourProximityService.
        final commands = _tourProximityService.processPositionUpdate(
          position: position,
          stops: tourStops,
          currentlyPlayingIds: _currentlyPlayingIds,
          failedAudioPins: failedPins,
        );

        // 2. Execute the returned commands on the AudioService.
        for (final command in commands) {
          if (command is PlayAudioCommand) {
            _audioService.play(command.stopName);
          } else if (command is StopAudioCommand) {
            _audioService.stop(command.stopName);
          }
        }
      },
      onError: (error) {
        debugPrint("[TourPlaybackService] Location Stream Error: $error");
        // In a real app, we might want to surface this error to the UI
        // via another stream or state notifier.
      },
    );
  }

  /// Cleans up resources, primarily the location stream subscription.
  void dispose() {
    _positionSubscription?.cancel();
    _playingIdsSubscription?.cancel();
  }
}