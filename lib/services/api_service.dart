import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Default server IP - Change this to your laptop's IP
  static const String serverIp = '192.168.43.214';
  static const String serverPort = '8080';
  static const String baseUrl = 'http://$serverIp:$serverPort/api';

  Future<Map<String, dynamic>> register({
    required String studentId,
    required String studentName,
    required String courseId,
    required String password,
    int? avatarId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'studentId': studentId,
              'studentName': studentName,
              'courseId': courseId,
              'password': password,
              'avatarId': avatarId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String studentId,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'studentId': studentId, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
        };
      } else {
        return {'success': false, 'error': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getUser(String studentId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/auth/user/$studentId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
        };
      } else {
        return {'success': false, 'error': data['message'] ?? 'User not found'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> updateAvatar(
    String studentId,
    int avatarId,
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse(
              '$baseUrl/auth/user/$studentId/avatar?avatarId=$avatarId',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Avatar updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to update avatar',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> deactivateUser(String studentId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/auth/user/$studentId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Deactivation failed',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/auth/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Connected to server'};
      } else {
        return {
          'success': false,
          'message': 'Server returned status ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to server: ${e.toString()}',
      };
    }
  }
}
