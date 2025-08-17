// START OF CODE FOR lib/services/tour_state_service.dart

import 'package:flutter/foundation.dart';
// --- MODIFIED --- Import the specific model needed.
import '../models/tour_stop.dart';
import 'tour_data_service.dart';

/// Manages the application's core state: the list of tour stops.
///
/// This service acts as the single source of truth for the tour data.
/// It is responsible for loading, saving, resetting, and modifying the
/// tour stops. UI components can listen to the [tourStopsNotifier]
/// to reactively rebuild when the data changes.
class TourStateService {
  // ... (rest of the file is unchanged)
  final TourDataService _tourDataService;

  TourStateService({required TourDataService tourDataService})
      : _tourDataService = tourDataService;

  // --- STATE ---
  // A ValueNotifier is a simple and efficient way to manage state and notify listeners.
  final ValueNotifier<List<TourStop>> _tourStopsNotifier = ValueNotifier([]);

  // --- PUBLIC GETTERS ---
  ValueListenable<List<TourStop>> get tourStopsNotifier => _tourStopsNotifier;
  List<TourStop> get tourStops => _tourStopsNotifier.value;

  // --- DATA MANAGEMENT METHODS ---

  /// Loads the tour data, either from a local file or the network.
  /// Notifies listeners upon completion.
  Future<void> loadTourData({
    required bool isEditMode,
    bool forceReload = false,
  }) async {
    try {
      final loadedStops = await _tourDataService.loadTourStops(
        isEditMode: isEditMode,
        forceReload: forceReload,
      );
      _tourStopsNotifier.value = loadedStops;
    } catch (e) {
      debugPrint("[TourStateService] Error loading tour data: $e");
      // Optionally, you could introduce an error state here.
      // For now, we rethrow to let the caller handle it.
      rethrow;
    }
  }

  /// Saves the current list of tour stops to a local file.
  Future<void> saveTourData({bool showSnackbar = true}) async {
    await _tourDataService.saveTourData(
      _tourStopsNotifier.value,
      showLogs: !showSnackbar, // A bit of a hack to map parameters
    );
  }

  /// Resets the tour to its original state from the network.
  Future<void> resetTourData({required bool isEditMode}) async {
    await _tourDataService.resetTourData();
    // After resetting, we must reload the data.
    await loadTourData(isEditMode: isEditMode, forceReload: true);
  }

  /// Adds a new stop or updates an existing one.
  void addOrUpdateStop(TourStop stop, {String? originalName}) {
    final List<TourStop> currentStops = List.from(_tourStopsNotifier.value);
    
    // If originalName is provided, it means we are updating an existing stop
    // that might have had its name changed.
    final index = originalName != null 
        ? currentStops.indexWhere((s) => s.name == originalName) 
        : currentStops.indexWhere((s) => s.name == stop.name);

    if (index != -1) {
      // Update existing stop
      currentStops[index] = stop;
    } else {
      // Add new stop
      currentStops.add(stop);
    }
    _tourStopsNotifier.value = currentStops;
  }

  /// Deletes a stop by its name.
  void deleteStop(String stopName) {
    final List<TourStop> currentStops = List.from(_tourStopsNotifier.value);
    currentStops.removeWhere((s) => s.name == stopName);
    _tourStopsNotifier.value = currentStops;
  }

  /// Updates the geographical position of a specific stop.
  void updateStopPosition(String stopName, double newLat, double newLng) {
    final List<TourStop> currentStops = List.from(_tourStopsNotifier.value);
    final index = currentStops.indexWhere((s) => s.name == stopName);
    if (index != -1) {
      final updatedStop = currentStops[index].copyWith(
        latitude: newLat,
        longitude: newLng,
      );
      currentStops[index] = updatedStop;
      _tourStopsNotifier.value = currentStops;
    }
  }

  void dispose() {
    _tourStopsNotifier.dispose();
  }
}
// END OF FILE