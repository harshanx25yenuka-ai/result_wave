import 'package:flutter/material.dart';
import 'package:result_wave/models/module.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/models/grade.dart';
import 'package:result_wave/pages/edit_result_page.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/utils/constants.dart';
import 'package:result_wave/utils/animations.dart';
import 'package:result_wave/widgets/glass_card.dart';
import 'package:result_wave/widgets/semester_chip.dart';

class ResultsPage extends StatefulWidget {
  final String studentId;

  const ResultsPage({Key? key, required this.studentId}) : super(key: key);

  @override
  _ResultsPageState createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage>
    with SingleTickerProviderStateMixin {
  List<Module> _modules = [];
  List<Result> _results = [];
  List<Grade> _grades = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedTypeFilter;
  late AnimationController _animationController;
  late PageController _pageController;
  late ScrollController _chipScrollController;
  int _currentSemesterIndex = 0;
  List<int> _semesters = [];

  // Cache for performance
  Map<int, Map<String, dynamic>> _cachedStatistics = {};
  Map<int, List<Module>> _cachedFilteredModules = {};
  Map<int, GlobalKey> _chipKeys = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
    _pageController = PageController(viewportFraction: 0.85);
    _chipScrollController = ScrollController();
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    _cachedStatistics.clear();
    _cachedFilteredModules.clear();

    Student student = (await DatabaseService().getStudents()).firstWhere(
      (s) => s.studentId == widget.studentId,
    );
    _modules = await DatabaseService().getModulesByCourse(student.courseId);
    _results = await DatabaseService().getResults();
    _grades = await DatabaseService().getGrades();

    _semesters = _modules.map((m) => m.semester).toSet().toList()..sort();

    for (var semester in _semesters) {
      final semesterModules = _modules
          .where((m) => m.semester == semester)
          .toList();
      final filteredModules = _getFilteredModules(semesterModules);
      final statistics = _getSemesterStatistics(semester, semesterModules);

      _cachedFilteredModules[semester] = filteredModules;
      _cachedStatistics[semester] = statistics;
      _chipKeys[semester] = GlobalKey();
    }

    setState(() => _isLoading = false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollChipToCenter(_currentSemesterIndex);
    });
  }

  Color _getGradeColor(String grade) {
    if (['F', 'F(CA)', 'F(ET)'].contains(grade)) return AppColors.error;
    if (['I', 'I(ET)', 'I(CA)'].contains(grade)) return AppColors.warning;
    if (['A+', 'A', 'A-'].contains(grade)) return AppColors.success;
    if (['B+', 'B', 'B-'].contains(grade)) return AppColors.primaryBlue;
    if (['C+', 'C', 'C-'].contains(grade)) return AppColors.accentTeal;
    return Colors.grey;
  }

  int _getGradePoints(String grade) {
    var gradeObj = _grades.firstWhere(
      (g) => g.grade == grade,
      orElse: () => Grade(grade: grade, gradePoint: 0.0, status: ''),
    );
    return (gradeObj.gradePoint * 10).toInt();
  }

  bool _isNonGpaPassed(String grade) {
    if (grade == 'N/A') return false;
    return ['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C'].contains(grade);
  }

  void _editResult(String moduleId, String currentGrade) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditResultPage(moduleId: moduleId, currentGrade: currentGrade),
      ),
    );
    if (result != null) {
      _cachedStatistics.clear();
      _cachedFilteredModules.clear();
      _loadData();
    }
  }

  List<Module> _getFilteredModules(List<Module> modules) {
    var filtered = List<Module>.from(modules);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (m) =>
                m.moduleId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                m.moduleName.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    if (_selectedTypeFilter != null) {
      filtered = filtered
          .where(
            (m) =>
                (_selectedTypeFilter == 'GPA' && m.isGpaModule) ||
                (_selectedTypeFilter == 'Non-GPA' && m.isNonGpaModule),
          )
          .toList();
    }

    return filtered;
  }

  Map<String, dynamic> _getSemesterStatistics(
    int semester,
    List<Module> semesterModules,
  ) {
    int totalModules = semesterModules.length;
    int passedModules = 0;
    int failedModules = 0;
    int pendingModules = 0;
    int nonGpaPassed = 0;
    int nonGpaTotal = 0;

    Map<String, int> gradeCount = {};
    String highestGrade = 'N/A';
    String lowestGrade = 'N/A';
    int highestGradePoints = 0;
    int lowestGradePoints = 100;

    for (var module in semesterModules) {
      var result = _results.firstWhere(
        (r) => r.moduleId == module.moduleId,
        orElse: () => Result(moduleId: module.moduleId, grade: 'N/A'),
      );

      if (result.grade == 'N/A') {
        pendingModules++;
        continue;
      }

      if (module.isNonGpaModule) {
        nonGpaTotal++;
        if (_isNonGpaPassed(result.grade)) {
          nonGpaPassed++;
          passedModules++;
        } else {
          failedModules++;
        }
      } else {
        if (result.grade == 'F' ||
            result.grade == 'F(CA)' ||
            result.grade == 'F(ET)') {
          failedModules++;
        } else {
          passedModules++;
        }
      }

      gradeCount[result.grade] = (gradeCount[result.grade] ?? 0) + 1;

      int points = _getGradePoints(result.grade);
      if (points > highestGradePoints && result.grade != 'N/A') {
        highestGradePoints = points;
        highestGrade = result.grade;
      }
      if (points < lowestGradePoints && points > 0 && result.grade != 'N/A') {
        lowestGradePoints = points;
        lowestGrade = result.grade;
      }
    }

    String mostCommonGrade = 'N/A';
    int maxCount = 0;
    gradeCount.forEach((grade, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommonGrade = grade;
      }
    });

    return {
      'totalModules': totalModules,
      'passedModules': passedModules,
      'failedModules': failedModules,
      'pendingModules': pendingModules,
      'nonGpaPassed': nonGpaPassed,
      'nonGpaTotal': nonGpaTotal,
      'gradeCount': gradeCount,
      'highestGrade': highestGrade,
      'lowestGrade': lowestGrade,
      'mostCommonGrade': mostCommonGrade,
      'passRate': totalModules - pendingModules > 0
          ? (passedModules / (totalModules - pendingModules) * 100)
                .toStringAsFixed(1)
          : '0',
    };
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentSemesterIndex = index;
    });
    _scrollChipToCenter(index);
  }

  void _onChipTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _scrollChipToCenter(int index) {
    if (index < 0 || index >= _semesters.length) return;

    final semester = _semesters[index];
    final chipKey = _chipKeys[semester];

    if (chipKey?.currentContext == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? renderBox =
          chipKey?.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && mounted) {
        final position = renderBox.localToGlobal(Offset.zero);
        final screenWidth = MediaQuery.of(context).size.width;
        final chipWidth = renderBox.size.width;
        final scrollOffset = _chipScrollController.offset;
        final targetOffset =
            scrollOffset + position.dx - (screenWidth / 2) + (chipWidth / 2);

        _chipScrollController.animateTo(
          targetOffset.clamp(
            0.0,
            _chipScrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final chipWidth = screenWidth * 0.28; // 28% of screen width for each chip
    final chipSpacing = 8.0; // Space between chips

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Results'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppGradients.darkBackgroundGradient
              : AppGradients.backgroundGradient,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _semesters.isEmpty
            ? _buildEmptyState()
            : Column(
                children: [
                  // Semester Chips Bar (Scrollable with 3-chip view)
                  Container(
                    margin: const EdgeInsets.only(top: 16, bottom: 8),
                    height: 55, // Reduced from 80 to 55 (30% reduction)
                    child: ListView.builder(
                      controller: _chipScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: (screenWidth - chipWidth) / 2,
                      ),
                      itemCount: _semesters.length,
                      itemBuilder: (context, index) {
                        final semester = _semesters[index];
                        final isActive = _currentSemesterIndex == index;

                        return SemesterChip(
                          key: _chipKeys[semester],
                          semester: semester,
                          isActive: isActive,
                          onTap: () => _onChipTap(index),
                          width: chipWidth,
                          marginHorizontal: chipSpacing,
                        );
                      },
                    ),
                  ),

                  // Page Indicator Dots
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_semesters.length, (index) {
                        final isActive = _currentSemesterIndex == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 24 : 8,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: isActive
                                ? AppColors.primaryBlue
                                : (isDark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade300),
                          ),
                        );
                      }),
                    ),
                  ),

                  // PageView for Swipe Navigation
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _semesters.length,
                      itemBuilder: (context, index) {
                        final semester = _semesters[index];
                        final filteredModules =
                            _cachedFilteredModules[semester] ?? [];
                        final statistics =
                            _cachedStatistics[semester] ??
                            _getSemesterStatistics(
                              semester,
                              _modules
                                  .where((m) => m.semester == semester)
                                  .toList(),
                            );

                        if (filteredModules.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.hourglass_empty,
                                  size: 64,
                                  color: isDark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No modules found for Semester $semester',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return RepaintBoundary(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildStatisticsDashboard(semester, statistics),
                                const SizedBox(height: 16),
                                _buildSemesterCard(
                                  semester,
                                  filteredModules,
                                  statistics,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatisticsDashboard(int semester, Map<String, dynamic> stats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                child: const Center(
                  child: Icon(Icons.analytics, size: 16, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Semester $semester Statistics',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              _buildStatChip(
                '✅ Passed',
                '${stats['passedModules']}',
                AppColors.success,
                isDark,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                '❌ Failed',
                '${stats['failedModules']}',
                AppColors.error,
                isDark,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                '⏳ Pending',
                '${stats['pendingModules']}',
                AppColors.warning,
                isDark,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                '📊 Pass Rate',
                '${stats['passRate']}%',
                AppColors.info,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (stats['gradeCount'].isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (stats['gradeCount'] as Map<String, int>).entries.map((
                entry,
              ) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getGradeColor(entry.key).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getGradeColor(entry.key).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _getGradeColor(entry.key),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildHighlightTile(
                  '🏆 Highest',
                  stats['highestGrade'],
                  AppColors.success,
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHighlightTile(
                  '📉 Lowest',
                  stats['lowestGrade'],
                  AppColors.error,
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHighlightTile(
                  '📊 Most Common',
                  stats['mostCommonGrade'],
                  AppColors.primaryBlue,
                  isDark,
                ),
              ),
            ],
          ),

          if (stats['nonGpaTotal'] > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (stats['nonGpaPassed'] == stats['nonGpaTotal'])
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    stats['nonGpaPassed'] == stats['nonGpaTotal']
                        ? Icons.check_circle
                        : Icons.warning,
                    size: 16,
                    color: stats['nonGpaPassed'] == stats['nonGpaTotal']
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Non-GPA Modules: ${stats['nonGpaPassed']}/${stats['nonGpaTotal']} passed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: stats['nonGpaPassed'] == stats['nonGpaTotal']
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightTile(
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterCard(
    int semester,
    List<Module> modules,
    Map<String, dynamic> stats,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int nonGpaTotal = modules.where((m) => m.isNonGpaModule).length;
    int nonGpaPassed = modules.where((m) => m.isNonGpaModule).where((m) {
      var result = _results.firstWhere(
        (r) => r.moduleId == m.moduleId,
        orElse: () => Result(moduleId: m.moduleId, grade: 'N/A'),
      );
      return _isNonGpaPassed(result.grade);
    }).length;
    bool allNonGpaPassed = nonGpaTotal == 0 || nonGpaPassed == nonGpaTotal;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: allNonGpaPassed
                        ? AppGradients.primary
                        : AppGradients.warningGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$semester',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Semester $semester',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${modules.length} modules',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: double.parse(stats['passRate']) >= 70
                        ? AppColors.success
                        : (double.parse(stats['passRate']) >= 50
                              ? AppColors.warning
                              : AppColors.error),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${stats['passRate']}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          ...modules.map((module) {
            var result = _results.firstWhere(
              (r) => r.moduleId == module.moduleId,
              orElse: () => Result(moduleId: module.moduleId, grade: 'N/A'),
            );
            bool isNonGpa = module.isNonGpaModule;
            int gradePoints = _getGradePoints(result.grade);
            Color gradeColor = _getGradeColor(result.grade);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: InkWell(
                onTap: () => _editResult(module.moduleId, result.grade),
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          module.credits.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
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
                                module.moduleId,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (isNonGpa)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Non-GPA',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            module.moduleName,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [gradeColor, gradeColor.withOpacity(0.7)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            result.grade,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          if (gradePoints > 0)
                            Text(
                              '${(gradePoints / 10).toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.edit,
                      size: 18,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 80,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Results Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your academic results will appear here',
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Search Modules',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Module code or name',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.backgroundDark
                      : Colors.grey.shade50,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _cachedFilteredModules.clear();
                    for (var semester in _semesters) {
                      final semesterModules = _modules
                          .where((m) => m.semester == semester)
                          .toList();
                      _cachedFilteredModules[semester] = _getFilteredModules(
                        semesterModules,
                      );
                    }
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFilterOption('All Modules', null),
            _buildFilterOption('GPA Modules', 'GPA'),
            _buildFilterOption('Non-GPA Modules', 'Non-GPA'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, String? value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isSelected = _selectedTypeFilter == value;

    return ListTile(
      leading: Radio<String?>(
        value: value,
        groupValue: _selectedTypeFilter,
        onChanged: (v) {
          setState(() {
            _selectedTypeFilter = v;
            _cachedFilteredModules.clear();
            for (var semester in _semesters) {
              final semesterModules = _modules
                  .where((m) => m.semester == semester)
                  .toList();
              _cachedFilteredModules[semester] = _getFilteredModules(
                semesterModules,
              );
            }
          });
          Navigator.pop(context);
        },
        activeColor: AppColors.primaryBlue,
      ),
      title: Text(
        label,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.primaryBlue)
          : null,
    );
  }
}
