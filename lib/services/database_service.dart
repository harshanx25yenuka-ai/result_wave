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
      version: 1,
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
            semester INTEGER
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

    // Load modules
    String modulesJson = await rootBundle.loadString('db/modules.json');
    List<dynamic> modules = jsonDecode(modulesJson);
    for (var module in modules) {
      await db.insert('modules', {
        'moduleId': module['Module_Id'],
        'moduleName': module['Module_Name'],
        'credits': module['Credits'],
        'courseIds': jsonEncode(module['Course_Id']),
        'semester': module['Semester'],
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
    return List.generate(maps.length, (i) {
      List<String> courseIds = jsonDecode(maps[i]['courseIds']).cast<String>();
      if (courseIds.contains(courseId)) {
        return Module(
          moduleId: maps[i]['moduleId'],
          moduleName: maps[i]['moduleName'],
          credits: maps[i]['credits'],
          courseIds: courseIds,
          semester: maps[i]['semester'],
        );
      }
      return null;
    }).where((module) => module != null).cast<Module>().toList();
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
