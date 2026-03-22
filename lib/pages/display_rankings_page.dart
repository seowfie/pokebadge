import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/player_ranking_model.dart';

class MonsterListPage extends StatefulWidget {
  const MonsterListPage({super.key});

  @override
  State<MonsterListPage> createState() => _MonsterListPageState();
}

class _MonsterListPageState extends State<MonsterListPage> {
  List<PlayerRanking> _rankings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRankings();
  }

  void _fetchRankings() async {
    try {
      final data = await ApiService.getTopHunters();
      if (data['success'] == true || data['status'] == 'success') {
        final List list = data['data'] ?? [];
        if (mounted) {
          setState(() {
            _rankings = list.map((e) => PlayerRanking.fromJson(e)).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = data['message']?.toString() ?? "Failed to load rankings";
            _isLoading = false;
          });
        }
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
      appBar: AppBar(title: const Text("Top 10 Monster Hunters")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text("Error: $_errorMessage"))
              : _rankings.isEmpty
                  ? const Center(child: Text("No rankings available yet."))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rankings.length,
                      itemBuilder: (context, index) {
                        final rank = _rankings[index];
                        final isTop3 = index < 3;
                        return Card(
                          elevation: isTop3 ? 4 : 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: index == 0 ? Colors.amber 
                                  : index == 1 ? Colors.grey[300] 
                                  : index == 2 ? Colors.orange[300] 
                                  : Colors.purple.withOpacity(0.5),
                              child: Text(
                                "#${index + 1}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            title: Text(rank.playerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            subtitle: Text("Monsters Caught: ${rank.totalCaught}"),
                            trailing: const Icon(Icons.star, color: Colors.amber),
                          ),
                        );
                      },
                    ),
    );
  }
}
