// lib/pages/pin_editor_page.dart

import 'package:flutter/material.dart';
import '../models/tour_stop.dart';

// Helper function to capitalize strings
String capitalize(String s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);

/// --- WIDGET: The Full-Screen Pin Editor Page ---
class PinEditorPage extends StatefulWidget {
  final TourStop initialStop;
  final Map<TourStopLabel, List<String>> availableAssetsByLabel;
  final List<TourStop> allStops;
  final bool isCreating;

  const PinEditorPage({
    super.key,
    required this.initialStop,
    required this.availableAssetsByLabel,
    required this.allStops,
    required this.isCreating,
  });

  @override
  State<PinEditorPage> createState() => _PinEditorPageState();
}

class _PinEditorPageState extends State<PinEditorPage> {
  late TextEditingController _nameController,
      _triggerRadiusController,
      _maxVolumeRadiusController;
  late String? _selectedAudioAsset;
  late AudioBehavior _selectedBehavior;
  late TourStopLabel _selectedLabel;

  // --- FIX #1: Add a dynamic getter for the current asset list ---
  // This getter ensures that whenever the UI rebuilds, it fetches the
  // correct list of audio files based on the *currently selected* label.
  List<String> get currentAssetList {
    return widget.availableAssetsByLabel[_selectedLabel] ?? [];
  }

  @override
  void initState() {
    super.initState();
    final stop = widget.initialStop;
    _nameController = TextEditingController(text: stop.name);
    _triggerRadiusController =
        TextEditingController(text: stop.triggerRadius.toString());
    _maxVolumeRadiusController =
        TextEditingController(text: stop.maxVolumeRadius.toString());
    _selectedBehavior = stop.behavior;
    _selectedLabel = stop.label;

    // Use the new getter to correctly initialize the audio asset selection
    if (currentAssetList.contains(stop.audioAsset)) {
      _selectedAudioAsset = stop.audioAsset;
    } else if (currentAssetList.isNotEmpty) {
      _selectedAudioAsset = currentAssetList.first;
    } else {
      _selectedAudioAsset = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _triggerRadiusController.dispose();
    _maxVolumeRadiusController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (_selectedAudioAsset == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select an audio file.'),
          backgroundColor: Colors.red));
      return;
    }
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('The pin name cannot be empty.'),
          backgroundColor: Colors.red));
      return;
    }
    final isNameUnchanged = newName == widget.initialStop.name;
    if (!isNameUnchanged) {
      final isNameTaken = widget.allStops.any((stop) => stop.name == newName);
      if (isNameTaken) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('The name "$newName" is already in use.'),
            backgroundColor: Colors.red));
        return;
      }
    }
    final updatedStop = widget.initialStop.copyWith(
      name: newName,
      audioAsset: _selectedAudioAsset,
      triggerRadius: double.tryParse(_triggerRadiusController.text) ?? 50.0,
      maxVolumeRadius: double.tryParse(_maxVolumeRadiusController.text) ?? 10.0,
      behavior: _selectedBehavior,
      label: _selectedLabel,
    );
    Navigator.of(context).pop(updatedStop);
  }

  void _onDelete() {
    showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              title: const Text('Delete Pin?'),
              content: Text(
                  'Are you sure you want to permanently delete "${widget.initialStop.name}"?'),
              actions: <Widget>[
                TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(false)),
                TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    child: const Text('Delete'),
                    onPressed: () => Navigator.of(context).pop(true)),
              ],
            )).then((confirmed) {
      if (confirmed == true) Navigator.of(context).pop('DELETE');
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
          title: Text(widget.isCreating ? 'Create New Pin' : 'Edit Pin'),
          backgroundColor: Colors.black,
          actions: [
            IconButton(
                tooltip: 'Save Changes',
                icon: const Icon(Icons.check),
                onPressed: _onSave)
          ]),
      body: ListView(padding: const EdgeInsets.all(16.0), children: [
        _buildTextField(_nameController, 'Name'),
        const SizedBox(height: 24),
        _buildLabelDropdown(),
        const SizedBox(height: 24),
        // --- FIX #3: Use the `currentAssetList` getter here ---
        _buildAudioDropdown('Audio File', _selectedAudioAsset, currentAssetList,
            (newValue) => setState(() => _selectedAudioAsset = newValue)),
        const SizedBox(height: 24),
        _buildBehaviorDropdown(),
        const SizedBox(height: 24),
        _buildTextField(
            _triggerRadiusController, 'Trigger Radius (meters)', TextInputType.number),
        const SizedBox(height: 24),
        _buildTextField(_maxVolumeRadiusController, 'Max Volume Radius (meters)',
            TextInputType.number),
        const SizedBox(height: 24),
        if (!widget.isCreating) ...[
          const SizedBox(height: 24),
          TextButton.icon(
              style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  backgroundColor: Colors.redAccent.withOpacity(0.1)),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete Pin'),
              onPressed: _onDelete),
        ]
      ]),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      [TextInputType? keyboardType]) {
    return TextField(
        controller: controller,
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder()),
        keyboardType: keyboardType);
  }

  Widget _buildAudioDropdown(String label, String? value, List<String> items,
      ValueChanged<String?> onChanged) {
    // If there are no items, show a disabled-looking field.
    if (items.isEmpty) {
        return TextFormField(
            readOnly: true,
            decoration: InputDecoration(
                labelText: label,
                hintText: 'No audio files for this label',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey.shade800
            ),
        );
    }
    
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      items: items
          .map((String filename) => DropdownMenuItem<String>(
              value: filename,
              child: Text(filename, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      isExpanded: true,
    );
  }

  Widget _buildLabelDropdown() {
    return DropdownButtonFormField<TourStopLabel>(
      value: _selectedLabel,
      items: TourStopLabel.values
          .map((TourStopLabel label) => DropdownMenuItem<TourStopLabel>(
              value: label, child: Text(capitalize(label.name))))
          .toList(),
      // --- FIX #2: Implement the full logic in the onChanged callback ---
      onChanged: (newValue) {
        if (newValue != null) {
          // This setState call is crucial. It tells Flutter to rebuild the UI.
          setState(() {
            // 1. Update the selected label.
            _selectedLabel = newValue;
            
            // 2. Get the list of assets for the NEW label.
            final newAssetList = widget.availableAssetsByLabel[_selectedLabel] ?? [];

            // 3. Check if the old audio file is in the new list.
            if (!newAssetList.contains(_selectedAudioAsset)) {
              // 4. If not, reset the audio file selection to the first item
              //    in the new list, or null if it's empty.
              _selectedAudioAsset = newAssetList.isNotEmpty ? newAssetList.first : null;
            }
          });
        }
      },
      decoration:
          const InputDecoration(labelText: 'Label (Character/Type)', border: OutlineInputBorder()),
    );
  }

  Widget _buildBehaviorDropdown() {
    return DropdownButtonFormField<AudioBehavior>(
      value: _selectedBehavior,
      items: AudioBehavior.values
          .map((AudioBehavior behavior) => DropdownMenuItem<AudioBehavior>(
              value: behavior, child: Text(capitalize(behavior.name))))
          .toList(),
      onChanged: (newValue) {
        if (newValue != null) {
          setState(() {
            _selectedBehavior = newValue;
          });
        }
      },
      decoration: const InputDecoration(
          labelText: 'Audio Behavior (Playback Rule)', border: OutlineInputBorder()),
    );
  }
}