import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/monster_model.dart';
import '../services/api_service.dart';

class MyMonstersPage extends StatefulWidget {
  const MyMonstersPage({super.key});

  @override
  State<MyMonstersPage> createState() => _MyMonstersPageState();
}

class _MyMonstersPageState extends State<MyMonstersPage> {
  List<Monster> _caughtMonsters = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCaughtMonsters();
  }

  Future<void> _fetchCaughtMonsters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final caughtList = prefs.getStringList('caught_monsters') ?? [];
      
      final allMonsters = await ApiService.getMonsters();
      
      if (mounted) {
        setState(() {
          _caughtMonsters = allMonsters
              .where((m) => caughtList.contains(m.monsterId.toString()))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Caught Monsters"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text("Error: $_errorMessage"))
              : _caughtMonsters.isEmpty
                  ? const Center(
                      child: Text(
                        "You haven't caught any monsters yet!\nGo back and catch some!",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: _caughtMonsters.length,
                      itemBuilder: (context, index) {
                        final monster = _caughtMonsters[index];
                        return Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: monster.pictureUrl != null && monster.pictureUrl!.isNotEmpty
                                      ? Image.network(
                                          monster.pictureUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stack) => const Icon(Icons.catching_pokemon, size: 50, color: Colors.purple),
                                        )
                                      : const Icon(Icons.catching_pokemon, size: 50, color: Colors.purple),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      monster.monsterName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      monster.monsterType,
                                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
