import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:torch_light/torch_light.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/monster_model.dart';
import '../services/api_service.dart';

class CatchMonsterPage extends StatefulWidget {
  const CatchMonsterPage({super.key});

  @override
  State<CatchMonsterPage> createState() => _CatchMonsterPageState();
}

class _CatchMonsterPageState extends State<CatchMonsterPage> {
  // Set default coordinates to Holy Angel University
  final TextEditingController _latController = TextEditingController(text: "15.144985");
  final TextEditingController _lngController = TextEditingController(text: "120.588702");
  final MapController _mapController = MapController();
  
  List<Monster> _monsters = [];
  List<Map<String, dynamic>> _locations = [];
  
  bool _isLoading = true;
  String? _errorMessage;
  
  bool _detecting = false;
  Monster? _detectedMonster;
  double? _detectedMonsterDistance;
  
  Map<String, dynamic>? _matchedLocation;

  @override
  void initState() {
    super.initState();
    _latController.addListener(_updateMatchedLocation);
    _lngController.addListener(_updateMatchedLocation);
    _initializeData();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
          _detectedMonster = null;
        });
      }
      
      final monsters = await ApiService.getMonsters();
      final locations = await ApiService.getLocations();
      final prefs = await SharedPreferences.getInstance();
      final caughtList = prefs.getStringList('caught_monsters') ?? [];
      
      if (mounted) {
        setState(() {
          _monsters = monsters.where((m) => !caughtList.contains(m.monsterId.toString())).toList();
          _locations = locations;
          _isLoading = false;
        });
        _updateMatchedLocation();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _updateMatchedLocation() {
    if (_locations.isEmpty) return;
    
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    
    if (lat == null || lng == null) {
      if (mounted) setState(() => _matchedLocation = null);
      return;
    }

    Map<String, dynamic>? closest;
    double minDistance = double.infinity;

    for (var loc in _locations) {
      final locLat = double.tryParse(loc['center_latitude'].toString()) ?? 0.0;
      final locLng = double.tryParse(loc['center_longitude'].toString()) ?? 0.0;

      final distance = Geolocator.distanceBetween(lat, lng, locLat, locLng);
      // Removed radius requirement -> always associate to the *closest* recognized location
      if (distance < minDistance) {
        minDistance = distance;
        closest = loc;
      }
    }

    if (mounted) {
      setState(() {
        _matchedLocation = closest;
      });
    }
  }

  Future<void> _triggerAudioAndTorch() async {
    final player = AudioPlayer();
    try {
      await player.play(AssetSource('sounds/monster_alarm.wav'));
    } catch (e) {
      debugPrint("Audio error: ${e}");
    }
    
    try {
      bool hasTorch = await TorchLight.isTorchAvailable();
      if (hasTorch) {
        await TorchLight.enableTorch();
      }
    } catch (e) {
      debugPrint("Torch error: ${e}");
    }

    await Future.delayed(const Duration(seconds: 3));

    try {
      await TorchLight.disableTorch();
    } catch (_) {}
    
    try {
      await player.stop();
      player.dispose();
    } catch (_) {}
  }

  void _detectMonsters() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid Latitude and Longitude.")),
      );
      return;
    }

    setState(() {
      _detecting = true;
      _detectedMonster = null;
    });

    // Simulate detecting delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    Monster? foundMonster;
    double? foundDistance;
    double minDistance = double.infinity;

    for (var m in _monsters) {
      final distance = Geolocator.distanceBetween(
        lat,
        lng,
        m.spawnLatitude,
        m.spawnLongitude,
      );
      // Removed spawn radius requirement -> detects closest monster
      if (distance < minDistance) {
        foundMonster = m;
        foundDistance = distance;
        minDistance = distance;
      }
    }

    setState(() {
      _detecting = false;
      _detectedMonster = foundMonster;
      _detectedMonsterDistance = foundDistance;
    });

    if (foundMonster == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No monsters detected near these coordinates.")),
      );
    }
  }

  void _performCatch(Monster monster) async {
    final lat = double.tryParse(_latController.text.trim()) ?? 0.0;
    final lng = double.tryParse(_lngController.text.trim()) ?? 0.0;

    // Optional audio/torch
    _triggerAudioAndTorch();

    try {
      final prefs = await SharedPreferences.getInstance();
      final playerIdStr = prefs.getString('player_id') ?? '1';
      final playerId = int.tryParse(playerIdStr) ?? 1;
      
      final locationId = _matchedLocation != null 
          ? (int.tryParse(_matchedLocation!['location_id'].toString()) ?? 1) 
          : 1;

      final response = await ApiService.catchMonster(
        playerId: playerId,
        monsterId: monster.monsterId,
        locationId: locationId,
        latitude: lat,
        longitude: lng,
      );

      if (response['success'] == true || response['status'] == 'success') {
        final caughtList = prefs.getStringList('caught_monsters') ?? [];
        if (!caughtList.contains(monster.monsterId.toString())) {
          caughtList.add(monster.monsterId.toString());
          await prefs.setStringList('caught_monsters', caughtList);
        }
        
        if (mounted) {
          final locName = _matchedLocation!['location_name'] ?? 'Unknown Location';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Caught ${monster.monsterName} at $locName!"),
              backgroundColor: const Color(0xFF386641),
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() {
            _monsters.removeWhere((m) => m.monsterId == monster.monsterId);
            _detectedMonster = null;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to catch: ${response['message'] ?? response['error']}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network Error: Could not save catch to server.")),
        );
      }
      debugPrint("Failed to save catch: $e");
    }
  }

  Widget _buildDetectionResult() {
    if (_detectedMonster == null) return const SizedBox.shrink();

    final locName = _matchedLocation?['location_name'] ?? 'Unknown Location';

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5EB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _detectedMonster!.monsterName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Type: ${_detectedMonster!.monsterType}",
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Text(
            "Found a monster in this location -> $locName",
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _performCatch(_detectedMonster!),
              icon: const Icon(Icons.catching_pokemon, color: Color(0xFF386641)),
              label: const Text(
                "Catch Monster",
                style: TextStyle(color: Color(0xFF386641), fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF386641), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFDF6),
      appBar: AppBar(
        title: const Text("Catch Monsters", style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text("Error: ${_errorMessage}"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Map View added back and defaulted to Holy Angel University
                      Container(
                        height: 200,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: const LatLng(15.144985, 120.588702),
                            initialZoom: 16.0,
                            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                            onTap: (tapPosition, point) {
                              _latController.text = point.latitude.toStringAsFixed(6);
                              _lngController.text = point.longitude.toStringAsFixed(6);
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                              userAgentPackageName: "com.example.haumonsters",
                            ),
                            if (_monsters.isNotEmpty)
                              CircleLayer(
                                circles: _monsters.map((m) => CircleMarker(
                                  point: LatLng(m.spawnLatitude, m.spawnLongitude),
                                  radius: m.spawnRadiusMeters,
                                  useRadiusInMeter: true,
                                  color: Colors.red.withOpacity(0.2),
                                  borderColor: Colors.red,
                                  borderStrokeWidth: 2,
                                )).toList(),
                              ),
                            if (_monsters.isNotEmpty)
                              MarkerLayer(
                                markers: _monsters.map((m) => Marker(
                                  point: LatLng(m.spawnLatitude, m.spawnLongitude),
                                  width: 40,
                                  height: 40,
                                  child: m.pictureUrl != null && m.pictureUrl!.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            m.pictureUrl!, 
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stack) => const Icon(Icons.catching_pokemon, color: Colors.red, size: 30),
                                          )
                                        )
                                      : const Icon(Icons.catching_pokemon, color: Colors.blueAccent, size: 30),
                                )).toList(),
                              ),
                          ],
                        ),
                      ),
                      TextField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: "- Your Latitude -",
                          labelStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF386641), width: 2)),
                          prefixIcon: Icon(Icons.my_location, color: Colors.black87),
                        ),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: "- Your Longitude -",
                          labelStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF386641), width: 2)),
                          prefixIcon: Icon(Icons.explore, color: Colors.black87),
                        ),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC8E6C9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Current matched location: ${_matchedLocation?['location_name'] ?? 'None'}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_detecting)
                        ElevatedButton.icon(
                          onPressed: null,
                          icon: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                          ),
                          label: const Text("Detecting..."),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.grey.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            elevation: 0,
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _detectMonsters,
                          icon: const Icon(Icons.radar, color: Colors.white),
                          label: const Text(
                            "Detect Monsters",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF386641),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                        ),
                      _buildDetectionResult(),
                    ],
                  ),
                ),
    );
  }
}