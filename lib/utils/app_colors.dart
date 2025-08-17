// lib/utils/app_colors.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/tour_stop.dart';

/// A utility class for managing the visual appearance of map pins.
class PinColor {
  // --- HUE DEFINITIONS based on the new LABEL enum ---
  static const double margherita = BitmapDescriptor.hueAzure;   // Light blue
  static const double caterina = BitmapDescriptor.hueRed;
  static const double donato = BitmapDescriptor.hueMagenta;    // Light Magenta
  static const double d = BitmapDescriptor.hueRose;           // Bright Magenta
  static const double antonio = BitmapDescriptor.hueOrange;     // Dark Green (hue is 0-360)
  static const double music = BitmapDescriptor.hueCyan;        // Proxy for White

  // --- STATE-BASED HUE DEFINITIONS (unchanged) ---
  static const double playing = BitmapDescriptor.hueGreen;
  static const double failed = BitmapDescriptor.hueRed;
  static const double editMode = BitmapDescriptor.hueViolet;

  /// Determines the appropriate circle color based on the stop's LABEL.
  static Color getCircleColor(TourStopLabel label) {
    switch (label) {
      case TourStopLabel.margherita:
        return Colors.lightBlueAccent;
      case TourStopLabel.caterina:
        return Colors.redAccent;
      case TourStopLabel.donato:
        return Colors.purpleAccent;
      case TourStopLabel.d:
        return const Color.fromARGB(255, 163, 64, 255);
      case TourStopLabel.antonio:
        return const Color.fromARGB(255, 254, 195, 1);
      case TourStopLabel.music:
        return Colors.cyanAccent.shade100;
    }
  }

  /// Determines the appropriate marker icon based on the pin's LABEL and state.
  static BitmapDescriptor getPinIcon({
    required TourStopLabel label, // <-- CHANGED from AudioBehavior
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

    // If no state override, use the color based on the label.
    double hue;
    switch (label) {
      case TourStopLabel.margherita:
        hue = PinColor.margherita;
        break;
      case TourStopLabel.caterina:
        hue = PinColor.caterina;
        break;
      case TourStopLabel.donato:
        hue = PinColor.donato;
        break;
      case TourStopLabel.d:
        hue = PinColor.d;
        break;
      case TourStopLabel.antonio:
        hue = PinColor.antonio;
        break;
      case TourStopLabel.music:
        hue = PinColor.music;
        break;
    }
    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }
}