import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyStudentId = 'student_id';
  static const String _keyLoginTimestamp = 'login_timestamp';
  static const int _sessionDurationDays = 7;

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    final loginTimestamp = prefs.getInt(_keyLoginTimestamp);

    if (!isLoggedIn || loginTimestamp == null) {
      return false;
    }

    // Check if session has expired (7 days)
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
}
