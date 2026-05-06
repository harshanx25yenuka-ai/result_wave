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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
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
    _modules = await DatabaseService().getModulesByCourse(student.courseId);
    _results = await DatabaseService().getResults();
    _grades = await DatabaseService().getGrades();

    setState(() => _isLoading = false);
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
    if (result != null) _loadData();
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

  @override
  Widget build(BuildContext context) {
    var semesters = _modules.map((m) => m.semester).toSet().toList()..sort();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Results'),
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
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppGradients.darkBackgroundGradient
              : AppGradients.backgroundGradient,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : semesters.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: semesters.length,
                  itemBuilder: (context, index) {
                    int semester = semesters[index];
                    var semesterModules = _modules
                        .where((m) => m.semester == semester)
                        .toList();
                    var filteredModules = _getFilteredModules(semesterModules);

                    if (filteredModules.isEmpty) return const SizedBox();

                    // Add spacing between cards
                    return Column(
                      children: [
                        FadeInAnimation(
                          delay: index * 50,
                          child: _buildSemesterCard(semester, filteredModules),
                        ),
                        // Add spacing between semester cards (except last)
                        if (index != semesters.length - 1)
                          const SizedBox(height: 20),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No Results Available',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your academic results will appear here',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterCard(int semester, List<Module> modules) {
    int nonGpaTotal = modules.where((m) => m.isNonGpaModule).length;
    int nonGpaPassed = modules.where((m) => m.isNonGpaModule).where((m) {
      var result = _results.firstWhere(
        (r) => r.moduleId == m.moduleId,
        orElse: () => Result(moduleId: m.moduleId, grade: 'N/A'),
      );
      return _isNonGpaPassed(result.grade);
    }).length;
    bool allNonGpaPassed = nonGpaTotal == 0 || nonGpaPassed == nonGpaTotal;

    // Calculate semester GPA for GPA modules
    double semesterGPA = 0.0;
    int totalGpaCredits = 0;
    double totalGpaPoints = 0.0;

    for (var module in modules.where((m) => m.isGpaModule)) {
      var result = _results.firstWhere(
        (r) => r.moduleId == module.moduleId,
        orElse: () => Result(moduleId: module.moduleId, grade: 'N/A'),
      );
      var grade = _grades.firstWhere(
        (g) => g.grade == result.grade,
        orElse: () => Grade(grade: 'N/A', gradePoint: 0.0, status: ''),
      );
      if (result.grade != 'N/A') {
        totalGpaPoints += grade.gradePoint * module.credits;
        totalGpaCredits += module.credits;
      }
    }

    if (totalGpaCredits > 0) {
      semesterGPA = totalGpaPoints / totalGpaCredits;
    }

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: allNonGpaPassed && semesterGPA >= 2.0
                  ? AppGradients.primary
                  : (semesterGPA < 2.0 && semesterGPA > 0
                        ? AppGradients.warningGradient
                        : AppGradients.errorGradient),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$semester',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          title: Text(
            'Semester $semester',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${modules.length} modules'),
              if (semesterGPA > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(Icons.star, size: 12, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Text(
                        'GPA: ${semesterGPA.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: semesterGPA >= 3.0
                              ? AppColors.success
                              : (semesterGPA >= 2.0
                                    ? AppColors.warning
                                    : AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              if (nonGpaTotal > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Non-GPA: $nonGpaPassed/$nonGpaTotal passed',
                    style: TextStyle(
                      fontSize: 11,
                      color: allNonGpaPassed
                          ? AppColors.success
                          : AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: semesterGPA >= 3.0
                  ? AppGradients.successGradient
                  : (semesterGPA >= 2.0
                        ? AppGradients.warningGradient
                        : AppGradients.errorGradient),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              semesterGPA > 0 ? semesterGPA.toStringAsFixed(2) : 'N/A',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: modules.map((module) {
                  var result = _results.firstWhere(
                    (r) => r.moduleId == module.moduleId,
                    orElse: () =>
                        Result(moduleId: module.moduleId, grade: 'N/A'),
                  );
                  bool isNonGpa = module.isNonGpaModule;
                  int gradePoints = _getGradePoints(result.grade);
                  Color gradeColor = _getGradeColor(result.grade);

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade100,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _editResult(module.moduleId, result.grade),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
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
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          module.moduleId,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
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
                                              color: AppColors.warning
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                        color: Colors.grey.shade600,
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
                                    colors: [
                                      gradeColor,
                                      gradeColor.withOpacity(0.7),
                                    ],
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
                                Icons.chevron_right,
                                size: 20,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                decoration: InputDecoration(
                  hintText: 'Module code or name',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
    bool isSelected = _selectedTypeFilter == value;
    return ListTile(
      leading: Radio<String?>(
        value: value,
        groupValue: _selectedTypeFilter,
        onChanged: (v) {
          setState(() => _selectedTypeFilter = v);
          Navigator.pop(context);
        },
        activeColor: AppColors.primaryBlue,
      ),
      title: Text(label),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.primaryBlue)
          : null,
    );
  }
}
