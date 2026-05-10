import 'package:result_wave/models/student.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:result_wave/services/database_service.dart';

class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyStudentId = 'student_id';
  static const String _keyLoginTimestamp = 'login_timestamp';
  static const int _sessionDurationDays = 7;

  final DatabaseService _dbService = DatabaseService();

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    final loginTimestamp = prefs.getInt(_keyLoginTimestamp);

    if (!isLoggedIn || loginTimestamp == null) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final sessionDuration = now - loginTimestamp;
    final maxDuration = _sessionDurationDays * 24 * 60 * 60 * 1000;

    if (sessionDuration >= maxDuration) {
      await logout();
      return false;
    }

    return true;
  }

  Future<String?> getCurrentStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStudentId);
  }

  Future<void> setLoggedIn(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyStudentId, studentId);
    await prefs.setInt(
      _keyLoginTimestamp,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyStudentId);
    await prefs.remove(_keyLoginTimestamp);
  }

  Future<void> clearLoginData() async {
    await logout();
  }

  Future<Map<String, dynamic>> login(String studentId, String password) async {
    // Validate credentials from database
    final isValid = await _dbService.validateStudentCredentials(
      studentId,
      password,
    );

    if (isValid) {
      final student = await _dbService.getStudentById(studentId);
      await setLoggedIn(studentId);
      return {'success': true, 'student': student};
    } else {
      // Check if student exists but password is wrong
      final existingStudent = await _dbService.getStudentById(studentId);
      if (existingStudent != null) {
        return {'success': false, 'error': 'Incorrect password'};
      } else {
        return {'success': false, 'error': 'Student ID not found'};
      }
    }
  }

  Future<bool> registerStudent({
    required String studentId,
    required String studentName,
    required String courseId,
    required String password,
  }) async {
    // Check if student already exists
    final existingStudent = await _dbService.getStudentById(studentId);
    if (existingStudent != null) {
      return false;
    }

    // Create new student
    final student = Student(
      studentId: studentId,
      studentName: studentName,
      courseId: courseId,
      password: password,
    );

    await _dbService.insertStudent(student);
    return true;
  }
}
