import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../models/monster_model.dart';
//import '../models/player_ranking_model.dart';

class ApiService {
  static const String baseUrl = "http://3.0.90.110";

  // GET TOP 10 MONSTER HUNTERS
  static Future<Map<String, dynamic>> getTopHunters() async {
    final response = await http.get(
      Uri.parse("$baseUrl/top_monster_hunters.php"),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addMonster({
    required String monsterName,
    required String monsterType,
    required double spawnLatitude,
    required double spawnLongitude,
    required double spawnRadiusMeters,
    String? pictureUrl,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/add_monster.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "monster_name": monsterName,
        "monster_type": monsterType,
        "spawn_latitude": spawnLatitude,
        "spawn_longitude": spawnLongitude,
        "spawn_radius_meters": spawnRadiusMeters,
        "picture_url": pictureUrl ?? "",
      }),
    );

    if (response.body.isEmpty) {
      throw Exception("Server returned empty response");
    }

    final data = jsonDecode(response.body);
    return data;
  }

  static Future<List<Monster>> getMonsters() async {
    final response = await http.get(
      Uri.parse("$baseUrl/get_monsters.php"),
    );

    if (response.body.isEmpty) {
      throw Exception("Server returned empty response");
    }

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (data["success"] == true) {
      final List list = data["data"] ?? [];
      return list.map((e) => Monster.fromJson(e)).toList();
    } else {
      throw Exception(data["message"] ?? "Failed to load monsters");
    }
  }

  static Future<String?> uploadMonsterImage(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/upload_monster_image.php"),
    );

    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print("STATUS CODE: ${response.statusCode}");
    print("RESPONSE BODY: ${response.body}");

    if (response.body.isEmpty) {
      throw Exception("Server returned empty response");
    }

    final trimmed = response.body.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
      throw Exception("Server did not return JSON. Response: ${response.body}");
    }

    final data = jsonDecode(trimmed);

    if (data["success"] == true) {
      return data["image_url"];
    } else {
      throw Exception(data["message"] ?? "Image upload failed");
    }
  }

  static Future<Map<String, dynamic>> updateMonster({
    required int monsterId,
    required String monsterName,
    required String monsterType,
    required double spawnLatitude,
    required double spawnLongitude,
    required double spawnRadiusMeters,
    String? pictureUrl,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/update_monster.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "monster_id": monsterId,
        "monster_name": monsterName,
        "monster_type": monsterType,
        "spawn_latitude": spawnLatitude,
        "spawn_longitude": spawnLongitude,
        "spawn_radius_meters": spawnRadiusMeters,
        "picture_url": pictureUrl ?? "",
      }),
    );

    if (response.body.isEmpty) {
      throw Exception("Server returned empty response");
    }

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteMonster({
    required int monsterId,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/delete_monster.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "monster_id": monsterId,
      }),
    );

    if (response.body.isEmpty) {
      throw Exception("Server returned empty response");
    }

    return jsonDecode(response.body);
  }

  // REGISTER
  static Future<Map<String, dynamic>> register(
      String playerName, String username, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/register.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "player_name": playerName,
        "username": username,
        "password": password,
      }),
    );

    return jsonDecode(response.body);
  }

  // LOGIN
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": username,
        "password": password,
      }),
    );

    return jsonDecode(response.body);
  }

  // ADD MONSTER CATCH
  static Future<Map<String, dynamic>> addMonsterCatch({
    required String playerId,
    required String monsterId,
    required String locationId,
    required double latitude,
    required double longitude,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/add_monster_catch.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "player_id": playerId,
        "monster_id": monsterId,
        "location_id": locationId,
        "latitude": latitude,
        "longitude": longitude,
      }),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addLocation({
    required String locationName,
    required double centerLatitude,
    required double centerLongitude,
    required double radiusMeters,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add_location.php"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "location_name": locationName,
          "center_latitude": centerLatitude,
          "center_longitude": centerLongitude,
          "radius_meters": radiusMeters,
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        return {
          "success": false,
          "message": "Server error: ${response.statusCode}",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": "Connection failed",
        "error": e.toString(),
      };
    }
  }

  static Future<List<Map<String, dynamic>>> getLocations() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_locations.php"));

      print("GET LOCATIONS STATUS: ${response.statusCode}");
      print("GET LOCATIONS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["success"] == true) {
          return List<Map<String, dynamic>>.from(data["locations"]);
        }
      }

      return [];
    } catch (e) {
      print("GET LOCATIONS ERROR: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>> catchMonster({
    required int playerId,
    required int monsterId,
    required int locationId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add_monster_catch.php"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "player_id": playerId,
          "monster_id": monsterId,
          "location_id": locationId,
          "latitude": latitude,
          "longitude": longitude,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        "success": false,
        "message": "Connection failed",
        "error": e.toString(),
      };
    }
  }
}
