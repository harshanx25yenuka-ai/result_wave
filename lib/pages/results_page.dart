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

                    return FadeInAnimation(
                      delay: index * 50,
                      child: _buildSemesterCard(semester, filteredModules),
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

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 44,
            height: 44,
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
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
              if (nonGpaTotal > 0)
                Text(
                  'Non-GPA: $nonGpaPassed/$nonGpaTotal passed',
                  style: TextStyle(
                    fontSize: 12,
                    color: allNonGpaPassed
                        ? AppColors.success
                        : AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          children: modules.map((module) {
            var result = _results.firstWhere(
              (r) => r.moduleId == module.moduleId,
              orElse: () => Result(moduleId: module.moduleId, grade: 'N/A'),
            );
            bool isNonGpa = module.isNonGpaModule;
            bool isPassed = isNonGpa ? _isNonGpaPassed(result.grade) : true;
            int gradePoints = _getGradePoints(result.grade);
            Color gradeColor = _getGradeColor(result.grade);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _editResult(module.moduleId, result.grade),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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
                                fontSize: 12,
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
                                        color: AppColors.warning.withOpacity(
                                          0.1,
                                        ),
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
                              const SizedBox(height: 2),
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
                            vertical: 6,
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
                                ),
                              ),
                              if (gradePoints > 0)
                                Text(
                                  '${(gradePoints / 10).toStringAsFixed(1)} pts',
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
