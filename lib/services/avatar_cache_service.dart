import 'package:shared_preferences/shared_preferences.dart';

class AvatarCacheService {
  static const String _avatarCacheKey = 'cached_avatar_';

  static Future<void> saveAvatar(String studentId, int? avatarId) async {
    final prefs = await SharedPreferences.getInstance();
    if (avatarId != null) {
      await prefs.setInt('$_avatarCacheKey$studentId', avatarId);
    } else {
      await prefs.remove('$_avatarCacheKey$studentId');
    }
    print('Avatar cached for $studentId: $avatarId');
  }

  static Future<int?> getAvatar(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_avatarCacheKey$studentId');
  }

  static Future<void> clearCache(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_avatarCacheKey$studentId');
  }

  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith(_avatarCacheKey)) {
        await prefs.remove(key);
      }
    }
  }
}
