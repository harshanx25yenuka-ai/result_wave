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

class InsightsPage extends StatefulWidget {
  final String studentId;

  const InsightsPage({Key? key, required this.studentId}) : super(key: key);

  @override
  _InsightsScreenState createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late PageController _pageController;
  List<Map<String, dynamic>> _allSuggestions = [];
  Map<String, List<Map<String, dynamic>>> _categorizedSuggestions = {};
  bool _isLoading = true;
  String _studentName = '';
  String _courseName = '';
  int _currentPageIndex = 0;

  // Category order
  final List<String> _categoryOrder = [
    'critical',
    'warning',
    'info',
    'success',
  ];

  // Category expansion states
  Map<String, bool> _categoryExpanded = {
    'critical': true,
    'warning': true,
    'info': true,
    'success': true,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _pageController = PageController();
    _loadInsights();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInsights() async {
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

    Map<int, List<Module>> semesterGpaModules = {};

    for (var module in gpaModules) {
      semesterGpaModules.putIfAbsent(module.semester, () => []).add(module);
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

    Map<int, int> semesterPassedNonGpa = {};
    Map<int, int> semesterTotalNonGpa = {};

    List<Module> nonGpaModules = modules
        .where((m) => m.isNonGpaModule)
        .toList();
    Map<int, List<Module>> semesterNonGpaModules = {};
    for (var module in nonGpaModules) {
      semesterNonGpaModules.putIfAbsent(module.semester, () => []).add(module);
    }

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

    bool allNonGpaPassed = true;
    for (var semester in semesterNonGpaModules.keys) {
      if (semesterPassedNonGpa[semester] != semesterTotalNonGpa[semester]) {
        allNonGpaPassed = false;
        break;
      }
    }

    bool isEligible = courseGPA >= 2.0 && allNonGpaPassed;

    // Generate AI Suggestions
    List<Map<String, dynamic>> suggestions = [];

    // CRITICAL: Failed modules
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
        suggestions.add({
          'category': 'critical',
          'icon': Icons.cancel,
          'title': 'Failed Module',
          'message':
              'You have failed ${module.moduleId}: ${module.moduleName}.',
          'action': 'Retake the module in the next available semester',
          'priority': 1,
          'moduleId': module.moduleId,
          'credits': module.credits,
          'semester': module.semester,
        });
      }
    }

    // WARNING: Incomplete modules
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

      if (['I', 'I(ET)', 'I(CA)'].contains(result.grade)) {
        suggestions.add({
          'category': 'warning',
          'icon': Icons.pending,
          'title': 'Incomplete Module',
          'message':
              'Module ${module.moduleId}: ${module.moduleName} is incomplete.',
          'action': 'Complete all assessments and end test requirements',
          'priority': 2,
          'moduleId': module.moduleId,
          'semester': module.semester,
        });
      }
    }

    // CRITICAL: Low CGPA
    if (courseGPA < 2.0) {
      suggestions.add({
        'category': 'critical',
        'icon': Icons.trending_down,
        'title': 'Low CGPA Warning',
        'message':
            'Your CGPA is ${courseGPA.toStringAsFixed(2)} (below required 2.0).',
        'action':
            'Focus on improving grades and consider retaking failed modules',
        'priority': 1,
      });
    }

    // WARNING: CGPA Needs Improvement
    if (courseGPA >= 2.0 && courseGPA < 2.5) {
      suggestions.add({
        'category': 'warning',
        'icon': Icons.info_outline,
        'title': 'CGPA Needs Improvement',
        'message': 'Your CGPA is ${courseGPA.toStringAsFixed(2)}.',
        'action':
            'Aim for higher grades in remaining modules to boost your CGPA',
        'priority': 3,
      });
    }

    // WARNING: Low semester GPA
    for (var semester in semesterGPAs.keys) {
      if (semesterGPAs[semester]! < 2.0) {
        suggestions.add({
          'category': 'warning',
          'icon': Icons.warning_amber,
          'title': 'Low Semester GPA',
          'message':
              'Semester $semester GPA is ${semesterGPAs[semester]!.toStringAsFixed(2)}.',
          'action': 'Review your study strategies and seek academic support',
          'priority': 2,
          'semester': semester,
        });
      }
    }

    // SUCCESS: Excellent semester performance
    for (var semester in semesterGPAs.keys) {
      if (semesterGPAs[semester]! >= 3.5) {
        suggestions.add({
          'category': 'success',
          'icon': Icons.celebration,
          'title': 'Excellent Performance!',
          'message':
              'Outstanding GPA of ${semesterGPAs[semester]!.toStringAsFixed(2)} in Semester $semester.',
          'action': 'Maintain this momentum and consider honors opportunities',
          'priority': 4,
          'semester': semester,
        });
      }
    }

    // WARNING: Non-GPA modules pending
    for (var semester in semesterNonGpaModules.keys) {
      int passed = semesterPassedNonGpa[semester] ?? 0;
      int total = semesterTotalNonGpa[semester] ?? 0;
      if (passed < total) {
        int failed = total - passed;
        suggestions.add({
          'category': 'warning',
          'icon': Icons.school,
          'title': 'Non-GPA Modules Pending',
          'message':
              '$failed Non-GPA module(s) in Semester $semester need completion.',
          'action':
              'These modules require a minimum C grade to qualify for degree',
          'priority': 2,
          'semester': semester,
        });
      }
    }

    // CRITICAL: Degree eligibility risk
    if (!isEligible) {
      if (courseGPA < 2.0) {
        suggestions.add({
          'category': 'critical',
          'icon': Icons.assignment_late,
          'title': 'Degree Eligibility Risk',
          'message': 'Your CGPA is below 2.0, affecting degree eligibility.',
          'action': 'Focus on improving grades in remaining semesters',
          'priority': 1,
        });
      } else if (!allNonGpaPassed) {
        suggestions.add({
          'category': 'critical',
          'icon': Icons.assignment_late,
          'title': 'Non-GPA Requirements Pending',
          'message':
              'You have incomplete Non-GPA modules that affect degree eligibility.',
          'action': 'Complete all Non-GPA modules with minimum C grade',
          'priority': 1,
        });
      }
    }

    // SUCCESS: Degree eligible
    if (isEligible && courseGPA >= 2.0) {
      suggestions.add({
        'category': 'success',
        'icon': Icons.verified,
        'title': 'Degree Eligible',
        'message': 'Congratulations! You are on track to complete your degree.',
        'action': 'Maintain your current performance to ensure graduation',
        'priority': 4,
      });
    }

    // SUCCESS: Great academic standing
    if (courseGPA >= 3.0 && isEligible) {
      suggestions.add({
        'category': 'success',
        'icon': Icons.emoji_events,
        'title': 'Great Academic Standing',
        'message': 'You are performing exceptionally well.',
        'action': 'Consider applying for scholarships or academic recognition',
        'priority': 4,
      });
    }

    // INFO: Study recommendations
    if (!isEligible && semesterGPAs.length >= 2) {
      suggestions.add({
        'category': 'info',
        'icon': Icons.psychology,
        'title': 'Study Strategy Recommendation',
        'message':
            'Based on your performance pattern, consider adjusting your study approach.',
        'action':
            'Join study groups, utilize office hours, and practice past papers',
        'priority': 3,
      });
    }

    // INFO: Credit completion progress
    int totalCredits = modules.fold(0, (sum, m) => sum + m.credits);
    int completedCredits = 0;
    for (var result in results) {
      var module = modules.firstWhere(
        (m) => m.moduleId == result.moduleId,
        orElse: () => Module(
          moduleId: '',
          moduleName: '',
          credits: 0,
          courseIds: [],
          semester: 0,
          gpaType: 'gpa',
        ),
      );
      var grade = grades.firstWhere(
        (g) => g.grade == result.grade,
        orElse: () => Grade(grade: '', gradePoint: 0.0, status: ''),
      );
      if (result.grade != 'N/A' && grade.gradePoint > 0) {
        completedCredits += module.credits;
      }
    }

    double completionPercentage = totalCredits > 0
        ? (completedCredits / totalCredits) * 100
        : 0;
    if (completionPercentage < 50 && !isEligible) {
      suggestions.add({
        'category': 'info',
        'icon': Icons.track_changes,
        'title': 'Credit Completion Progress',
        'message':
            'You have completed ${completionPercentage.toStringAsFixed(0)}% of total credits.',
        'action': 'Focus on completing more modules to stay on track',
        'priority': 3,
      });
    }

    // Sort by priority
    suggestions.sort((a, b) => a['priority'].compareTo(b['priority']));

    // Remove duplicates
    Set<String> seenModules = {};
    suggestions = suggestions.where((s) {
      if (s.containsKey('moduleId')) {
        if (seenModules.contains(s['moduleId'])) {
          return false;
        }
        seenModules.add(s['moduleId']);
      }
      return true;
    }).toList();

    // Categorize suggestions
    Map<String, List<Map<String, dynamic>>> categorized = {
      'critical': [],
      'warning': [],
      'info': [],
      'success': [],
    };

    for (var suggestion in suggestions) {
      String category = suggestion['category'];
      if (categorized.containsKey(category)) {
        categorized[category]!.add(suggestion);
      }
    }

    setState(() {
      _allSuggestions = suggestions;
      _categorizedSuggestions = categorized;
      _isLoading = false;
    });
  }

  bool _isNonGpaPassed(String grade) {
    if (grade == 'N/A') return false;
    return ['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C'].contains(grade);
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'critical':
        return AppColors.error;
      case 'warning':
        return AppColors.warning;
      case 'info':
        return AppColors.info;
      case 'success':
        return AppColors.success;
      default:
        return AppColors.primaryBlue;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      case 'success':
        return Icons.check_circle;
      default:
        return Icons.lightbulb;
    }
  }

  String _getCategoryTitle(String category) {
    switch (category) {
      case 'critical':
        return 'Critical';
      case 'warning':
        return 'Warning';
      case 'info':
        return 'Information';
      case 'success':
        return 'Success';
      default:
        return '';
    }
  }

  String _getCategoryDescription(String category) {
    switch (category) {
      case 'critical':
        return 'Urgent issues requiring immediate attention';
      case 'warning':
        return 'Areas that need improvement';
      case 'info':
        return 'Helpful recommendations and tips';
      case 'success':
        return 'Achievements and positive feedback';
      default:
        return '';
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPageIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Filter out empty categories for page view
    List<String> availableCategories = _categoryOrder.where((category) {
      return (_categorizedSuggestions[category] ?? []).isNotEmpty;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('AI Smart Insights'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        // Removed CGPA display from app bar
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppGradients.darkBackgroundGradient
              : AppGradients.backgroundGradient,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _allSuggestions.isEmpty
            ? _buildEmptyState(isDark, screenHeight)
            : Column(
                children: [
                  // Summary Header - Responsive height
                  SizedBox(
                    height: screenHeight * 0.25,
                    child: _buildSummaryHeader(isDark, screenWidth),
                  ),
                  // Page Indicator
                  if (availableCategories.length > 1)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(availableCategories.length, (
                          index,
                        ) {
                          bool isActive = _currentPageIndex == index;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? _getCategoryColor(
                                      availableCategories[index],
                                    )
                                  : (isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                  // PageView for Swipe Gesture
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      children: availableCategories.map((category) {
                        List<Map<String, dynamic>> items =
                            _categorizedSuggestions[category] ?? [];
                        return _buildCategoryPage(
                          category,
                          items,
                          isDark,
                          screenHeight,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSummaryHeader(bool isDark, double screenWidth) {
    int criticalCount = _categorizedSuggestions['critical']?.length ?? 0;
    int warningCount = _categorizedSuggestions['warning']?.length ?? 0;
    int infoCount = _categorizedSuggestions['info']?.length ?? 0;
    int successCount = _categorizedSuggestions['success']?.length ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      child: GlassCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppGradients.goldGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Analysis Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Based on your academic performance',
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSummaryChip(
                  'Critical',
                  criticalCount,
                  AppColors.error,
                  isDark,
                  screenWidth,
                ),
                _buildSummaryChip(
                  'Warning',
                  warningCount,
                  AppColors.warning,
                  isDark,
                  screenWidth,
                ),
                _buildSummaryChip(
                  'Info',
                  infoCount,
                  AppColors.info,
                  isDark,
                  screenWidth,
                ),
                _buildSummaryChip(
                  'Success',
                  successCount,
                  AppColors.success,
                  isDark,
                  screenWidth,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(
    String label,
    int count,
    Color color,
    bool isDark,
    double screenWidth,
  ) {
    double chipWidth = (screenWidth - 64) / 4; // Responsive width calculation

    return Container(
      width: chipWidth,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPage(
    String category,
    List<Map<String, dynamic>> items,
    bool isDark,
    double screenHeight,
  ) {
    Color categoryColor = _getCategoryColor(category);
    IconData categoryIcon = _getCategoryIcon(category);
    String categoryTitle = _getCategoryTitle(category);
    String categoryDescription = _getCategoryDescription(category);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Category Header Card
          GlassCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            categoryColor,
                            categoryColor.withOpacity(0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(categoryIcon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoryTitle,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            categoryDescription,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${items.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Insights List
          ...items
              .map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: _buildInsightCard(
                    item,
                    categoryColor,
                    isDark,
                    screenHeight,
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
    Map<String, dynamic> insight,
    Color categoryColor,
    bool isDark,
    double screenHeight,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [categoryColor, categoryColor.withOpacity(0.7)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(insight['icon'], color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight['title'],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      insight['message'],
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 18, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '💡 ${insight['action']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (insight.containsKey('semester') || insight.containsKey('credits'))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (insight.containsKey('semester'))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 10,
                            color: categoryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Semester ${insight['semester']}',
                            style: TextStyle(
                              fontSize: 10,
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (insight.containsKey('credits') && insight['credits'] > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.credit_card,
                            size: 10,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${insight['credits']} Credits',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, double screenHeight) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Container(
          height: screenHeight * 0.7,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 80,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No Insights Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete more modules to get AI-powered insights',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
