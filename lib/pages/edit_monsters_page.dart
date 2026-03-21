import 'package:flutter/material.dart';
import '../models/monster_model.dart';
import '../services/api_service.dart';
import 'edit_monster_page.dart';

class EditMonstersPage extends StatefulWidget {
  const EditMonstersPage({super.key});
  @override
  State<EditMonstersPage> createState() => _EditMonstersPageState();
}

class _EditMonstersPageState extends State<EditMonstersPage> {
  late Future<List<Monster>> _monstersFuture;

  @override
  void initState() {
    super.initState();
    _loadMonsters();
  }

  void _loadMonsters() {
    _monstersFuture = ApiService.getMonsters();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadMonsters();
    });
  }

  Future<void> _openEdit(Monster monster) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditMonsterPage(monster: monster)),
    );
    if (updated == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Monsters"),
      ),
      body: FutureBuilder<List<Monster>>(
        future: _monstersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}"),
            );
          }
          final monsters = snapshot.data ?? [];
          if (monsters.isEmpty) {
            return const Center(
              child: Text("No monsters found"),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              itemCount: monsters.length,
              itemBuilder: (context, index) {
                final monster = monsters[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: monster.pictureUrl != null &&
                            monster.pictureUrl!.isNotEmpty
                        ? CircleAvatar(
                            backgroundImage:
                                NetworkImage(monster.pictureUrl!),
                          )
                        : const CircleAvatar(
                            child: Icon(Icons.image_not_supported),
                          ),
                    title: Text(monster.monsterName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Type: ${monster.monsterType}"),
                        Text(
                          "Lat: ${monster.spawnLatitude.toStringAsFixed(7)}",
                        ),
                        Text(
                          "Lng: ${monster.spawnLongitude.toStringAsFixed(7)}",
                        ),
                        Text(
                          "Radius: ${monster.spawnRadiusMeters.toStringAsFixed(2)} m",
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openEdit(monster),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
