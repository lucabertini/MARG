////////////////////////////////// START OF CODE FOR 
// lib/pages/home_page.dart

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/app_language.dart';
import '../models/tour_stop.dart';
import '../services/audio_service.dart';
import '../view_models/home_page_view_model.dart';
import '../utils/app_colors.dart';
import 'pin_editor_page.dart';

class HomePage extends StatefulWidget {
  final bool isProductionMode;

  const HomePage({super.key, this.isProductionMode = false});

  @override
  State<HomePage> createState() => _HomePageState();
}


class _HomePageState extends State<HomePage> {
  GoogleMapController? _mapController;
  int _newPinCounter = 1;
  bool _isMarkerBeingDragged = false;

  // --- THIS IS THE FIX ---
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure the widget tree is fully built
    // before we try to access the provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // This call "wakes up" the location-based audio playback logic
      // now that the user is viewing the map.
      Provider.of<HomePageViewModel>(context, listen: false).activatePlayback();
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _onLanguageChanged(HomePageViewModel viewModel, AppLanguage? newLanguage) async {
    if (newLanguage == null) return;
    
    await viewModel.changeLanguage(newLanguage);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Language switched to ${newLanguage.name.toUpperCase()}. Audio reloaded."),
        backgroundColor: Colors.indigo,
      ));
    }
  }
  
  Future<void> _openPinEditor(HomePageViewModel viewModel, TourStop stopToEdit) async {
    final bool isCreatingNewPin = !viewModel.tourStops.any((s) => s.name == stopToEdit.name);
    final originalName = stopToEdit.name;

    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) =>
        PinEditorPage(
          initialStop: stopToEdit,
          availableAssetsByLabel: viewModel.availableAssetsByLabel,
          allStops: viewModel.tourStops,
          isCreating: isCreatingNewPin,
        )));

    await viewModel.handlePinEditorResult(result, originalName);

    if (mounted && result != null) {
      if (result == 'DELETE') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pin "$originalName" deleted.'), backgroundColor: Colors.red));
      } else if (result is TourStop) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved.'), backgroundColor: Colors.green, duration: Duration(seconds: 1)));
      }
    }
  }

  Future<void> _updatePinPosition(HomePageViewModel viewModel, TourStop stopToMove, LatLng newPosition) async {
    await viewModel.updatePinPosition(stopToMove.name, newPosition);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Moved "${stopToMove.name}" to new location.'), backgroundColor: Colors.blueAccent, duration: const Duration(seconds: 2)));
    }
  }

  void _exportToJson(HomePageViewModel viewModel) {
    if (viewModel.tourStops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('There are no pins to export.')));
      return;
    }
    final String prettyJsonString = viewModel.getJsonExportString();
    _showExportDialog(prettyJsonString);
  }

  Future<void> _resetTourData(HomePageViewModel viewModel) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resetting to original tour...'), backgroundColor: Colors.orange));
    await viewModel.resetTourData();
  }

  void _showResetConfirmationDialog(HomePageViewModel viewModel) {
    showDialog(context: context, builder: (BuildContext context) => AlertDialog(
      title: const Text('Reset Tour?'),
      content: const Text('This will delete all your local changes and restore the original tour from the internet. This action cannot be undone.'),
      actions: [
        TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
        TextButton(style: TextButton.styleFrom(foregroundColor: Colors.redAccent), child: const Text('Reset'), onPressed: () {
          Navigator.of(context).pop();
          _resetTourData(viewModel);
        }),
      ],
    ),
    );
  }

  void _showExportDialog(String jsonString) {
    showDialog(context: context, builder: (BuildContext context) => AlertDialog(
      title: const Text('Exported Tour Data (JSON)'),
      content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: SelectableText(jsonString, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)))),
      actions: [
        TextButton(child: const Text('Copy to Clipboard'), onPressed: () {
          Clipboard.setData(ClipboardData(text: jsonString));
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
        }),
        TextButton(child: const Text('Done'), onPressed: () => Navigator.of(context).pop()),
      ],
    ));
  }

  void _zoomToFitAllStops(List<TourStop> tourStops) {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_mapController == null || tourStops.isEmpty || !mounted) return;
      if (tourStops.length == 1) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(tourStops.first.latitude, tourStops.first.longitude), 15.0));
        return;
      }
      double minLat = tourStops.first.latitude, maxLat = tourStops.first.latitude;
      double minLng = tourStops.first.longitude, maxLng = tourStops.first.longitude;
      for (final stop in tourStops) {
        minLat = min(minLat, stop.latitude);
        maxLat = max(maxLat, stop.latitude);
        minLng = min(minLng, stop.longitude);
        maxLng = max(maxLng, stop.longitude);
      }
      final bounds = LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomePageViewModel>(
      builder: (context, viewModel, child) {
        // This is a one-time operation after the view model has finished loading.
        // We listen for the first time isLoading becomes false with content.
        if (!viewModel.isLoading && viewModel.tourStops.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _zoomToFitAllStops(viewModel.tourStops);
          });
        }

        return Scaffold(
          body: () {
            if (viewModel.isLoading) {
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const CircularProgressIndicator(), const SizedBox(height: 20), Text(viewModel.statusMessage),
              ]));
            }
            
            if (widget.isProductionMode) {
              return _buildDisabledView();
            }
            
            return _buildTourUI(viewModel);
          }(),
        );
      },
    );
  }

  Widget _buildTourUI(HomePageViewModel viewModel) {
    final audioService = context.read<AudioService>();
    final tourStops = viewModel.tourStops;
    final failedAudioPins = viewModel.failedAudioPins;
    const double mapPadding = 270;
    
    return Stack(children: [
      GoogleMap(
        initialCameraPosition: CameraPosition(target: tourStops.isNotEmpty ? LatLng(tourStops.first.latitude, tourStops.first.longitude) : const LatLng(41.9028, 12.4964), zoom: 15),
        onMapCreated: (GoogleMapController controller) async {
          _mapController = controller;
          final String mapStyle = await rootBundle.loadString('assets/map_styles/dark_mode.json');
          await _mapController!.setMapStyle(mapStyle);
          // The zoom operation is now handled in the main build method's post-frame callback
        },
        markers: tourStops.map((stop) {
          final isPlaying = viewModel.currentlyPlayingIds.contains(stop.name);
          final hasFailed = failedAudioPins.contains(stop.name);

          final icon = PinColor.getPinIcon(
            label: stop.label,
            isPlaying: isPlaying,
            hasFailed: hasFailed,
          );

          return Marker(
            markerId: MarkerId(stop.name),
            position: LatLng(stop.latitude, stop.longitude),
            icon: icon,
            draggable: viewModel.isEditModeEnabled,
            onDragStart: (_) { if (viewModel.isEditModeEnabled) setState(() => _isMarkerBeingDragged = true); },
            onDragEnd: (newPosition) { if (viewModel.isEditModeEnabled) {
              setState(() => _isMarkerBeingDragged = false);
              _updatePinPosition(viewModel, stop, newPosition);
            }},
            onTap: () {
              if (viewModel.isEditModeEnabled) {
                _openPinEditor(viewModel, stop);
              } else {
                if (hasFailed && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Audio for "${stop.name}" could not be loaded.'), backgroundColor: Colors.red.shade900));
                  return;
                }
                isPlaying ? audioService.stop(stop.name) : audioService.play(stop.name);
              }
            },
          );
        }).toSet(),
        circles: tourStops.expand((stop) {
          final circleBaseColor = PinColor.getCircleColor(stop.label);
          return [
            Circle(circleId: CircleId('${stop.name}_trigger'), center: LatLng(stop.latitude, stop.longitude), radius: stop.triggerRadius, fillColor: circleBaseColor.withOpacity(0.1), strokeWidth: 1, strokeColor: circleBaseColor.withOpacity(0.5)),
            Circle(circleId: CircleId('${stop.name}_max_volume'), center: LatLng(stop.latitude, stop.longitude), radius: stop.maxVolumeRadius, fillColor: circleBaseColor.withOpacity(0.2), strokeWidth: 2, strokeColor: circleBaseColor),
          ];
        }).toSet(),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        padding: const EdgeInsets.only(bottom: mapPadding),
        onLongPress: (LatLng latLng) {
          if (viewModel.isEditModeEnabled && !_isMarkerBeingDragged) {
            final defaultLabel = TourStopLabel.margherita;
            final assetsForDefaultLabel = viewModel.availableAssetsByLabel[defaultLabel] ?? [];
            final defaultAudioAsset = assetsForDefaultLabel.isNotEmpty ? assetsForDefaultLabel.first : '';

            final newStop = TourStop(
                name: 'New Pin $_newPinCounter',
                latitude: latLng.latitude,
                longitude: latLng.longitude,
                audioAsset: defaultAudioAsset,
                triggerRadius: 50.0,
                maxVolumeRadius: 10.0,
                behavior: AudioBehavior.speech,
                label: defaultLabel,
            );
            _newPinCounter++;
            _openPinEditor(viewModel, newStop);
          }
        },
      ),
      Positioned(left: 0, right: 0, bottom: 0, child: _buildStatusPanel(viewModel))
    ]);
  }

  Widget _buildStatusPanel(HomePageViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('KITCHEN LAB', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
        const Divider(color: Colors.white24, height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Audio Language', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
          DropdownButton<AppLanguage>(
            value: viewModel.selectedLanguage,
            items: AppLanguage.values.map((lang) => DropdownMenuItem(value: lang, child: Text(lang.name.toUpperCase()))).toList(),
            onChanged: (lang) => _onLanguageChanged(viewModel, lang),
            underline: Container(),
            dropdownColor: Colors.grey.shade800,
          )
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Edit Mode', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
          Switch(
            value: viewModel.isEditModeEnabled, 
            activeColor: Colors.purpleAccent, 
            onChanged: viewModel.toggleEditMode,
          ),
        ]),
        if (viewModel.isEditModeEnabled) ...[
          const SizedBox(height: 8),
          ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white), icon: const Icon(Icons.print), label: const Text('Export Tour to JSON'), onPressed: () => _exportToJson(viewModel)),
          const SizedBox(height: 8),
          ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), icon: const Icon(Icons.delete_sweep), label: const Text('Reset Tour to Default'), onPressed: () => _showResetConfirmationDialog(viewModel)),
        ]
      ]),
    );
  }

  Widget _buildDisabledView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 24),
            Text('MARGHERITA', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}