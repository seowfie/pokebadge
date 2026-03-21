import 'package:flutter/material.dart';
import '../models/monster_model.dart';
import '../services/api_service.dart';

class DeleteMonsterPage extends StatefulWidget {
  const DeleteMonsterPage({super.key});

  @override
  State<DeleteMonsterPage> createState() => _DeleteMonsterPageState();
}

class _DeleteMonsterPageState extends State<DeleteMonsterPage> {
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

  Future<void> _deleteMonster(Monster monster) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Delete ${monster.monsterName}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await ApiService.deleteMonster(
        monsterId: monster.monsterId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result["message"]?.toString() ?? "Done"),
        ),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Delete Monsters"),
      ),
      body: FutureBuilder<List<Monster>>(
        future: _monstersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final monsters = snapshot.data ?? [];
          if (monsters.isEmpty) {
            return const Center(child: Text("No monsters found"));
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
                            backgroundImage: NetworkImage(monster.pictureUrl!),
                          )
                        : const CircleAvatar(
                            child: Icon(Icons.image_not_supported),
                          ),
                    title: Text(monster.monsterName),
                    subtitle: Text(monster.monsterType),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteMonster(monster),
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
