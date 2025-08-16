// lib/pages/pin_editor_page.dart

import 'package:flutter/material.dart';
import '../models/tour_stop.dart'; // Import the extracted model

/// --- WIDGET: The Full-Screen Pin Editor Page ---
class PinEditorPage extends StatefulWidget {
  final TourStop initialStop;
  final List<String> availableSpeechAssets;
  final List<String> availableAmbientAssets;
  final List<TourStop> allStops;
  final bool isCreating;

  const PinEditorPage({
    super.key,
    required this.initialStop,
    required this.availableSpeechAssets,
    required this.availableAmbientAssets,
    required this.allStops,
    required this.isCreating,
  });

  @override
  State<PinEditorPage> createState() => _PinEditorPageState();
}

class _PinEditorPageState extends State<PinEditorPage> {
  late TextEditingController _nameController, _triggerRadiusController, _maxVolumeRadiusController;
  late String? _selectedAudioAsset;
  late AudioBehavior _selectedBehavior;

  List<String> get currentAssetList {
    return _selectedBehavior == AudioBehavior.speech
        ? widget.availableSpeechAssets
        : widget.availableAmbientAssets;
  }

  @override
  void initState() {
    super.initState();
    final stop = widget.initialStop;
    _nameController = TextEditingController(text: stop.name);
    _triggerRadiusController = TextEditingController(text: stop.triggerRadius.toString());
    _maxVolumeRadiusController = TextEditingController(text: stop.maxVolumeRadius.toString());
    _selectedBehavior = stop.behavior;

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an audio file.'), backgroundColor: Colors.red));
      return;
    }
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The pin name cannot be empty.'), backgroundColor: Colors.red));
      return;
    }
    final isNameUnchanged = newName == widget.initialStop.name;
    if (!isNameUnchanged) {
      final isNameTaken = widget.allStops.any((stop) => stop.name == newName);
      if (isNameTaken) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('The name "$newName" is already in use.'), backgroundColor: Colors.red));
        return;
      }
    }
    final updatedStop = widget.initialStop.copyWith(
      name: newName,
      audioAsset: _selectedAudioAsset,
      triggerRadius: double.tryParse(_triggerRadiusController.text) ?? 50.0,
      maxVolumeRadius: double.tryParse(_maxVolumeRadiusController.text) ?? 10.0,
      behavior: _selectedBehavior,
    );
    Navigator.of(context).pop(updatedStop);
  }

  void _onDelete() {
    showDialog<bool>(context: context, builder: (BuildContext context) => AlertDialog(
      title: const Text('Delete Pin?'),
      content: Text('Are you sure you want to permanently delete "${widget.initialStop.name}"?'),
      actions: <Widget>[
        TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
        TextButton(style: TextButton.styleFrom(foregroundColor: Colors.redAccent), child: const Text('Delete'), onPressed: () => Navigator.of(context).pop(true)),
      ],
    )).then((confirmed) {
      if (confirmed == true) Navigator.of(context).pop('DELETE');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(title: Text(widget.isCreating ? 'Create New Pin' : 'Edit Pin'), backgroundColor: Colors.black, actions: [IconButton(tooltip: 'Save Changes', icon: const Icon(Icons.check), onPressed: _onSave)]),
      body: ListView(padding: const EdgeInsets.all(16.0), children: [
        _buildTextField(_nameController, 'Name'), const SizedBox(height: 24),
        _buildBehaviorDropdown(), const SizedBox(height: 24),
        _buildAudioDropdown('Audio File', _selectedAudioAsset, currentAssetList, (newValue) => setState(() => _selectedAudioAsset = newValue)), const SizedBox(height: 24),
        _buildTextField(_triggerRadiusController, 'Trigger Radius (meters)', TextInputType.number), const SizedBox(height: 24),
        _buildTextField(_maxVolumeRadiusController, 'Max Volume Radius (meters)', TextInputType.number), const SizedBox(height: 24),
        if (!widget.isCreating) ...[
          const SizedBox(height: 24),
          TextButton.icon(style: TextButton.styleFrom(foregroundColor: Colors.redAccent, backgroundColor: Colors.redAccent.withOpacity(0.1)), icon: const Icon(Icons.delete_forever), label: const Text('Delete Pin'), onPressed: _onDelete),
        ]
      ]),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, [TextInputType? keyboardType]) {
    return TextField(controller: controller, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), keyboardType: keyboardType);
  }

  Widget _buildAudioDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((String filename) => DropdownMenuItem<String>(value: filename, child: Text(filename, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      isExpanded: true,
    );
  }

  Widget _buildBehaviorDropdown() {
    return DropdownButtonFormField<AudioBehavior>(
      value: _selectedBehavior,
      items: AudioBehavior.values.map((AudioBehavior behavior) => DropdownMenuItem<AudioBehavior>(value: behavior, child: Text(behavior.name))).toList(),
      onChanged: (newValue) {
        if (newValue != null) {
          setState(() {
            _selectedBehavior = newValue;
            if (!currentAssetList.contains(_selectedAudioAsset)) {
              _selectedAudioAsset = currentAssetList.isNotEmpty ? currentAssetList.first : null;
            }
          });
        }
      },
      decoration: const InputDecoration(labelText: 'Audio Behavior', border: OutlineInputBorder()),
    );
  }
}