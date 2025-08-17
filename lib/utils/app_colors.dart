////////////////////////////////// START OF CODE FOR lib/utils/app_colors.dart


import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/tour_stop.dart';

/// A utility class for managing the visual appearance of map pins.
///
/// By centralizing all color and icon logic here, we can easily change the
/// theme of the map markers across the entire app from one single file.
class PinColor {
  // --- HUE DEFINITIONS ---
  // These are the base colors for our pin types.
  // Using BitmapDescriptor constants for clarity where possible.
  static const double speech = BitmapDescriptor.hueAzure;   // A nice light blue
  static const double ambient = BitmapDescriptor.hueYellow; 

  // --- STATE-BASED HUE DEFINITIONS ---
  // These hues represent the pin's current state and override the base color.
  static const double playing = BitmapDescriptor.hueGreen;
  static const double failed = BitmapDescriptor.hueRed;
  static const double editMode = BitmapDescriptor.hueViolet;

  // --- CIRCLE COLOR DEFINITIONS ---
  // We define corresponding `Color` objects for the circles for consistency.
  static const Color speechCircle = Colors.lightBlueAccent;
  static const Color ambientCircle = Colors.amberAccent; 

  /// Determines the appropriate circle color based on the stop's behavior.
  static Color getCircleColor(AudioBehavior behavior) {
    return behavior == AudioBehavior.speech
        ? PinColor.speechCircle
        : PinColor.ambientCircle;
  }

  /// Determines the appropriate marker icon based on the pin's type and state.
  ///
  /// The logic is prioritized: a failed pin is always red, an editable pin
  /// is always violet, etc., regardless of its underlying audio behavior.
  static BitmapDescriptor getPinIcon({
    required AudioBehavior behavior,
    required bool isPlaying,
    required bool hasFailed,
    required bool isEditMode,
  }) {
    // State overrides take precedence.
    if (hasFailed) {
      return BitmapDescriptor.defaultMarkerWithHue(PinColor.failed);
    }
    if (isEditMode) {
      return BitmapDescriptor.defaultMarkerWithHue(PinColor.editMode);
    }
    if (isPlaying) {
      return BitmapDescriptor.defaultMarkerWithHue(PinColor.playing);
    }

    // If no state override, use the color based on the audio behavior.
    final double hue = (behavior == AudioBehavior.speech)
        ? PinColor.speech
        : PinColor.ambient; // This now correctly points to hueOrange

    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }
}
////////////////////////////////// END OF FILE