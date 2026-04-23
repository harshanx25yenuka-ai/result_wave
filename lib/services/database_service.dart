import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/student.dart';
import '../models/course.dart';
import '../models/module.dart';
import '../models/grade.dart';
import '../models/result.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initializeDatabase();
    return _database!;
  }

  Future<Database> initializeDatabase() async {
    String path = join(await getDatabasesPath(), 'result_wave.db');
    return await openDatabase(
      path,
      version: 2, // Incremented version for schema change
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE students (
            studentId TEXT PRIMARY KEY,
            studentName TEXT,
            courseId TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE courses (
            courseId TEXT PRIMARY KEY,
            courseName TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE modules (
            moduleId TEXT PRIMARY KEY,
            moduleName TEXT,
            credits INTEGER,
            courseIds TEXT,
            semester INTEGER,
            gpaType TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE grades (
            grade TEXT PRIMARY KEY,
            gradePoint REAL,
            status TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE results (
            moduleId TEXT,
            grade TEXT,
            PRIMARY KEY (moduleId)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add gpaType column to modules table
          try {
            await db.execute(
              'ALTER TABLE modules ADD COLUMN gpaType TEXT DEFAULT "gpa"',
            );
          } catch (e) {
            // Column might already exist
          }
        }
      },
    );
  }

  Future<void> loadJsonData() async {
    final db = await database;

    // Load courses
    String coursesJson = await rootBundle.loadString('db/courses.json');
    List<dynamic> courses = jsonDecode(coursesJson);
    for (var course in courses) {
      await db.insert('courses', {
        'courseId': course['Course_Id'],
        'courseName': course['Course_Name'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Load grades
    String gradesJson = await rootBundle.loadString('db/grades.json');
    List<dynamic> grades = jsonDecode(gradesJson);
    for (var grade in grades) {
      await db.insert('grades', {
        'grade': grade['Grade'],
        'gradePoint': grade['Grade_Point'],
        'status': grade['Status'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Load modules with gpa_type
    String modulesJson = await rootBundle.loadString('db/modules.json');
    List<dynamic> modules = jsonDecode(modulesJson);
    for (var module in modules) {
      await db.insert('modules', {
        'moduleId': module['Module_Id'],
        'moduleName': module['Module_Name'],
        'credits': module['Credits'],
        'courseIds': jsonEncode(module['Course_Id']),
        'semester': module['Semester'],
        'gpaType': module['gpa_type'] ?? 'gpa',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> insertStudent(Student student) async {
    final db = await database;
    await db.insert(
      'students',
      student.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Student>> getStudents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('students');
    return List.generate(maps.length, (i) {
      return Student(
        studentId: maps[i]['studentId'],
        studentName: maps[i]['studentName'],
        courseId: maps[i]['courseId'],
      );
    });
  }

  Future<List<Course>> getCourses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('courses');
    return List.generate(maps.length, (i) {
      return Course(
        courseId: maps[i]['courseId'],
        courseName: maps[i]['courseName'],
      );
    });
  }

  Future<List<Module>> getModulesByCourse(String courseId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('modules');
    List<Module> modules = [];
    for (var map in maps) {
      List<String> courseIds = jsonDecode(map['courseIds']).cast<String>();
      if (courseIds.contains(courseId)) {
        modules.add(
          Module(
            moduleId: map['moduleId'],
            moduleName: map['moduleName'],
            credits: map['credits'],
            courseIds: courseIds,
            semester: map['semester'],
            gpaType: map['gpaType'] ?? 'gpa',
          ),
        );
      }
    }
    return modules;
  }

  Future<List<Grade>> getGrades() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('grades');
    return List.generate(maps.length, (i) {
      return Grade(
        grade: maps[i]['grade'],
        gradePoint: maps[i]['gradePoint'],
        status: maps[i]['status'],
      );
    });
  }

  Future<void> insertResult(Result result) async {
    final db = await database;
    await db.insert(
      'results',
      result.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Result>> getResults() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('results');
    return List.generate(maps.length, (i) {
      return Result(moduleId: maps[i]['moduleId'], grade: maps[i]['grade']);
    });
  }
}
