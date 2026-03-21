import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/monster_model.dart';
import '../services/api_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
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
      _mapController.move(_currentLocation!, 15.0);
    }
  }

  void _showMonsterDetails(Monster monster) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(monster.monsterName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (monster.pictureUrl != null && monster.pictureUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  monster.pictureUrl!, 
                  width: double.infinity, 
                  height: 150, 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const Icon(Icons.catching_pokemon, size: 80, color: Colors.blue),
                ),
              )
            else
              const Icon(Icons.catching_pokemon, size: 80, color: Colors.blue),
            const SizedBox(height: 16),
            Text("Type: ${monster.monsterType}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text("Lat: ${monster.spawnLatitude.toStringAsFixed(6)}"),
            Text("Lng: ${monster.spawnLongitude.toStringAsFixed(6)}"),
            Text("Radius: ${monster.spawnRadiusMeters.toStringAsFixed(1)} meters"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monster Map"),
        actions: [
          if (_currentLocation != null)
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: () => _mapController.move(_currentLocation!, 15),
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
                    initialZoom: 14.0,
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
                          color: Colors.blue.withOpacity(0.2),
                          borderColor: Colors.blue,
                          borderStrokeWidth: 2,
                        )).toList(),
                      ),
                    if (_monsters.isNotEmpty)
                      MarkerLayer(
                        markers: _monsters.map((m) => Marker(
                          point: LatLng(m.spawnLatitude, m.spawnLongitude),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => _showMonsterDetails(m),
                            child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
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
                            child: const Icon(Icons.person_pin_circle, color: Colors.green, size: 50),
                          )
                        ],
                      ),
                  ],
                ),
    );
  }
}
