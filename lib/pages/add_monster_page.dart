import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';

class AddMonsterPage extends StatefulWidget {
  const AddMonsterPage({super.key});

  @override
  State<AddMonsterPage> createState() => _AddMonsterPageState();
}

class _AddMonsterPageState extends State<AddMonsterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _monsterNameController = TextEditingController();
  final TextEditingController _monsterTypeController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController(text: '100');
  final MapController _mapController = MapController();
  final ImagePicker _imagePicker = ImagePicker();
  LatLng _selectedPoint = const LatLng(15.144985, 120.588702);
  File? _selectedImage;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _isPickingImage = false;
  bool _isGettingLocation = false;

  double get _radiusMeters => double.tryParse(_radiusController.text.trim()) ?? 100.0;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
  }

  Future<void> _setInitialLocation() async {
    setState(() {
      _isGettingLocation = true;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled.");
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied.");
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permission permanently denied. Enable it in app settings.");
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final currentPoint = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _selectedPoint = currentPoint;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(currentPoint, 17);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("GPS not available: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
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

  Future<void> _saveMonster() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
    });
    try {
      String? imageUrl;
      if (_selectedImage != null) {
        setState(() {
          _isUploadingImage = true;
        });
        imageUrl = await ApiService.uploadMonsterImage(_selectedImage!);
        setState(() {
          _isUploadingImage = false;
        });
      }
      final result = await ApiService.addMonster(
        monsterName: _monsterNameController.text.trim(),
        monsterType: _monsterTypeController.text.trim(),
        spawnLatitude: _selectedPoint.latitude,
        spawnLongitude: _selectedPoint.longitude,
        spawnRadiusMeters: _radiusMeters,
        pictureUrl: imageUrl,
      );
      if (!mounted) return;
      if (result["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Monster added successfully")),
        );
        _monsterNameController.clear();
        _monsterTypeController.clear();
        _radiusController.text = '100';
        setState(() {
          _selectedImage = null;
        });
        await _setInitialLocation();
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
    final latText = _selectedPoint.latitude.toStringAsFixed(7);
    final lngText = _selectedPoint.longitude.toStringAsFixed(7);
    final busy = _isSaving || _isUploadingImage || _isPickingImage || _isGettingLocation;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Monster"),
        actions: [
          IconButton(
            onPressed: _isGettingLocation ? null : _setInitialLocation,
            icon: const Icon(Icons.my_location),
          ),
        ],
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
                      const Text(
                        "Tap on the map to set the monster spawn point",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text("Latitude: $latText"),
                      const SizedBox(height: 4),
                      Text("Longitude: $lngText"),
                      const SizedBox(height: 4),
                      Text("Radius: ${_radiusMeters.toStringAsFixed(2)} meters"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedImage != null)
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
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
                  onPressed: busy ? null : _saveMonster,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      _isUploadingImage
                          ? "Uploading Image..."
                          : _isSaving
                              ? "Saving..."
                              : "Save Monster",
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
