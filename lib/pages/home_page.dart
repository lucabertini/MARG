////////////////////////////////// START OF CODE FOR
// lib/pages/home_page.dart

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui; // Import for image rendering

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // Import for RepaintBoundary
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

  // --- NEW: State for managing custom marker icons ---
  final Map<String, GlobalKey> _markerKeys = {};
  final Map<String, BitmapDescriptor> _markerIcons = {};
  bool _areCustomIconsBuilt = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
  
  void _showLanguageDialog(HomePageViewModel viewModel) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Language'),
          backgroundColor: Colors.grey.shade900,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppLanguage.values.map((lang) {
              return ListTile(
                title: Text(lang == AppLanguage.it ? 'Italiano' : 'English'),
                onTap: () {
                  Navigator.of(context).pop();
                  _onLanguageChanged(viewModel, lang);
                },
              );
            }).toList(),
          ),
        );
      },
    );
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

  Widget _pinInfoWidget(TourStop stop) {
    String audioFileName = stop.audioAsset;
    final lastDotIndex = audioFileName.lastIndexOf('.');
    if (lastDotIndex != -1) {
      audioFileName = audioFileName.substring(0, lastDotIndex);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white54, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(stop.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8)),
          const SizedBox(height: 2),
          Text(audioFileName, style: const TextStyle(color: Colors.white70, fontSize: 8)),
          Text(stop.behavior.name, style: const TextStyle(color: Colors.cyanAccent, fontStyle: FontStyle.italic, fontSize: 5)),
        ],
      ),
    );
  }

  List<Widget> _buildOffscreenMarkerWidgets(HomePageViewModel viewModel) {
    if (!viewModel.showPinInfo) {
      if (_areCustomIconsBuilt) {
        WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {
          _areCustomIconsBuilt = false;
          _markerIcons.clear();
        }));
      }
      return [];
    }
    
    _markerKeys.removeWhere((key, value) => !viewModel.tourStops.any((s) => s.name == key));
    
    return viewModel.tourStops.map((stop) {
      final key = _markerKeys.putIfAbsent(stop.name, () => GlobalKey());
      return Transform.translate(
        offset: const Offset(-9999, -9999),
        child: RepaintBoundary(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pinInfoWidget(stop),
              Icon(Icons.location_on, color: PinColor.getCircleColor(stop.label), size: 42),
            ],
          ),
        ),
      );
    }).toList();
  }

  Future<void> _updateMarkerIcons(HomePageViewModel viewModel) async {
    if (!viewModel.showPinInfo || _areCustomIconsBuilt) return;

    final Map<String, BitmapDescriptor> newIcons = {};

    for (final stop in viewModel.tourStops) {
      final key = _markerKeys[stop.name];
      if (key == null) continue;
      final context = key.currentContext;
      if (context == null) continue;
      
      try {
        final boundary = context.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.5);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        
        if (byteData == null) continue;
        
        final bytes = byteData.buffer.asUint8List();
        newIcons[stop.name] = BitmapDescriptor.fromBytes(bytes);
      } catch (e) {
        debugPrint("Error creating marker icon for ${stop.name}: $e");
      }
    }
    
    if (mounted && newIcons.isNotEmpty) {
      setState(() {
        _markerIcons.addAll(newIcons);
        _areCustomIconsBuilt = true;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<HomePageViewModel>(
      builder: (context, viewModel, child) {
        if (!viewModel.isLoading && viewModel.tourStops.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _zoomToFitAllStops(viewModel.tourStops);
            _updateMarkerIcons(viewModel);
          });
        }

        return Scaffold(
          body: Stack(
            children: [
              Builder(
                builder: (context) {
                  if (viewModel.isLoading) {
                    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const CircularProgressIndicator(), const SizedBox(height: 20), Text(viewModel.statusMessage),
                    ]));
                  }
                  
                  if (widget.isProductionMode) {
                    return _buildDisabledView();
                  }
                  
                  return _buildTourUI(viewModel);
                },
              ),
              ..._buildOffscreenMarkerWidgets(viewModel),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTourUI(HomePageViewModel viewModel) {
    final audioService = context.read<AudioService>();
    final tourStops = viewModel.tourStops;
    final failedAudioPins = viewModel.failedAudioPins;
    const double mapPadding = 120;
    
    return Stack(children: [
      GoogleMap(
        initialCameraPosition: CameraPosition(target: tourStops.isNotEmpty ? LatLng(tourStops.first.latitude, tourStops.first.longitude) : const LatLng(41.9028, 12.4964), zoom: 15),
        onMapCreated: (GoogleMapController controller) async {
          _mapController = controller;
          final String mapStyle = await rootBundle.loadString('assets/map_styles/dark_mode.json');
          await _mapController!.setMapStyle(mapStyle);
        },
        markers: tourStops.map((stop) {
          final isPlaying = viewModel.currentlyPlayingIds.contains(stop.name);
          final hasFailed = failedAudioPins.contains(stop.name);

          BitmapDescriptor icon;
          if (viewModel.showPinInfo && _markerIcons.containsKey(stop.name)) {
            icon = _markerIcons[stop.name]!;
          } else {
            icon = PinColor.getPinIcon(
              label: stop.label,
              isPlaying: isPlaying,
              hasFailed: hasFailed,
            );
          }
          
          return Marker(
            markerId: MarkerId(stop.name),
            position: LatLng(stop.latitude, stop.longitude),
            icon: icon,
            anchor: viewModel.showPinInfo ? const Offset(0.5, 0.9) : const Offset(0.5, 1.0), 
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
      Positioned(left: 0, right: 0, bottom: 0, child: _buildControlBar(viewModel))
    ]);
  }

  // --- WIDGETS FOR THE NEW CONTROL BAR ---

  Widget _buildControlBar(HomePageViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.all(20.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(50), // Pill shape
          border: Border.all(color: Colors.white30, width: 0.5),
      ),
      child: viewModel.isEditModeEnabled
          ? _buildExpandedControls(viewModel)
          : _buildCompactControls(viewModel),
    );
  }

  Widget _buildCompactControls(HomePageViewModel viewModel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildCircularButton(
          text: viewModel.selectedLanguage.name.toUpperCase(),
          onPressed: () => _showLanguageDialog(viewModel),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        _buildCircularButton(
          text: 'EDIT',
          onPressed: () => viewModel.toggleEditMode(true),
          backgroundColor: Colors.purpleAccent,
        ),
      ],
    );
  }
  
  // --- MODIFIED: Reordered the buttons ---
  Widget _buildExpandedControls(HomePageViewModel viewModel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // IT button moved to the far left
        _buildCircularButton(
          text: viewModel.selectedLanguage.name.toUpperCase(),
          tooltip: 'Change Language',
          onPressed: () => _showLanguageDialog(viewModel),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        _buildCircularButton(
          text: 'EX',
          tooltip: 'Export Tour to JSON',
          onPressed: () => _exportToJson(viewModel),
          backgroundColor: Colors.blueGrey.shade700,
        ),
        _buildCircularButton(
          text: 'REV',
          tooltip: 'Reset Tour',
          onPressed: () => _showResetConfirmationDialog(viewModel),
          backgroundColor: Colors.blueGrey.shade700,
        ),
        _buildCircularButton(
          text: 'PINS',
          tooltip: 'Show/Hide Pin Info',
          onPressed: () {
            setState(() => _areCustomIconsBuilt = false);
            viewModel.toggleShowPinInfo(!viewModel.showPinInfo);
          },
          backgroundColor: viewModel.showPinInfo ? Colors.green.shade600 : Colors.purpleAccent,
        ),
        _buildCircularButton(
          text: 'EDIT',
          tooltip: 'Exit Edit Mode',
          onPressed: () {
            if (viewModel.showPinInfo) {
              viewModel.toggleShowPinInfo(false);
            }
            viewModel.toggleEditMode(false);
          },
          backgroundColor: Colors.green.shade600,
        ),
      ],
    );
  }
  
  Widget _buildCircularButton({
    String? text,
    IconData? icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    String? tooltip,
    Color foregroundColor = Colors.white,
    double size = 52.0,
  }) {
    final buttonContent = text != null
        ? Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
        : Icon(icon, size: 24);

    final button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
        fixedSize: Size(size * 0.95, size * 0.95),
      ),
      child: buttonContent,
    );
    
    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: button,
      );
    }
    
    return button;
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