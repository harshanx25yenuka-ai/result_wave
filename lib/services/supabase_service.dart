import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/config/supabase.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isInitialized = false;
  String? _currentStudentId;

  Future<void> initSupabase() async {
    if (_isInitialized) return;

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      _isInitialized = true;
      print('Supabase initialized successfully');
    } catch (e) {
      print('Supabase initialization error: $e');
      rethrow;
    }
  }

  SupabaseClient get client {
    if (!_isInitialized) {
      throw Exception('Supabase not initialized. Call initSupabase() first.');
    }
    return Supabase.instance.client;
  }

  Future<void> setRLSContext(String studentId) async {
    _currentStudentId = studentId;
    try {
      await client.rpc(
        'set_current_student_id',
        params: {'student_id': studentId},
      );
    } catch (e) {
      print('Set RLS context error: $e');
    }
  }

  Future<void> clearRLSContext() async {
    _currentStudentId = null;
    try {
      await client.rpc('set_current_student_id', params: {'student_id': ''});
    } catch (e) {
      print('Clear RLS context error: $e');
    }
  }

  // =============================================
  // USER AUTHENTICATION METHODS
  // =============================================

  Future<Map<String, dynamic>> createUser({
    required String studentId,
    required String studentName,
    required String courseId,
    required String password,
    int? avatarId,
  }) async {
    try {
      final response = await client.rpc(
        'create_user_simple',
        params: {
          'p_student_id': studentId,
          'p_student_name': studentName,
          'p_course_id': courseId,
          'p_password': password,
          'p_avatar_id': avatarId,
        },
      );

      print('Create user response: $response');

      if (response != null && response['success'] == true) {
        return {
          'success': true,
          'message': response['message'],
          'user': response['user'],
        };
      } else {
        return {
          'success': false,
          'error': response?['error'] ?? 'Failed to create user',
        };
      }
    } catch (e) {
      print('Create user error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> loginUser({
    required String studentId,
    required String password,
  }) async {
    try {
      final response = await client.rpc(
        'verify_user_password_simple',
        params: {'p_student_id': studentId, 'p_password': password},
      );

      print('Login response: $response');

      if (response != null && response['success'] == true) {
        await setRLSContext(studentId);

        return {'success': true, 'user': response['user']};
      } else {
        return {
          'success': false,
          'error': response?['error'] ?? 'Invalid Student ID or Password',
        };
      }
    } catch (e) {
      print('Login error: $e');
      return {'success': false, 'error': 'Connection error. Please try again.'};
    }
  }

  Future<void> logout() async {
    await clearRLSContext();
  }

  Future<bool> userExists(String studentId) async {
    try {
      final response = await client
          .from(SupabaseConfig.usersTable)
          .select('student_id')
          .eq('student_id', studentId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('User exists error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getUserAvatar(String studentId) async {
    try {
      // First check if user exists
      final userExists = await this.userExists(studentId);

      if (!userExists) {
        print('User does not exist in Supabase: $studentId');
        return {
          'success': false,
          'avatarId': null,
          'error': 'User not found in Supabase',
        };
      }

      // Query the user table directly
      final response = await client
          .from(SupabaseConfig.usersTable)
          .select('avatar_id')
          .eq('student_id', studentId)
          .maybeSingle();

      print('Get user avatar response: $response');

      if (response != null) {
        final avatarId = response['avatar_id'];
        print('Avatar ID found: $avatarId');
        return {'success': true, 'avatarId': avatarId};
      } else {
        print('No user found for studentId: $studentId');
        return {'success': false, 'avatarId': null, 'error': 'User not found'};
      }
    } catch (e) {
      print('Get user avatar error: $e');
      return {'success': false, 'avatarId': null, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateUserAvatar({
    required String studentId,
    required int? avatarId,
  }) async {
    try {
      await setRLSContext(studentId);

      final response = await client.rpc(
        'update_user_avatar',
        params: {'p_student_id': studentId, 'p_avatar_id': avatarId},
      );

      print('Update user avatar response: $response');

      if (response != null && response['success'] == true) {
        return {
          'success': true,
          'message': 'Avatar updated successfully',
          'avatarId': avatarId,
        };
      } else {
        return {
          'success': false,
          'error': response?['message'] ?? 'Failed to update avatar',
        };
      }
    } catch (e) {
      print('Update user avatar error: $e');
      return {'success': false, 'error': e.toString()};
    } finally {
      await clearRLSContext();
    }
  }

  // =============================================
  // BACKUP METHODS
  // =============================================

  Future<Map<String, dynamic>> createBackup({
    required String studentId,
    required String studentName,
    required String courseId,
    required Map<String, dynamic> backupData,
  }) async {
    try {
      final backupSize = _calculateBackupSize(backupData);

      final response = await client.rpc(
        'upsert_student_backup',
        params: {
          'p_student_id': studentId,
          'p_student_name': studentName,
          'p_course_id': courseId,
          'p_data': backupData,
          'p_backup_version': '1.0',
        },
      );

      print('Create backup response: $response');

      if (response != null && response['success'] == true) {
        return {
          'success': true,
          'message': response['message'],
          'backupId': response['backup_id'],
          'isUpdate': response['is_update'] ?? false,
          'backupDate': DateTime.now(),
          'backupSize': backupSize,
        };
      } else {
        return {
          'success': false,
          'error': response?['message'] ?? 'Failed to create backup',
        };
      }
    } catch (e) {
      print('Create backup error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getBackups({String? studentId}) async {
    try {
      if (studentId != null) {
        final response = await client.rpc(
          'get_student_backup_history',
          params: {'p_student_id': studentId},
        );

        if (response == null) {
          return [];
        }

        if (response is List) {
          return List<Map<String, dynamic>>.from(response);
        }

        if (response is Map && response.containsKey('data')) {
          return List<Map<String, dynamic>>.from(response['data']);
        }

        return [];
      } else {
        final response = await client
            .from(SupabaseConfig.backupsTable)
            .select()
            .order('backup_date', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      print('Get backups error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getLatestBackup(String studentId) async {
    try {
      final response = await client.rpc(
        'get_latest_student_backup',
        params: {'p_student_id': studentId},
      );

      print('Get latest backup response: $response');

      if (response != null) {
        if (response is List && response.isNotEmpty) {
          return response[0];
        }
        if (response is Map && response.containsKey('id')) {
          return Map<String, dynamic>.from(response);
        }
      }
      return {};
    } catch (e) {
      print('Get latest backup error: $e');
      return {};
    }
  }

  Future<bool> restoreBackup(int backupId, Database localDb) async {
    try {
      final response = await client
          .from(SupabaseConfig.backupsTable)
          .select()
          .eq('id', backupId)
          .maybeSingle();

      if (response != null) {
        final backupData = response['data'] as Map<String, dynamic>;
        await _restoreToLocalDatabase(localDb, backupData);
        return true;
      }
      return false;
    } catch (e) {
      print('Restore backup error: $e');
      return false;
    }
  }

  Future<bool> restoreLatestBackup(String studentId, Database localDb) async {
    try {
      final latestBackup = await getLatestBackup(studentId);
      if (latestBackup.isNotEmpty && latestBackup.containsKey('id')) {
        return await restoreBackup(latestBackup['id'], localDb);
      }
      return false;
    } catch (e) {
      print('Restore latest backup error: $e');
      return false;
    }
  }

  Future<bool> deleteBackup(int backupId) async {
    try {
      final response = await client.rpc(
        'delete_student_backup',
        params: {'p_backup_id': backupId},
      );

      if (response != null && response['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      print('Delete backup error: $e');
      return false;
    }
  }

  Future<int> cleanupOldBackups(String studentId) async {
    try {
      final response = await client.rpc(
        'cleanup_old_backups',
        params: {'p_student_id': studentId},
      );
      return response ?? 0;
    } catch (e) {
      print('Cleanup old backups error: $e');
      return 0;
    }
  }

  // =============================================
  // STATISTICS METHODS
  // =============================================

  Future<Map<String, dynamic>> getBackupStatistics() async {
    try {
      final response = await client.rpc('get_backup_statistics');
      if (response != null && response.isNotEmpty) {
        return {
          'totalBackups': response[0]['total_backups'] ?? 0,
          'totalStudentsWithBackups':
              response[0]['total_students_with_backups'] ?? 0,
          'avgBackupSize': response[0]['avg_backup_size'] ?? 0,
          'totalStorageUsed': response[0]['total_storage_used'] ?? 0,
          'largestBackupSize': response[0]['largest_backup_size'] ?? 0,
          'smallestBackupSize': response[0]['smallest_backup_size'] ?? 0,
        };
      }
      return {};
    } catch (e) {
      print('Get backup statistics error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      final response = await client.rpc('get_user_statistics');
      if (response != null && response.isNotEmpty) {
        return {
          'totalUsers': response[0]['total_users'] ?? 0,
          'activeUsers': response[0]['active_users'] ?? 0,
          'inactiveUsers': response[0]['inactive_users'] ?? 0,
          'usersLast7Days': response[0]['users_last_7_days'] ?? 0,
          'usersLast30Days': response[0]['users_last_30_days'] ?? 0,
        };
      }
      return {};
    } catch (e) {
      print('Get user statistics error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getStudentBackupSummary(String studentId) async {
    try {
      final response = await client.rpc(
        'get_student_backup_summary',
        params: {'p_student_id': studentId},
      );

      if (response != null && response.isNotEmpty) {
        return {
          'totalBackups': response[0]['total_backups'] ?? 0,
          'latestBackupDate': response[0]['latest_backup_date'] != null
              ? DateTime.parse(response[0]['latest_backup_date'])
              : null,
          'totalStorageUsed': response[0]['total_storage_used'] ?? 0,
          'oldestBackupDate': response[0]['oldest_backup_date'] != null
              ? DateTime.parse(response[0]['oldest_backup_date'])
              : null,
        };
      }
      return {
        'totalBackups': 0,
        'latestBackupDate': null,
        'totalStorageUsed': 0,
        'oldestBackupDate': null,
      };
    } catch (e) {
      print('Get student backup summary error: $e');
      return {
        'totalBackups': 0,
        'latestBackupDate': null,
        'totalStorageUsed': 0,
        'oldestBackupDate': null,
      };
    }
  }

  // =============================================
  // HELPER METHODS
  // =============================================

  int _calculateBackupSize(Map<String, dynamic> data) {
    final jsonString = data.toString();
    return jsonString.length;
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _restoreToLocalDatabase(
    Database db,
    Map<String, dynamic> backupData,
  ) async {
    await db.transaction((txn) async {
      await txn.delete('students');
      await txn.delete('results');

      final students = backupData['students'] as List;
      for (var student in students) {
        await txn.insert('students', student);
      }

      final results = backupData['results'] as List;
      for (var result in results) {
        await txn.insert('results', result);
      }
    });
  }

  Future<Map<String, dynamic>> prepareBackupData(String studentId) async {
    final dbService = DatabaseService();
    final students = await dbService.getStudents();
    final student = students.firstWhere((s) => s.studentId == studentId);
    final results = await dbService.getResults();

    return {
      'students': students.map((s) => s.toMap()).toList(),
      'results': results.map((r) => r.toMap()).toList(),
      'student_id': studentId,
      'backup_version': '1.0',
      'backup_timestamp': DateTime.now().toIso8601String(),
      'student_name': student.studentName,
      'course_id': student.courseId,
    };
  }

  Future<bool> testConnection() async {
    try {
      final response = await client
          .from(SupabaseConfig.usersTable)
          .select()
          .limit(1);
      return true;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
}
