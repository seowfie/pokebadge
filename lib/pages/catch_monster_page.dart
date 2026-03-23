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
  final TextEditingController _latController = TextEditingController(text: "15.133103");
  final TextEditingController _lngController = TextEditingController(text: "120.590585");
  final MapController _mapController = MapController();
  
  List<Monster> _monsters = [];
  List<Map<String, dynamic>> _locations = [];
  
  bool _isLoading = true;
  String? _errorMessage;
  
  bool _detecting = false;
  Monster? _detectedMonster;
  double? _detectedMonsterDistance;
  
  Map<String, dynamic>? _matchedLocation;

  // HAU building zones — each has a 40m radius and 4 sub-spawn spots
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

  // 10m offset in degrees (approx at this latitude)
  static const double _latOffset = 0.00009;   // ~10m N/S
  static const double _lngOffset = 0.0000932; // ~10m E/W

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
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (lat == null || lng == null) {
      if (mounted) setState(() => _matchedLocation = null);
      return;
    }

    Map<String, dynamic>? matched;

    for (var building in _buildings) {
      final bLat = building['lat'] as double;
      final bLng = building['lng'] as double;
      final distance = Geolocator.distanceBetween(lat, lng, bLat, bLng);
      if (distance <= 40) {
        matched = {'location_name': building['name']};
        break;
      }
    }

    if (mounted) {
      setState(() {
        _matchedLocation = matched;
      });

      // Move the map to match the new coordinates!
      try {
        _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
      } catch (e) {
        // MapController might not be ready yet
      }
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
      // Only detect monsters within their spawn radius
      if (distance <= m.spawnRadiusMeters && distance < minDistance) {
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
              content: Text("Caught ${monster.monsterName} at $locName!", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF9C27B0),
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
    final distanceStr = _detectedMonsterDistance != null
        ? "${_detectedMonsterDistance!.toStringAsFixed(1)} m away"
        : "";

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Monster detected near you!",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00E5FF),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "${_detectedMonster!.monsterName} (${_detectedMonster!.monsterType}) - $distanceStr",
            style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            "Location - $locName",
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFFFF4081)],
                ),
              ),
              child: ElevatedButton.icon(
                onPressed: () => _performCatch(_detectedMonster!),
                icon: const Icon(Icons.catching_pokemon, color: Colors.white),
                label: const Text(
                  "Catch Monster",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
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
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Catch Monsters", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
                          options: const MapOptions(
                            initialCenter: LatLng(15.133103, 120.590585),
                            initialZoom: 16.0,
                            interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                              userAgentPackageName: "com.example.haumonsters",
                            ),
                            // Building zone circles (40m radius, blue)
                            CircleLayer(
                              circles: _buildings.map((b) => CircleMarker(
                                point: LatLng(b['lat'] as double, b['lng'] as double),
                                radius: 40,
                                useRadiusInMeter: true,
                                color: Colors.blue.withOpacity(0.10),
                                borderColor: Colors.blue.shade600,
                                borderStrokeWidth: 1.2,
                              )).toList(),
                            ),
                            // Building name markers (small icon + label)
                            MarkerLayer(
                              markers: _buildings.map((b) => Marker(
                                point: LatLng(b['lat'] as double, b['lng'] as double),
                                width: 56,
                                height: 36,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_city, color: Colors.blue.shade800, size: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade800.withOpacity(0.85),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        b['name'] as String,
                                        style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
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
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          labelText: "- Your Latitude -",
                          labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          border: const OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF), width: 2)),
                          prefixIcon: const Icon(Icons.my_location, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _lngController,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          labelText: "- Your Longitude -",
                          labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          border: const OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF), width: 2)),
                          prefixIcon: const Icon(Icons.explore, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFF4081).withOpacity(0.5)),
                        ),
                        child: Text(
                          "Current matched location: ${_matchedLocation?['location_name'] ?? 'None'}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_detecting)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: const Color(0xFF1E1E1E),
                            border: Border.all(color: Colors.grey.shade800),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: null,
                            icon: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                            ),
                            label: const Text("Detecting...", style: TextStyle(color: Colors.white70)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E5FF), Color(0xFF9C27B0)],
                            ),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _detectMonsters,
                            icon: const Icon(Icons.radar, color: Colors.white),
                            label: const Text(
                              "Detect Monsters",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            ),
                          ),
                        ),
                      _buildDetectionResult(),
                    ],
                  ),
                ),
    );
  }
}