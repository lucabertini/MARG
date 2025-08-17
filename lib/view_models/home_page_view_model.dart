//////////////////////////////////  START OF CODE FOR 
// lib/view_models/home_page_view_model.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Import services and models, NOT material.dart
import '../services/tour_data_service.dart';
import '../services/audio_service.dart';
import '../services/tour_playback_service.dart';
import '../services/tour_proximity_service.dart';
import '../services/tour_state_service.dart';
import '../models/app_language.dart';
import '../models/tour_stop.dart';

class HomePageViewModel extends ChangeNotifier {
  // --- DEPENDENCIES (Services) ---
  final TourDataService _tourDataService;
  final AudioService _audioService;
  final TourPlaybackService _tourPlaybackService;
  final TourProximityService _tourProximityService;
  final TourStateService _tourStateService;

  // --- PRIVATE STATE ---
  StreamSubscription<Set<String>>? _playingIdsSubscription;
  bool _disposed = false;

  // --- PUBLIC UI STATE ---
  bool isLoading = true;
  String statusMessage = 'Initializing...';
  late AppLanguage selectedLanguage;
  late bool isEditModeEnabled;
  Set<String> currentlyPlayingIds = {};

  // --- GETTERS for data from services ---
  List<TourStop> get tourStops => _tourStateService.tourStops;
  Set<String> get failedAudioPins => _audioService.failedPins;
  Map<TourStopLabel, List<String>> get availableAssetsByLabel => _audioService.availableAssetsByLabel;


  HomePageViewModel({
    required TourDataService tourDataService,
    required AudioService audioService,
    required TourPlaybackService tourPlaybackService,
    required TourProximityService tourProximityService,
    required TourStateService tourStateService,
    required AppLanguage initialLanguage,
    required bool isEditMode,
  })  : _tourDataService = tourDataService,
        _audioService = audioService,
        _tourPlaybackService = tourPlaybackService,
        _tourProximityService = tourProximityService,
        _tourStateService = tourStateService {
    selectedLanguage = initialLanguage;
    isEditModeEnabled = isEditMode;

    // Listen to streams from services and update own state
    _playingIdsSubscription =
        _audioService.currentlyPlayingIdsStream.listen((playingIds) {
      currentlyPlayingIds = playingIds;
      notifyListeners();
    });

    // Listen to data changes from the state service
    _tourStateService.tourStopsNotifier.addListener(_onTourStopsChanged);
    
    // Start loading data immediately when the ViewModel is created.
    initialize();
  }

  void _onTourStopsChanged() {
    notifyListeners();
  }

  // --- INITIALIZATION LOGIC ---
  Future<void> initialize() async {
    // Prevent re-initialization if called accidentally
    if (!isLoading) return; 

    _updateStatus('Initializing...', notify: false);
    
    await _audioService.loadAvailableAssets(selectedLanguage);
    await loadTourData();

    final bool trackingStarted = await _tourPlaybackService.start();
    if (!trackingStarted) {
      _updateStatus('Location permissions are denied.');
    } else {
      _updateStatus('Tour loaded successfully.');
    }

    // NOTE: We no longer call `setPlaybackActive` here.
    // It will be called from the new `activatePlayback` method.
    isLoading = false;
    notifyListeners();
  }
  
  // --- THIS IS THE FIX ---
  /// Called from the HomePage to enable location-based audio triggers.
  void activatePlayback() {
    // Only activate playback if the user is NOT in edit mode.
    // This ensures the correct state when navigating directly to the home page.
    _tourPlaybackService.setPlaybackActive(!isEditModeEnabled);
  }


  // --- UI ACTION METHODS ---

  void toggleEditMode(bool isEnabled) {
    isEditModeEnabled = isEnabled;
    _tourPlaybackService.setPlaybackActive(!isEditModeEnabled);

    if (!isEditModeEnabled) {
      _tourProximityService.reset();
      // Stop all playing audio when exiting edit mode
      for (var stop in tourStops) {
        _audioService.stop(stop.name);
      }
    }
    notifyListeners();
  }

  Future<void> changeLanguage(AppLanguage newLanguage) async {
    if (newLanguage == selectedLanguage) return;

    selectedLanguage = newLanguage;
    _updateStatus("Switching language to '${newLanguage.name}'...");

    _tourProximityService.reset();
    await _audioService.loadAvailableAssets(selectedLanguage);
    await setupAllAudioPlayers();

    _updateStatus("Loaded tour in ${newLanguage.name.toUpperCase()}.");
  }

  Future<void> setupAllAudioPlayers() async {
    await _audioService.setupPlayersForStops(tourStops, selectedLanguage);
    notifyListeners(); // Notify to update UI with any new failed pins
  }

  Future<void> saveTourData() async {
    if (!isEditModeEnabled) return;
    await _tourStateService.saveTourData();
  }
  
  Future<void> loadTourData({bool forceReload = false}) async {
    try {
      await _tourStateService.loadTourData(
        isEditMode: isEditModeEnabled,
        forceReload: forceReload,
      );
      await setupAllAudioPlayers();
    } catch (e) {
      _updateStatus("Error: Could not process tour data.");
      debugPrint("[VM-LOAD] Error loading tour stops: $e");
    }
  }

  Future<void> resetTourData() async {
    _tourProximityService.reset();
    _updateStatus('Reloading original tour...');
    await _tourStateService.resetTourData(isEditMode: isEditModeEnabled);
    await setupAllAudioPlayers();
  }

  /// Handles the result from the PinEditorPage.
  /// The navigation itself is a UI concern and remains in the View.
  Future<void> handlePinEditorResult(dynamic result, String originalName) async {
    if (result == null) return;
    
    if (result == 'DELETE') {
      _audioService.removePlayer(originalName);
      _tourStateService.deleteStop(originalName);
      await saveTourData();
      return;
    }

    if (result is TourStop) {
      final updatedStop = result;
      final isCreatingNewPin = tourStops.every((s) => s.name != originalName);

      if (!isCreatingNewPin && originalName != updatedStop.name) {
        _audioService.removePlayer(originalName);
      }

      await _audioService.updatePlayerForStop(updatedStop, selectedLanguage);
      _tourStateService.addOrUpdateStop(updatedStop, originalName: isCreatingNewPin ? null : originalName);
      
      await saveTourData();
    }
  }

  Future<void> updatePinPosition(String stopName, LatLng newPosition) async {
    _tourStateService.updateStopPosition(stopName, newPosition.latitude, newPosition.longitude);
    await _tourStateService.saveTourData(showSnackbar: false);
  }

  String getJsonExportString() {
    return _tourDataService.getJsonExportString(tourStops);
  }

  // --- HELPERS ---
  void _updateStatus(String message, {bool notify = true}) {
    statusMessage = message;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _playingIdsSubscription?.cancel();
    _tourStateService.tourStopsNotifier.removeListener(_onTourStopsChanged);
    // Note: The services themselves are disposed by _HomePageState, which owns them.
    super.dispose();
  }
}