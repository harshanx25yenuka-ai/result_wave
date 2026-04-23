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
  int _numGpaModules = 0;
  int _numNonGpaModules = 0;
  int _numSemesters = 0;
  Map<int, double> _semesterGPAs = {};
  Map<int, int> _semesterGpaCredits = {};
  Map<int, int> _semesterPassedNonGpaModules = {};
  Map<int, int> _semesterTotalNonGpaModules = {};
  double _courseGPA = 0.0;
  List<String> _suggestions = [];
  bool _isDegreeEligible = false;
  String _degreeStatus = '';
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

    // Separate GPA and Non-GPA modules
    List<Module> gpaModules = modules.where((m) => m.isGpaModule).toList();
    List<Module> nonGpaModules = modules
        .where((m) => m.isNonGpaModule)
        .toList();

    Map<int, List<Module>> semesterGpaModules = {};
    Map<int, List<Module>> semesterNonGpaModules = {};

    for (var module in gpaModules) {
      semesterGpaModules.putIfAbsent(module.semester, () => []).add(module);
    }
    for (var module in nonGpaModules) {
      semesterNonGpaModules.putIfAbsent(module.semester, () => []).add(module);
    }

    // Calculate Semester GPAs using only GPA modules
    Map<int, double> semesterGPAs = {};
    Map<int, int> semesterGpaCredits = {};

    for (var semester in semesterGpaModules.keys) {
      int totalCredits = 0;
      double totalPoints = 0.0;
      bool hasResults = false;

      for (var module in semesterGpaModules[semester]!) {
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

      if (hasResults && totalCredits > 0) {
        semesterGPAs[semester] = totalPoints / totalCredits;
        semesterGpaCredits[semester] = totalCredits;
      }
    }

    // Check Non-GPA module pass status for each semester
    Map<int, int> semesterPassedNonGpa = {};
    Map<int, int> semesterTotalNonGpa = {};

    for (var semester in semesterNonGpaModules.keys) {
      int passedCount = 0;
      int totalCount = semesterNonGpaModules[semester]!.length;

      for (var module in semesterNonGpaModules[semester]!) {
        var result = results.firstWhere(
          (r) => r.moduleId == module.moduleId,
          orElse: () => Result(moduleId: module.moduleId, grade: 'N/A'),
        );
        // Non-GPA modules need at least 'C' grade to pass
        if (_isNonGpaPassed(result.grade)) {
          passedCount++;
        }
      }

      semesterPassedNonGpa[semester] = passedCount;
      semesterTotalNonGpa[semester] = totalCount;
    }

    // Calculate Overall Course GPA (using only GPA modules)
    double totalCoursePoints = 0.0;
    int totalCourseCredits = 0;
    for (var semester in semesterGPAs.keys) {
      totalCoursePoints +=
          semesterGPAs[semester]! * semesterGpaCredits[semester]!;
      totalCourseCredits += semesterGpaCredits[semester]!;
    }
    double courseGPA = totalCourseCredits > 0
        ? totalCoursePoints / totalCourseCredits
        : 0.0;

    // Check Degree Eligibility
    bool allNonGpaPassed = true;
    for (var semester in semesterNonGpaModules.keys) {
      if (semesterPassedNonGpa[semester] != semesterTotalNonGpa[semester]) {
        allNonGpaPassed = false;
        break;
      }
    }

    bool gpaConditionMet = courseGPA >= 2.0;
    bool isEligible = gpaConditionMet && allNonGpaPassed;

    String degreeStatus = '';
    if (isEligible) {
      degreeStatus = 'Eligible for Degree';
    } else {
      if (!gpaConditionMet && !allNonGpaPassed) {
        degreeStatus = 'Not Eligible: Low GPA & Failed Non-GPA Modules';
      } else if (!gpaConditionMet) {
        degreeStatus = 'Not Eligible: Overall GPA below 2.0';
      } else {
        degreeStatus =
            'Not Eligible: Some Non-GPA modules not passed (Need at least C)';
      }
    }

    // Generate suggestions
    List<String> suggestions = [];

    // GPA related suggestions
    for (var semester in semesterGPAs.keys) {
      if (semesterGPAs[semester]! < 2.0) {
        suggestions.add(
          'Improve grades in Semester $semester GPA modules to reach GPA of 2.0 or higher.',
        );
      }
    }
    if (courseGPA < 2.0) {
      suggestions.add(
        'Your overall GPA is ${courseGPA.toStringAsFixed(2)}. You need a minimum of 2.0 to be eligible for the degree.',
      );
    }

    // Non-GPA module related suggestions
    for (var semester in semesterNonGpaModules.keys) {
      int failedCount =
          (semesterTotalNonGpa[semester] ?? 0) -
          (semesterPassedNonGpa[semester] ?? 0);
      if (failedCount > 0) {
        suggestions.add(
          'You have $failedCount non-GPA module(s) in Semester $semester that need at least a C grade.',
        );
      }
    }

    // Failed module suggestions
    for (var result in results) {
      if ([
        'F',
        'F(CA)',
        'F(ET)',
        'I',
        'I(ET)',
        'I(CA)',
      ].contains(result.grade)) {
        var module = modules.firstWhere(
          (m) => m.moduleId == result.moduleId,
          orElse: () => Module(
            moduleId: result.moduleId,
            moduleName: '',
            credits: 0,
            courseIds: [],
            semester: 0,
            gpaType: 'gpa',
          ),
        );
        String moduleType = module.isGpaModule
            ? 'GPA module'
            : 'non-GPA module';
        suggestions.add(
          'Upgrade ${result.moduleId} ($moduleType) to at least C.',
        );
      }
    }

    // Calculate number of semesters
    Set<int> allSemesters = {};
    allSemesters.addAll(semesterGpaModules.keys);
    allSemesters.addAll(semesterNonGpaModules.keys);

    setState(() {
      _numModules = modules.length;
      _numGpaModules = gpaModules.length;
      _numNonGpaModules = nonGpaModules.length;
      _numSemesters = allSemesters.length;
      _semesterGPAs = semesterGPAs;
      _semesterGpaCredits = semesterGpaCredits;
      _semesterPassedNonGpaModules = semesterPassedNonGpa;
      _semesterTotalNonGpaModules = semesterTotalNonGpa;
      _courseGPA = courseGPA;
      _suggestions = suggestions;
      _isDegreeEligible = isEligible;
      _degreeStatus = degreeStatus;
      _isLoading = false;
    });
  }

  bool _isNonGpaPassed(String grade) {
    // Non-GPA modules need at least 'C' to pass
    if (grade == 'N/A') return false;
    if (['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C'].contains(grade)) {
      return true;
    }
    return false;
  }

  bool _isGpaModulePassed(String grade) {
    // GPA modules pass with any grade above F
    if (grade == 'N/A') return false;
    if (['F', 'F(CA)', 'F(ET)', 'I', 'I(ET)', 'I(CA)'].contains(grade)) {
      return false;
    }
    return true;
  }

  Color _getGpaColor(double gpa) {
    if (gpa >= 3.0) return Colors.green;
    if (gpa >= 2.0) return Colors.orange;
    return Colors.red;
  }

  Color _getDegreeStatusColor() {
    if (_isDegreeEligible) return Colors.green;
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
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'GPA Modules',
                            '$_numGpaModules',
                            Icons.auto_graph,
                            Colors.green,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Non-GPA Modules',
                            '$_numNonGpaModules',
                            Icons.school_outlined,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // Degree Status Card
                    Card(
                      color: _getDegreeStatusColor().withOpacity(0.1),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              _isDegreeEligible
                                  ? Icons.verified
                                  : Icons.warning_amber,
                              color: _getDegreeStatusColor(),
                              size: 32,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Degree Status',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getDegreeStatusColor(),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _degreeStatus,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _getDegreeStatusColor(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Overall GPA',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '(Based on GPA modules only)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
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
                            SizedBox(height: 20),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Minimum GPA required: 2.00',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  if (_courseGPA >= 2.0)
                                    Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: Colors.green,
                                    )
                                  else
                                    Icon(
                                      Icons.cancel,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Semester Performance
                    if (_semesterGPAs.isNotEmpty) ...[
                      Text(
                        'Semester Performance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      ...(_semesterGPAs.keys.toList()..sort()).map((semester) {
                        int gpaCredits = _semesterGpaCredits[semester] ?? 0;
                        int passedNonGpa =
                            _semesterPassedNonGpaModules[semester] ?? 0;
                        int totalNonGpa =
                            _semesterTotalNonGpaModules[semester] ?? 0;
                        bool nonGpaComplete =
                            totalNonGpa == 0 || passedNonGpa == totalNonGpa;

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
                                      'Semester $semester',
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
                                          _semesterGPAs[semester]!,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'GPA: ${_semesterGPAs[semester]!.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: _getGpaColor(
                                            _semesterGPAs[semester]!,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: _semesterGPAs[semester]! / 4.0,
                                  backgroundColor: Colors.grey[200],
                                  color: _getGpaColor(_semesterGPAs[semester]!),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                if (totalNonGpa > 0) ...[
                                  SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        nonGpaComplete
                                            ? Icons.check_circle
                                            : Icons.warning,
                                        size: 14,
                                        color: nonGpaComplete
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Non-GPA Modules: $passedNonGpa/$totalNonGpa passed',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: nonGpaComplete
                                              ? Colors.green[700]
                                              : Colors.orange[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
                                      'Great job! You\'re on track to complete your degree. Keep up the good work!',
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
