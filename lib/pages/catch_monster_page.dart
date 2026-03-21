import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/monster_model.dart';
import '../services/api_service.dart';

class CatchMonsterPage extends StatefulWidget {
  const CatchMonsterPage({super.key});

  @override
  State<CatchMonsterPage> createState() => _CatchMonsterPageState();
}

class _CatchMonsterPageState extends State<CatchMonsterPage> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  List<Monster> _monsters = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
      
      final monsters = await ApiService.getMonsters();
      
      if (mounted) {
        setState(() {
          _monsters = monsters;
          _isLoading = false;
        });
      }

      await _getLocation();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    if (mounted) {
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });
      _mapController.move(_currentLocation!, 16.0);
    }
  }

  void _attemptCatch(Monster monster) {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fetching your location... Please wait")),
      );
      return;
    }
    
    final distance = Geolocator.distanceBetween(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      monster.spawnLatitude,
      monster.spawnLongitude,
    );

    if (distance <= monster.spawnRadiusMeters) {
      _showCatchDialog(monster, true, distance);
    } else {
      _showCatchDialog(monster, false, distance);
    }
  }

  void _showCatchDialog(Monster monster, bool inRange, double distance) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(inRange ? "Catch ${monster.monsterName}!" : "Too far away!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (monster.pictureUrl != null && monster.pictureUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Image.network(
                  monster.pictureUrl!, 
                  width: 100, 
                  height: 100, 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const Icon(Icons.catching_pokemon, size: 80, color: Colors.blue),
                ),
              )
            else
              const Icon(Icons.catching_pokemon, size: 80, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              inRange 
                ? "You are close enough to catch this ${monster.monsterType} monster! (Distance: ${distance.toStringAsFixed(1)}m)"
                : "You are ${distance.toStringAsFixed(1)} meters away.\nYou need to be within ${monster.spawnRadiusMeters.toStringAsFixed(1)} meters to catch it!",
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
          if (inRange)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("You caught ${monster.monsterName}!")),
                );
                setState(() {
                  _monsters.removeWhere((m) => m.monsterId == monster.monsterId);
                });
              },
              child: const Text("Throw Pokeball"),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Catch Monsters"),
        actions: [
          if (_currentLocation != null)
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: () => _mapController.move(_currentLocation!, 16),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeData,
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text("Error: $_errorMessage"))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? const LatLng(15.144985, 120.588702),
                    initialZoom: 15.0,
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
                          width: 60,
                          height: 60,
                          child: GestureDetector(
                            onTap: () => _attemptCatch(m),
                            child: m.pictureUrl != null && m.pictureUrl!.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      m.pictureUrl!, 
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) => const Icon(Icons.catching_pokemon, color: Colors.red, size: 40),
                                    )
                                  )
                                : const Icon(Icons.catching_pokemon, color: Colors.blueAccent, size: 40),
                          ),
                        )).toList(),
                      ),
                    if (_currentLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation!,
                            width: 50,
                            height: 50,
                            child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 50),
                          )
                        ],
                      ),
                  ],
                ),
    );
  }
}