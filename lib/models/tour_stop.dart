////////////////////////////////// START OF CODE FOR 
// lib/models/tour_stop.dart

enum AudioBehavior {
  speech,
  ambient,
}

/// --- NEW: Defines the character/type of pin for visual purposes ---
enum TourStopLabel {
  margherita,
  caterina,
  donato,
  d,
  antonio,
  music,
}

/// --- BLUEPRINT: Defines what a "Tour Stop" is ---
class TourStop {
  final String name;
  final double latitude;
  final double longitude;
  final String audioAsset;
  final double triggerRadius;
  final double maxVolumeRadius;
  final AudioBehavior behavior;
  final TourStopLabel label; // <-- NEW FIELD

  TourStop({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.audioAsset,
    required this.triggerRadius,
    required this.maxVolumeRadius,
    required this.behavior,
    required this.label, // <-- ADDED TO CONSTRUCTOR
  });

  TourStop copyWith({
    String? name,
    double? latitude,
    double? longitude,
    String? audioAsset,
    double? triggerRadius,
    double? maxVolumeRadius,
    AudioBehavior? behavior,
    TourStopLabel? label, // <-- ADDED TO COPYWITH
  }) {
    return TourStop(
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      audioAsset: audioAsset ?? this.audioAsset,
      triggerRadius: triggerRadius ?? this.triggerRadius,
      maxVolumeRadius: maxVolumeRadius ?? this.maxVolumeRadius,
      behavior: behavior ?? this.behavior,
      label: label ?? this.label, // <-- ADDED TO COPYWITH
    );
  }

  factory TourStop.fromJson(Map<String, dynamic> json) {
    // Behavior parsing (unchanged)
    String behaviorString = json['behavior'] ?? 'ambient';
    AudioBehavior behavior = AudioBehavior.values.firstWhere(
      (e) => e.name == behaviorString,
      orElse: () => AudioBehavior.ambient,
    );

    // --- NEW: Label parsing ---
    String labelString = json['label'] ?? 'margherita'; // Default to margherita
    TourStopLabel label = TourStopLabel.values.firstWhere(
      (e) => e.name == labelString,
      orElse: () => TourStopLabel.margherita, // Fallback default
    );

    return TourStop(
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      audioAsset: json['audioAsset'],
      triggerRadius: (json['triggerRadius'] as num).toDouble(),
      maxVolumeRadius: (json['maxVolumeRadius'] as num).toDouble(),
      behavior: behavior,
      label: label, // <-- PASS TO CONSTRUCTOR
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'audioAsset': audioAsset,
      'triggerRadius': triggerRadius,
      'maxVolumeRadius': maxVolumeRadius,
      'behavior': behavior.name,
      'label': label.name, 
    };
  }
}