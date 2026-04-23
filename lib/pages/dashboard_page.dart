import 'package:flutter/material.dart';
import 'package:result_wave/models/module.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/models/grade.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/services/database_service.dart';

class DashboardPage extends StatefulWidget {
  final String studentId;

  DashboardPage({required this.studentId});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _numModules = 0;
  int _numSemesters = 0;
  Map<int, double> _semesterGPAs = {};
  double _courseGPA = 0.0;
  List<String> _suggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    Student student = (await DatabaseService().getStudents()).firstWhere(
      (s) => s.studentId == widget.studentId,
    );
    List<Module> modules = await DatabaseService().getModulesByCourse(
      student.courseId,
    );
    List<Result> results = await DatabaseService().getResults();
    List<Grade> grades = await DatabaseService().getGrades();

    Map<int, List<Module>> semesterModules = {};

    for (var module in modules) {
      semesterModules.putIfAbsent(module.semester, () => []).add(module);
    }

    Map<int, double> semesterGPAs = {};
    Map<int, int> semesterCredits = {};

    for (var semester in semesterModules.keys) {
      int totalCredits = 0;
      double totalPoints = 0.0;
      bool hasResults = false;

      for (var module in semesterModules[semester]!) {
        totalCredits += module.credits;
        var result = results.firstWhere(
          (r) => r.moduleId == module.moduleId,
          orElse: () => Result(moduleId: module.moduleId, grade: 'N/A'),
        );
        var grade = grades.firstWhere(
          (g) => g.grade == result.grade,
          orElse: () => Grade(grade: 'N/A', gradePoint: 0.0, status: ''),
        );
        if (result.grade != 'N/A') {
          totalPoints += grade.gradePoint * module.credits;
          hasResults = true;
        }
      }

      if (hasResults) {
        semesterGPAs[semester] = totalCredits > 0
            ? totalPoints / totalCredits
            : 0.0;
        semesterCredits[semester] = totalCredits;
      }
    }

    double totalSemesterPoints = 0.0;
    int totalSemesterCredits = 0;
    for (var semester in semesterGPAs.keys) {
      totalSemesterPoints +=
          semesterGPAs[semester]! * semesterCredits[semester]!;
      totalSemesterCredits += semesterCredits[semester]!;
    }
    double courseGPA = totalSemesterCredits > 0
        ? totalSemesterPoints / totalSemesterCredits
        : 0.0;

    List<String> suggestions = [];
    for (var semester in semesterGPAs.keys) {
      if (semesterGPAs[semester]! < 2.0) {
        suggestions.add(
          'Improve grades in Semester $semester to reach GPA of 2.0 or higher.',
        );
      }
    }
    if (courseGPA < 2.0) {
      suggestions.add(
        'Improve overall grades to reach Course GPA of 2.0 or higher.',
      );
    }
    for (var result in results) {
      if ([
        'F',
        'F(CA)',
        'F(ET)',
        'I',
        'I(ET)',
        'I(CA)',
      ].contains(result.grade)) {
        suggestions.add('Upgrade ${result.moduleId} to at least C.');
      }
    }

    setState(() {
      _numModules = modules.length;
      _numSemesters = semesterModules.keys.length;
      _semesterGPAs = semesterGPAs;
      _courseGPA = courseGPA;
      _suggestions = suggestions;
      _isLoading = false;
    });
  }

  Color _getGpaColor(double gpa) {
    if (gpa >= 3.0) return Colors.green;
    if (gpa >= 2.0) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Modules',
                            '$_numModules',
                            Icons.book_outlined,
                            Colors.blue,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Semesters',
                            '$_numSemesters',
                            Icons.calendar_today,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // GPA Card
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Overall GPA',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getGpaColor(
                                      _courseGPA,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _courseGPA.toStringAsFixed(2),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: _getGpaColor(_courseGPA),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            LinearProgressIndicator(
                              value: _courseGPA / 4.0,
                              backgroundColor: Colors.grey[200],
                              color: _getGpaColor(_courseGPA),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('0.0', style: TextStyle(fontSize: 12)),
                                Text('1.0', style: TextStyle(fontSize: 12)),
                                Text('2.0', style: TextStyle(fontSize: 12)),
                                Text('3.0', style: TextStyle(fontSize: 12)),
                                Text('4.0', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Semester GPAs
                    if (_semesterGPAs.isNotEmpty) ...[
                      Text(
                        'Semester Performance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      ..._semesterGPAs.entries.map((entry) {
                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Semester ${entry.key}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getGpaColor(
                                          entry.value,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'GPA: ${entry.value.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: _getGpaColor(entry.value),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: entry.value / 4.0,
                                  backgroundColor: Colors.grey[200],
                                  color: _getGpaColor(entry.value),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      SizedBox(height: 20),
                    ],

                    // Suggestions
                    Text(
                      'Suggestions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: _suggestions.isEmpty
                            ? Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Great job! You\'re performing well across all areas.',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: _suggestions.map((suggestion) {
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.trending_up,
                                          color: Colors.orange,
                                          size: 20,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            suggestion,
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
