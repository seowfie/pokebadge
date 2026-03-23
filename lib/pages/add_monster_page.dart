import 'dart:io';
import 'dart:math';
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
  final TextEditingController _radiusController = TextEditingController(text: '10');
  final MapController _mapController = MapController();
  final ImagePicker _imagePicker = ImagePicker();
  // Start at CHAPEL
  LatLng _selectedPoint = const LatLng(15.132142, 120.589501);
  File? _selectedImage;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _isPickingImage = false;
  bool _isGettingLocation = false;
  String? _selectedBuildingName = 'CHAPEL';

  final _random = Random();

  // Same building list as catch_monster_page
  static const List<Map<String, dynamic>> _buildings = [
    {'name': 'St. Martha Hall', 'lat': 15.133576, 'lng': 120.591420},
    {'name': 'SFJ',             'lat': 15.133271, 'lng': 120.591094},
    {'name': 'STL',             'lat': 15.132660, 'lng': 120.590788},
    {'name': 'PGN',             'lat': 15.132654, 'lng': 120.590263},
    {'name': 'APS',             'lat': 15.131826, 'lng': 120.589936},
    {'name': 'MGN',             'lat': 15.133208, 'lng': 120.589979},
    {'name': 'SJH',             'lat': 15.132701, 'lng': 120.589073},
    {'name': 'CHAPEL',          'lat': 15.132142, 'lng': 120.589501},
    {'name': 'GGN',             'lat': 15.131748, 'lng': 120.590675},
    {'name': 'Covered Court',   'lat': 15.131412, 'lng': 120.589191},
  ];

  double get _radiusMeters => double.tryParse(_radiusController.text.trim()) ?? 10.0;

  /// Returns a random LatLng within [radiusMeters] of [center]
  LatLng _randomPointInRadius(double centerLat, double centerLng, double radiusMeters) {
    final angle = _random.nextDouble() * 2 * pi;
    final distance = sqrt(_random.nextDouble()) * radiusMeters; // uniform in circle
    final latOffset = distance / 111111;
    final lngOffset = distance / (111111 * cos(centerLat * pi / 180));
    return LatLng(
      centerLat + latOffset * cos(angle),
      centerLng + lngOffset * sin(angle),
    );
  }

  @override
  void initState() {
    super.initState();
    // Do NOT call _setInitialLocation here anymore, as it overwrites our Chapel default with device GPS.
    // Instead, just ensure the map is centered on our default point.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(_selectedPoint, 17);
    });
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
              // Building selector dropdown
              DropdownButtonFormField<String>(
                value: _selectedBuildingName,
                decoration: const InputDecoration(
                  labelText: "Place at Building (optional)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
                hint: const Text("Tap map or select a building"),
                items: [
                  ..._buildings.map((b) => DropdownMenuItem<String>(
                    value: b['name'] as String,
                    child: Text(b['name'] as String),
                  )),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  final building = _buildings.firstWhere((b) => b['name'] == value);
                  final bLat = building['lat'] as double;
                  final bLng = building['lng'] as double;
                  // Random point within the building's 40m zone
                  final point = _randomPointInRadius(bLat, bLng, 40);
                  setState(() {
                    _selectedBuildingName = value;
                    _selectedPoint = point;
                  });
                  _mapController.move(point, 17);
                },
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
                      // Building zone reference circles (blue, 40m)
                      CircleLayer(
                        circles: _buildings.map((b) => CircleMarker(
                          point: LatLng(b['lat'] as double, b['lng'] as double),
                          radius: 40,
                          useRadiusInMeter: true,
                          color: Colors.blue.withOpacity(0.10),
                          borderColor: Colors.blue.shade400,
                          borderStrokeWidth: 1.5,
                        )).toList(),
                      ),
                      // Selected spawn radius circle
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _selectedPoint,
                            radius: _radiusMeters,
                            useRadiusInMeter: true,
                            color: Colors.red.withOpacity(0.2),
                            borderStrokeWidth: 2,
                            borderColor: Colors.red,
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
