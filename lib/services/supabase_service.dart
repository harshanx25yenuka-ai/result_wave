import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:result_wave/services/database_service.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String tableName = 'student_backups';

  Future<void> initSupabase() async {
    await Supabase.initialize(
      url:
          'https://qeteyfiutignsgjchowj.supabase.co', // Replace with your Supabase URL
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFldGV5Zml1dGlnbnNnamNob3dqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyMTUxMzEsImV4cCI6MjA5Mjc5MTEzMX0.PdocPQeBGBw2Pt4hILZWPxYmqy3yx6f2HOogvdgwlb0', // Replace with your Supabase anon key
    );
  }

  SupabaseClient get client => Supabase.instance.client;

  // Create backup table if not exists (run this once in Supabase SQL editor)
  /*
  CREATE TABLE IF NOT EXISTS student_backups (
    id SERIAL PRIMARY KEY,
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    course_id TEXT NOT NULL,
    backup_date TIMESTAMP NOT NULL,
    backup_size BIGINT NOT NULL,
    data JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
  );
  */

  Future<Map<String, dynamic>> createBackup({
    required String studentId,
    required String studentName,
    required String courseId,
    required Map<String, dynamic> backupData,
  }) async {
    try {
      final backupSize = _calculateBackupSize(backupData);
      final backupDate = DateTime.now();

      final response = await client.from(tableName).insert({
        'student_id': studentId,
        'student_name': studentName,
        'course_id': courseId,
        'backup_date': backupDate.toIso8601String(),
        'backup_size': backupSize,
        'data': backupData,
      }).select();

      return {
        'success': true,
        'data': response.isNotEmpty ? response[0] : null,
        'backupDate': backupDate,
        'backupSize': backupSize,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getBackups({String? studentId}) async {
    try {
      var query = client.from(tableName).select();
      if (studentId != null) {
        query = query.eq('student_id', studentId);
      }
      final response = await query.order('backup_date', ascending: false);
      return response;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getLatestBackup(String studentId) async {
    try {
      final response = await client
          .from(tableName)
          .select()
          .eq('student_id', studentId)
          .order('backup_date', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        return response[0];
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<bool> restoreBackup(int backupId, Database localDb) async {
    try {
      final response = await client
          .from(tableName)
          .select()
          .eq('id', backupId)
          .single();

      if (response != null) {
        final backupData = response['data'] as Map<String, dynamic>;
        await _restoreToLocalDatabase(localDb, backupData);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteBackup(int backupId) async {
    try {
      await client.from(tableName).delete().eq('id', backupId);
      return true;
    } catch (e) {
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
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _restoreToLocalDatabase(
    Database db,
    Map<String, dynamic> backupData,
  ) async {
    await db.transaction((txn) async {
      // Clear existing data
      await txn.delete('students');
      await txn.delete('results');

      // Restore students
      final students = backupData['students'] as List;
      for (var student in students) {
        await txn.insert('students', student);
      }

      // Restore results
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
    };
  }
}
