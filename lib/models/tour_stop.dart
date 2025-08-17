// START OF CODE FOR lib/models/tour_stop.dart

//import 'package:flutter/foundation.dart';

/// --- A set of pre-approved choices for how audio should behave ---
enum AudioBehavior {
  speech,
  ambient,
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

  TourStop({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.audioAsset,
    required this.triggerRadius,
    required this.maxVolumeRadius,
    required this.behavior,
  });

  TourStop copyWith({
    String? name,
    double? latitude,
    double? longitude,
    String? audioAsset,
    double? triggerRadius,
    double? maxVolumeRadius,
    AudioBehavior? behavior,
  }) {
    return TourStop(
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      audioAsset: audioAsset ?? this.audioAsset,
      triggerRadius: triggerRadius ?? this.triggerRadius,
      maxVolumeRadius: maxVolumeRadius ?? this.maxVolumeRadius,
      behavior: behavior ?? this.behavior,
    );
  }

  factory TourStop.fromJson(Map<String, dynamic> json) {
    String behaviorString = json['behavior'] ?? 'ambient';
    AudioBehavior behavior = AudioBehavior.values.firstWhere(
          (e) => e.name == behaviorString,
      orElse: () => AudioBehavior.ambient,
    );

    return TourStop(
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      audioAsset: json['audioAsset'],
      triggerRadius: (json['triggerRadius'] as num).toDouble(),
      maxVolumeRadius: (json['maxVolumeRadius'] as num).toDouble(),
      behavior: behavior,
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
    };
  }
}
// END OF FILE