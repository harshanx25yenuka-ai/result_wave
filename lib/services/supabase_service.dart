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
    await SupabaseConfig.setCurrentStudentId(studentId);
  }

  Future<void> clearRLSContext() async {
    _currentStudentId = null;
    await SupabaseConfig.clearCurrentStudentId();
  }

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

      if (response != null) {
        return {
          'success': response['success'] ?? false,
          'message': response['message'],
          'user': response['user'],
        };
      } else {
        return {'success': false, 'error': 'Failed to create user'};
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
      final response = await client
          .from(SupabaseConfig.usersTable)
          .select('avatar_id')
          .eq('student_id', studentId)
          .maybeSingle();

      if (response != null) {
        return {'success': true, 'avatarId': response['avatar_id']};
      }
      return {'success': false, 'avatarId': null};
    } catch (e) {
      return {'success': false, 'avatarId': null, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateUserAvatar({
    required String studentId,
    required int? avatarId,
  }) async {
    try {
      final response = await client
          .from(SupabaseConfig.usersTable)
          .update({
            'avatar_id': avatarId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('student_id', studentId)
          .select();

      if (response.isNotEmpty) {
        return {
          'success': true,
          'message': 'Avatar updated successfully',
          'avatarId': avatarId,
        };
      }
      return {'success': false, 'error': 'Failed to update avatar'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Backup Methods
  Future<Map<String, dynamic>> createBackup({
    required String studentId,
    required String studentName,
    required String courseId,
    required Map<String, dynamic> backupData,
  }) async {
    try {
      final backupSize = _calculateBackupSize(backupData);

      final existingBackup = await client
          .from(SupabaseConfig.backupsTable)
          .select()
          .eq('student_id', studentId)
          .maybeSingle();

      if (existingBackup != null) {
        final response = await client
            .from(SupabaseConfig.backupsTable)
            .update({
              'student_name': studentName,
              'course_id': courseId,
              'backup_date': DateTime.now().toIso8601String(),
              'backup_size': backupSize,
              'data': backupData,
              'backup_version': '1.0',
            })
            .eq('student_id', studentId)
            .select();

        if (response.isNotEmpty) {
          return {
            'success': true,
            'message': 'Backup updated successfully',
            'backupId': response[0]['id'],
            'isUpdate': true,
            'backupDate': DateTime.now(),
            'backupSize': backupSize,
          };
        }
      } else {
        final response = await client.from(SupabaseConfig.backupsTable).insert({
          'student_id': studentId,
          'student_name': studentName,
          'course_id': courseId,
          'backup_date': DateTime.now().toIso8601String(),
          'backup_size': backupSize,
          'data': backupData,
          'backup_version': '1.0',
        }).select();

        if (response.isNotEmpty) {
          return {
            'success': true,
            'message': 'Backup created successfully',
            'backupId': response[0]['id'],
            'isUpdate': false,
            'backupDate': DateTime.now(),
            'backupSize': backupSize,
          };
        }
      }

      return {'success': false, 'error': 'Failed to create backup'};
    } catch (e) {
      print('Create backup error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getBackups({String? studentId}) async {
    try {
      if (studentId != null) {
        final response = await client
            .from(SupabaseConfig.backupsTable)
            .select()
            .eq('student_id', studentId)
            .order('backup_date', ascending: false);
        return response;
      } else {
        final response = await client
            .from(SupabaseConfig.backupsTable)
            .select()
            .order('backup_date', ascending: false);
        return response;
      }
    } catch (e) {
      print('Get backups error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getLatestBackup(String studentId) async {
    try {
      final response = await client
          .from(SupabaseConfig.backupsTable)
          .select()
          .eq('student_id', studentId)
          .order('backup_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return response;
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
      if (latestBackup.isNotEmpty) {
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
      await client
          .from(SupabaseConfig.backupsTable)
          .delete()
          .eq('id', backupId);
      return true;
    } catch (e) {
      print('Delete backup error: $e');
      return false;
    }
  }

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
