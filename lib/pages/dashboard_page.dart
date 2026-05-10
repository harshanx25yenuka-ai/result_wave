import 'package:flutter/material.dart';
import 'package:result_wave/models/module.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/models/grade.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/models/course.dart';
import 'package:result_wave/screens/settings_screen.dart';
import 'package:result_wave/pages/insights_page.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/utils/constants.dart';
import 'package:result_wave/utils/animations.dart';
import 'package:result_wave/widgets/glass_card.dart';
import 'package:result_wave/widgets/insight_card.dart';
import 'package:result_wave/widgets/gauge_chart.dart';
import 'package:result_wave/core/gpa_system.dart';

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
  int _insightsCount = 0;
  bool _isDegreeEligible = false;
  String _degreeStatus = '';
  bool _isLoading = true;
  String _studentName = '';
  String _courseName = '';

  List<Map<String, dynamic>> _failedModules = [];
  List<Map<String, dynamic>> _incompleteModules = [];

  bool _isFailedModulesExpanded = false;
  bool _isIncompleteModulesExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
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

    try {
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
        semesterNonGpaModules
            .putIfAbsent(module.semester, () => [])
            .add(module);
      }

      // Use GPASystem to calculate semester GPAs
      Map<int, double> semesterGPAs = {};
      Map<int, int> semesterGpaCredits = {};

      for (var semester in semesterGpaModules.keys) {
        int totalCredits = 0;
        for (var module in semesterGpaModules[semester]!) {
          totalCredits += module.credits;
        }
        semesterGpaCredits[semester] = totalCredits;

        final semesterGPA = GPASystem.calculateSemesterGPA(
          modules: semesterGpaModules[semester]!,
          results: results,
          grades: grades,
        );
        if (semesterGPA > 0) {
          semesterGPAs[semester] = semesterGPA;
        }
      }

      // Calculate Non-GPA pass counts
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
          if (GPASystem.isNonGpaPassed(result.grade)) passedCount++;
        }

        semesterPassedNonGpa[semester] = passedCount;
        semesterTotalNonGpa[semester] = totalCount;
      }

      // Calculate overall CGPA using GPASystem
      double courseGPA = GPASystem.calculateCGPA(
        semesterGPAs: semesterGPAs,
        semesterCredits: semesterGpaCredits,
      );

      // Check if all Non-GPA modules are passed
      bool allNonGpaPassed = true;
      for (var semester in semesterNonGpaModules.keys) {
        if (semesterPassedNonGpa[semester] != semesterTotalNonGpa[semester]) {
          allNonGpaPassed = false;
          break;
        }
      }

      // Check degree eligibility using GPASystem
      bool isEligible = GPASystem.isDegreeEligible(
        cgpa: courseGPA,
        semesterPassedNonGpa: semesterPassedNonGpa,
        semesterTotalNonGpa: semesterTotalNonGpa,
      );

      // Get degree status message using GPASystem
      String degreeStatus = GPASystem.getDegreeStatus(
        cgpa: courseGPA,
        allNonGpaPassed: allNonGpaPassed,
      );

      // Calculate insights count for notification badge
      int insightsCount = 0;
      for (var result in results) {
        if (['F', 'F(ET)', 'F(CA)'].contains(result.grade)) {
          insightsCount++;
        }
        if (['I', 'I(ET)', 'I(CA)'].contains(result.grade)) {
          insightsCount++;
        }
      }
      if (courseGPA < 2.0)
        insightsCount++;
      else if (courseGPA < 2.5)
        insightsCount++;

      for (var semester in semesterGPAs.keys) {
        if (semesterGPAs[semester]! < 2.0) insightsCount++;
      }

      for (var semester in semesterNonGpaModules.keys) {
        int passed = semesterPassedNonGpa[semester] ?? 0;
        int total = semesterTotalNonGpa[semester] ?? 0;
        if (passed < total) insightsCount++;
      }
      if (!isEligible) insightsCount++;
      if (insightsCount == 0) insightsCount = 1;

      // Collect failed and incomplete modules
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

        if (['F', 'F(ET)', 'F(CA)'].contains(result.grade)) {
          failedModules.add({
            'moduleId': module.moduleId,
            'moduleName': module.moduleName,
            'semester': module.semester,
            'grade': result.grade,
            'type': module.isGpaModule ? 'GPA' : 'Non-GPA',
            'credits': module.credits,
          });
        }

        if (['I', 'I(ET)', 'I(CA)'].contains(result.grade)) {
          incompleteModules.add({
            'moduleId': module.moduleId,
            'moduleName': module.moduleName,
            'semester': module.semester,
            'grade': result.grade,
            'type': module.isGpaModule ? 'GPA' : 'Non-GPA',
            'credits': module.credits,
          });
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
        _insightsCount = insightsCount;
        _isDegreeEligible = isEligible;
        _degreeStatus = degreeStatus;
        _failedModules = failedModules;
        _incompleteModules = incompleteModules;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  Color _getGpaColor(double gpa) {
    if (gpa >= 3.5) return AppColors.success;
    if (gpa >= 3.0) return AppColors.primaryBlue;
    if (gpa >= 2.0) return AppColors.warning;
    return AppColors.error;
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(studentId: widget.studentId),
      ),
    );
  }

  void _openInsights() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InsightsPage(studentId: widget.studentId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
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
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.auto_awesome),
                  if (_insightsCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$_insightsCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: _openInsights,
              tooltip: 'AI Insights',
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: _openSettings,
              tooltip: 'Settings',
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
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
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
                                        isDark,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildGpaInfoRow(
                                        'Target',
                                        '2.00',
                                        AppColors.warning,
                                        isDark,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildGpaInfoRow(
                                        'Status',
                                        GPASystem.getGpaLabel(_courseGPA),
                                        _getGpaColor(_courseGPA),
                                        isDark,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              LinearProgressIndicator(
                                value: _courseGPA / 4.0,
                                backgroundColor: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
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

                      // Failed Modules Section
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
                                              isDark,
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

                      // Incomplete Modules Section
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
                                              isDark,
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
                                  (semester) =>
                                      _buildSemesterCard(semester, isDark),
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

  Widget _buildGpaInfoRow(
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
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
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
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

  Widget _buildModuleAlert(
    Map<String, dynamic> module,
    Color color,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.05),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : null,
                      ),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
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
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterCard(int semester, bool isDark) {
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
          colors: isDark
              ? [AppColors.surfaceDark, AppColors.backgroundDark]
              : [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? gpaColor.withOpacity(0.3) : gpaColor.withOpacity(0.3),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
                      Text(
                        'Semester',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey.shade500 : Colors.grey,
                        ),
                      ),
                      Text(
                        '$semester',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : null,
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
            backgroundColor: isDark
                ? Colors.grey.shade800
                : Colors.grey.shade200,
            color: gpaColor,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.credit_card,
                size: 12,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                '$gpaCredits credits',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
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
