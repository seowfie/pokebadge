import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../models/monster_model.dart';
import '../services/api_service.dart';

class EditMonsterPage extends StatefulWidget {
  final Monster monster;
  const EditMonsterPage({
    super.key,
    required this.monster,
  });
  @override
  State<EditMonsterPage> createState() => _EditMonsterPageState();
}

class _EditMonsterPageState extends State<EditMonsterPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _monsterNameController;
  late final TextEditingController _monsterTypeController;
  late final TextEditingController _radiusController;
  final MapController _mapController = MapController();
  final ImagePicker _imagePicker = ImagePicker();
  late LatLng _selectedPoint;
  File? _selectedImage;
  String? _currentPictureUrl;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _isPickingImage = false;

  double get _radiusMeters => double.tryParse(_radiusController.text.trim()) ?? 100.0;

  @override
  void initState() {
    super.initState();
    _monsterNameController = TextEditingController(text: widget.monster.monsterName);
    _monsterTypeController = TextEditingController(text: widget.monster.monsterType);
    _radiusController = TextEditingController(
      text: widget.monster.spawnRadiusMeters.toStringAsFixed(2),
    );
    _selectedPoint = LatLng(
      widget.monster.spawnLatitude,
      widget.monster.spawnLongitude,
    );
    _currentPictureUrl = widget.monster.pictureUrl;
  }

  Future<void> _captureImage() async {
    try {
      setState(() {
        _isPickingImage = true;
      });
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 55,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked == null) return;
      setState(() {
        _selectedImage = File(picked.path);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to open camera: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      setState(() {
        _isPickingImage = true;
      });
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 55,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked == null) return;
      setState(() {
        _selectedImage = File(picked.path);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to open gallery: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _updateMonster() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
    });
    try {
      String? finalPictureUrl = _currentPictureUrl;
      if (_selectedImage != null) {
        setState(() {
          _isUploadingImage = true;
        });
        finalPictureUrl = await ApiService.uploadMonsterImage(_selectedImage!);
        setState(() {
          _isUploadingImage = false;
        });
      }
      final result = await ApiService.updateMonster(
        monsterId: widget.monster.monsterId,
        monsterName: _monsterNameController.text.trim(),
        monsterType: _monsterTypeController.text.trim(),
        spawnLatitude: _selectedPoint.latitude,
        spawnLongitude: _selectedPoint.longitude,
        spawnRadiusMeters: _radiusMeters,
        pictureUrl: finalPictureUrl,
      );
      if (!mounted) return;
      if (result["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Monster updated successfully")),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result["message"]?.toString() ?? "Failed")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploadingImage = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _monsterNameController.dispose();
    _monsterTypeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isSaving || _isUploadingImage || _isPickingImage;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Monster"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _monsterNameController,
                decoration: const InputDecoration(
                  labelText: "Monster Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Enter monster name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _monsterTypeController,
                decoration: const InputDecoration(
                  labelText: "Monster Type",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Enter monster type";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _radiusController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Spawn Radius (meters)",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final radius = double.tryParse(value ?? '');
                  if (radius == null || radius <= 0) {
                    return "Enter a valid radius";
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 400,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedPoint,
                      initialZoom: 16,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _selectedPoint = point;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: "com.example.haumonsters",
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _selectedPoint,
                            radius: _radiusMeters,
                            useRadiusInMeter: true,
                            color: Colors.blue.withOpacity(0.2),
                            borderStrokeWidth: 2,
                            borderColor: Colors.blue,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedPoint,
                            width: 60,
                            height: 60,
                            child: const Icon(
                              Icons.location_pin,
                              size: 50,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        "Latitude: ${_selectedPoint.latitude.toStringAsFixed(7)}",
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Longitude: ${_selectedPoint.longitude.toStringAsFixed(7)}",
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Radius: ${_radiusMeters.toStringAsFixed(2)} meters",
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImage!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else if (_currentPictureUrl != null && _currentPictureUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _currentPictureUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 50),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : _captureImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Capture Photo"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : _pickImageFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Pick from Gallery"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: busy ? null : _updateMonster,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      _isUploadingImage
                          ? "Uploading Image..."
                          : _isSaving
                              ? "Saving..."
                              : "Update Monster",
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

            ],
          ),
        ),
      ),
    );
  }
}
