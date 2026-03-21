class PlayerRanking {
  final Map<String, dynamic> data;

  PlayerRanking(this.data);

  factory PlayerRanking.fromJson(Map<String, dynamic> json) {
    return PlayerRanking(json);
  }
}
