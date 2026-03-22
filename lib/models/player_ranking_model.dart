class PlayerRanking {
  final String playerName;
  final int totalCaught;
  final Map<String, dynamic> data;

  PlayerRanking({
    required this.playerName,
    required this.totalCaught,
    required this.data,
  });

  factory PlayerRanking.fromJson(Map<String, dynamic> json) {
    return PlayerRanking(
      playerName: json['player_name'] ?? json['username'] ?? 'Unknown Hunter',
      totalCaught: int.tryParse(json['total_catches']?.toString() ?? '0') ?? 0,
      data: json,
    );
  }
}
