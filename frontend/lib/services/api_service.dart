import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiService {
  static const String baseUrl = "http://localhost:8001";
  static const String wsUrl = "ws://localhost:8001";

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        body: {
          'username': username,
          'password': password,
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Login error: $e");
    }
    return null;
  }

  Future<List<dynamic>> getGoals() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/goals/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Get goals error: $e");
    }
    return [];
  }

  Future<List<dynamic>> getTodaysTasks() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tasks/today'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Get tasks error: $e");
    }
    return [];
  }

  WebSocketChannel getChatChannel({int? goalId, int? sessionId}) {
    // Note: In a real app, we'd handle the token async before connecting
    // For now, we'll assume the token is available or passed in.
    // This is a bit tricky with synchronous channel creation.
    return WebSocketChannel.connect(
      Uri.parse('$wsUrl/ws/chat?token=TOKEN_PLACEHOLDER&goal_id=${goalId ?? ""}&session_id=${sessionId ?? ""}'),
    );
  }

  Future<List<dynamic>> getChatSessions() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/sessions'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Get chat sessions error: $e");
    }
    return [];
  }

  Future<Map<String, dynamic>?> getChatHistory(int sessionId) async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/sessions/$sessionId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Get chat history error: $e");
    }
    return null;
  }
}
