////////////////////////////////// START OF CODE FOR 
/////lib/services/tour_data_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// --- MODIFIED --- Import the specific model needed.
import '../models/tour_stop.dart';

// The URL constant now lives here, with the service that uses it.
const String TOUR_URL = "https://gist.githubusercontent.com/lucabertini/579180d07f04601b61b9368d93dcb450/raw/";

class TourDataService {
  // ... (rest of the file is unchanged)
  // This private helper method for getting the local path is now part of the service.
  Future<String> _getLocalDataPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/tour_data.json';
  }

  // The parsing logic is now a private method within the service.
  List<TourStop> _parseTourStopsFromJsonString(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((jsonItem) => TourStop.fromJson(jsonItem)).toList();
  }

  /// Loads tour data.
  ///
  /// If [isEditMode] is true and [forceReload] is false, it first tries to
  /// load from the local device file. If that fails or doesn't exist, it falls
  /// back to fetching from the network Gist.
  Future<List<TourStop>> loadTourStops({
    required bool isEditMode,
    bool forceReload = false,
  }) async {
    // Try loading local data first if in edit mode and not forcing a reload.
    if (isEditMode && !forceReload) {
      try {
        final path = await _getLocalDataPath();
        final file = File(path);
        if (await file.exists()) {
          final String localData = await file.readAsString();
          debugPrint("[SERVICE] Loaded tour from local file.");
          return _parseTourStopsFromJsonString(localData);
        }
      } catch (e) {
        debugPrint("[SERVICE] FAILED to load local file, will fetch from Gist. Error: $e");
      }
    }

    // Fallback to network fetch.
    final tourUrl = "$TOUR_URL?v=${DateTime.now().millisecondsSinceEpoch}";
    try {
      final response = await http.get(Uri.parse(tourUrl));
      if (response.statusCode == 200) {
        debugPrint("[SERVICE] Loaded tour from Gist.");
        final tourStops = _parseTourStopsFromJsonString(response.body);
        // If in edit mode, we save the freshly fetched data locally.
        if (isEditMode) {
          await saveTourData(tourStops, showLogs: false);
        }
        return tourStops;
      } else {
        throw Exception("Failed to load tour. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("[SERVICE] Error: Could not process tour data from Gist. Error: $e");
      // Return an empty list or rethrow the exception to be handled by the UI.
      rethrow;
    }
  }

  /// Saves the provided list of [tourStops] to the local device file.
  Future<void> saveTourData(List<TourStop> tourStops, {bool showLogs = true}) async {
    try {
      final path = await _getLocalDataPath();
      final file = File(path);
      final List<Map<String, dynamic>> tourStopsAsJson = tourStops.map((stop) => stop.toJson()).toList();
      final String jsonString = jsonEncode(tourStopsAsJson);
      await file.writeAsString(jsonString);
      if (showLogs) {
        debugPrint("[SERVICE] Tour data saved successfully.");
      }
    } catch (e) {
      debugPrint("[SERVICE] FAILED to save tour data: $e");
    }
  }

  /// Deletes the local tour data file, effectively resetting to the default.
  Future<void> resetTourData() async {
    try {
      final path = await _getLocalDataPath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint("[SERVICE] Local tour data file deleted.");
      }
    } catch (e) {
      debugPrint("[SERVICE] Could not clear local data file. Error: $e");
    }
  }

  /// Converts a list of tour stops into a formatted JSON string for export.
  String getJsonExportString(List<TourStop> tourStops) {
    final List<Map<String, dynamic>> tourStopsAsJson = tourStops.map((stop) => stop.toJson()).toList();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(tourStopsAsJson);
  }
}
//////////////////////////////////  END OF FILE