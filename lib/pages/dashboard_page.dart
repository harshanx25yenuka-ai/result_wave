import 'package:flutter/material.dart';
import 'package:result_wave/models/module.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/models/grade.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/models/course.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/utils/constants.dart';
import 'package:result_wave/utils/animations.dart';
import 'package:result_wave/widgets/glass_card.dart';
import 'package:result_wave/widgets/insight_card.dart';
import 'package:result_wave/widgets/gauge_chart.dart';

class DashboardPage extends StatefulWidget {
  final String studentId;

  const DashboardPage({Key? key, required this.studentId}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

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
  String _studentName = '';
  String _courseName = '';

  List<Map<String, dynamic>> _failedModules = [];
  List<Map<String, dynamic>> _incompleteModules = [];

  // Collapse states
  bool _isFailedModulesExpanded = false;
  bool _isIncompleteModulesExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    Student student = (await DatabaseService().getStudents()).firstWhere(
      (s) => s.studentId == widget.studentId,
    );
    List<Module> modules = await DatabaseService().getModulesByCourse(
      student.courseId,
    );
    List<Result> results = await DatabaseService().getResults();
    List<Grade> grades = await DatabaseService().getGrades();
    List<Course> courses = await DatabaseService().getCourses();

    _studentName = student.studentName;
    _courseName = courses
        .firstWhere((c) => c.courseId == student.courseId)
        .courseName;

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
        if (_isNonGpaPassed(result.grade)) passedCount++;
      }

      semesterPassedNonGpa[semester] = passedCount;
      semesterTotalNonGpa[semester] = totalCount;
    }

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

    bool allNonGpaPassed = true;
    for (var semester in semesterNonGpaModules.keys) {
      if (semesterPassedNonGpa[semester] != semesterTotalNonGpa[semester]) {
        allNonGpaPassed = false;
        break;
      }
    }

    bool isEligible = courseGPA >= 2.0 && allNonGpaPassed;

    String degreeStatus = '';
    if (isEligible) {
      degreeStatus = 'Eligible for Degree';
    } else {
      if (!allNonGpaPassed) {
        degreeStatus = 'Not Eligible: Non-GPA modules need C or above';
      } else if (courseGPA < 2.0) {
        degreeStatus = 'Not Eligible: GPA below 2.0';
      } else {
        degreeStatus = 'Not Eligible';
      }
    }

    List<String> suggestions = [];
    for (var semester in semesterGPAs.keys) {
      if (semesterGPAs[semester]! < 2.0) {
        suggestions.add('Improve Semester $semester GPA to 2.0+');
      }
    }
    if (courseGPA < 2.0) {
      suggestions.add(
        'Overall GPA ${courseGPA.toStringAsFixed(2)} needs to reach 2.0',
      );
    }

    List<Map<String, dynamic>> failedModules = [];
    List<Map<String, dynamic>> incompleteModules = [];

    for (var result in results) {
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

      String moduleType = module.isGpaModule ? 'GPA' : 'Non-GPA';

      if (['F', 'F(ET)', 'F(CA)'].contains(result.grade)) {
        failedModules.add({
          'moduleId': module.moduleId,
          'moduleName': module.moduleName,
          'semester': module.semester,
          'grade': result.grade,
          'type': moduleType,
          'credits': module.credits,
        });
        suggestions.add('Retake ${module.moduleId} - Failed');
      }

      if (['I', 'I(ET)', 'I(CA)'].contains(result.grade)) {
        incompleteModules.add({
          'moduleId': module.moduleId,
          'moduleName': module.moduleName,
          'semester': module.semester,
          'grade': result.grade,
          'type': moduleType,
          'credits': module.credits,
        });
        suggestions.add('Complete ${module.moduleId} - Incomplete');
      }
    }

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
      _failedModules = failedModules;
      _incompleteModules = incompleteModules;
      _isLoading = false;
    });

    _animationController.forward();
  }

  bool _isNonGpaPassed(String grade) {
    if (grade == 'N/A') return false;
    return ['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C'].contains(grade);
  }

  Color _getGpaColor(double gpa) {
    if (gpa >= 3.5) return AppColors.success;
    if (gpa >= 3.0) return AppColors.primaryBlue;
    if (gpa >= 2.0) return AppColors.warning;
    return AppColors.error;
  }

  String _getGpaLabel(double gpa) {
    if (gpa >= 3.7) return 'Excellent';
    if (gpa >= 3.0) return 'Very Good';
    if (gpa >= 2.0) return 'Good';
    return 'Needs Improvement';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.dark
            ? AppGradients.darkBackgroundGradient
            : AppGradients.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_studentName),
              if (_studentName.isNotEmpty)
                Text(
                  _courseName,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppGradients.goldGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    _courseGPA.toStringAsFixed(2),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Section
                      FadeInAnimation(
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: AppGradients.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Welcome Back!',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Here\'s your academic progress summary',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Stats Row
                      Row(
                        children: [
                          Expanded(
                            child: FadeInAnimation(
                              delay: 100,
                              child: InsightCard(
                                title: 'Total Modules',
                                value: '$_numModules',
                                icon: Icons.book_outlined,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FadeInAnimation(
                              delay: 150,
                              child: InsightCard(
                                title: 'Semesters',
                                value: '$_numSemesters',
                                icon: Icons.calendar_today,
                                color: AppColors.accentPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FadeInAnimation(
                              delay: 200,
                              child: InsightCard(
                                title: 'GPA Modules',
                                value: '$_numGpaModules',
                                icon: Icons.auto_graph,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FadeInAnimation(
                              delay: 250,
                              child: InsightCard(
                                title: 'Non-GPA',
                                value: '$_numNonGpaModules',
                                icon: Icons.school_outlined,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // GPA Analytics Section
                      FadeInAnimation(
                        delay: 300,
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: AppGradients.goldGradient,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.trending_up,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'GPA Analytics',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  GaugeChart(
                                    value: _courseGPA,
                                    maxValue: 4.0,
                                    label: 'CGPA',
                                    color: _getGpaColor(_courseGPA),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildGpaInfoRow(
                                        'Current CGPA',
                                        _courseGPA.toStringAsFixed(2),
                                        _getGpaColor(_courseGPA),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildGpaInfoRow(
                                        'Target',
                                        '2.00',
                                        AppColors.warning,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildGpaInfoRow(
                                        'Status',
                                        _getGpaLabel(_courseGPA),
                                        _getGpaColor(_courseGPA),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              LinearProgressIndicator(
                                value: _courseGPA / 4.0,
                                backgroundColor: Colors.grey.shade200,
                                color: _getGpaColor(_courseGPA),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Degree Status
                      FadeInAnimation(
                        delay: 350,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: _isDegreeEligible
                                ? AppGradients.successGradient
                                : AppGradients.warningGradient,
                            borderRadius: BorderRadius.circular(
                              AppConstants.borderRadiusLg,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  _isDegreeEligible
                                      ? Icons.verified
                                      : Icons.warning_amber,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Degree Status',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      Text(
                                        _degreeStatus,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Failed Modules Section (Collapsible)
                      if (_failedModules.isNotEmpty) ...[
                        FadeInAnimation(
                          delay: 400,
                          child: GlassCard(
                            padding: EdgeInsets.zero,
                            child: Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: _isFailedModulesExpanded,
                                onExpansionChanged: (expanded) {
                                  setState(() {
                                    _isFailedModulesExpanded = expanded;
                                  });
                                },
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: AppGradients.errorGradient,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.cancel,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                title: const Text(
                                  'Failed Modules',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_failedModules.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: _failedModules
                                          .map(
                                            (module) => _buildModuleAlert(
                                              module,
                                              AppColors.error,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Incomplete Modules Section (Collapsible)
                      if (_incompleteModules.isNotEmpty) ...[
                        FadeInAnimation(
                          delay: 450,
                          child: GlassCard(
                            padding: EdgeInsets.zero,
                            child: Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: _isIncompleteModulesExpanded,
                                onExpansionChanged: (expanded) {
                                  setState(() {
                                    _isIncompleteModulesExpanded = expanded;
                                  });
                                },
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: AppGradients.warningGradient,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.pending,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                title: const Text(
                                  'Incomplete Modules',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_incompleteModules.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: _incompleteModules
                                          .map(
                                            (module) => _buildModuleAlert(
                                              module,
                                              AppColors.warning,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Semester Performance
                      if (_semesterGPAs.isNotEmpty) ...[
                        FadeInAnimation(
                          delay: 500,
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.school,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Semester Performance',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ...(_semesterGPAs.keys.toList()..sort()).map(
                                  (semester) => _buildSemesterCard(semester),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Suggestions
                      if (_suggestions.isNotEmpty) ...[
                        FadeInAnimation(
                          delay: 550,
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.goldGradient,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.lightbulb,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'AI Suggestions',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ..._suggestions.map(
                                  (suggestion) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: AppColors.gold,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            suggestion,
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildGpaInfoRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildModuleAlert(Map<String, dynamic> module, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      module['moduleId'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: module['type'] == 'GPA'
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        module['type'],
                        style: TextStyle(
                          fontSize: 10,
                          color: module['type'] == 'GPA'
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  module['moduleName'],
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  module['grade'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Semester ${module['semester']}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterCard(int semester) {
    double gpa = _semesterGPAs[semester]!;
    int gpaCredits = _semesterGpaCredits[semester] ?? 0;
    int passedNonGpa = _semesterPassedNonGpaModules[semester] ?? 0;
    int totalNonGpa = _semesterTotalNonGpaModules[semester] ?? 0;
    Color gpaColor = _getGpaColor(gpa);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gpaColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$semester',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Semester',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        '$semester',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [gpaColor, gpaColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'GPA: ${gpa.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: gpa / 4.0,
            backgroundColor: Colors.grey.shade200,
            color: gpaColor,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.credit_card, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                '$gpaCredits credits',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const Spacer(),
              if (totalNonGpa > 0)
                Row(
                  children: [
                    Icon(
                      passedNonGpa == totalNonGpa
                          ? Icons.check_circle
                          : Icons.warning,
                      size: 12,
                      color: passedNonGpa == totalNonGpa
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Non-GPA: $passedNonGpa/$totalNonGpa',
                      style: TextStyle(
                        fontSize: 11,
                        color: passedNonGpa == totalNonGpa
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
