import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
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
  final MapController _mapController = MapController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
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
      final prefs = await SharedPreferences.getInstance();
      final caughtList = prefs.getStringList('caught_monsters') ?? [];
      
      if (mounted) {
        setState(() {
          _monsters = monsters.where((m) => !caughtList.contains(m.monsterId.toString())).toList();
          _isLoading = false;
        });
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

  Future<void> _triggerAudioAndTorch() async {
    final player = AudioPlayer();
    try {
      await player.play(AssetSource('sounds/alarm.ogg'));
    } catch (e) {
      debugPrint("Audio error: $e");
    }
    
    try {
      bool hasTorch = await TorchLight.isTorchAvailable();
      if (hasTorch) {
        await TorchLight.enableTorch();
      }
    } catch (e) {
      debugPrint("Torch error: $e");
    }

    await Future.delayed(const Duration(seconds: 5));

    try {
      await TorchLight.disableTorch();
    } catch (_) {}
    
    try {
      await player.stop();
      player.dispose();
    } catch (_) {}
  }

  void _performCatch(Monster monster) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("You caught ${monster.monsterName}!")),
    );
    setState(() {
      _monsters.removeWhere((m) => m.monsterId == monster.monsterId);
    });

    _triggerAudioAndTorch();

    try {
      final prefs = await SharedPreferences.getInstance();
      final playerId = prefs.getString('player_id') ?? '1';
      
      final caughtList = prefs.getStringList('caught_monsters') ?? [];
      if (!caughtList.contains(monster.monsterId.toString())) {
        caughtList.add(monster.monsterId.toString());
        await prefs.setStringList('caught_monsters', caughtList);
      }
      
      await ApiService.addMonsterCatch(
        playerId: playerId,
        monsterId: monster.monsterId.toString(),
        locationId: '1',
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
      );
    } catch (e) {
      debugPrint("Failed to save catch: $e");
    }
  }

  void _scanAndCatch() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid Latitude and Longitude.")),
      );
      return;
    }

    setState(() {
      _currentLocation = LatLng(lat, lng);
      _mapController.move(_currentLocation!, 15);
    });

    Monster? foundMonster;
    for (var m in _monsters) {
      final distance = Geolocator.distanceBetween(
        lat,
        lng,
        m.spawnLatitude,
        m.spawnLongitude,
      );
      if (distance <= m.spawnRadiusMeters) {
        foundMonster = m;
        break;
      }
    }

    if (foundMonster != null) {
      _performCatch(foundMonster);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No monsters detected at these coordinates.")),
      );
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
                _performCatch(monster);
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanAndCatch,
        icon: const Icon(Icons.radar),
        label: const Text("Scan Area"),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text("Error: $_errorMessage"))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _latController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: const InputDecoration(labelText: "Latitude", isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _lngController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: const InputDecoration(labelText: "Longitude", isDense: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: FlutterMap(
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
              ),
            ],
          ),
    );
  }
}