import 'package:flutter/material.dart';
import 'package:result_wave/models/module.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/models/grade.dart';
import 'package:result_wave/pages/edit_result_page.dart';
import 'package:result_wave/services/database_service.dart';

class ResultsPage extends StatefulWidget {
  final String studentId;

  ResultsPage({required this.studentId});

  @override
  _ResultsPageState createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  List<Module> _modules = [];
  List<Result> _results = [];
  List<Grade> _grades = [];
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
    _modules = await DatabaseService().getModulesByCourse(student.courseId);
    _results = await DatabaseService().getResults();
    _grades = await DatabaseService().getGrades();

    setState(() {
      _isLoading = false;
    });
  }

  Color _getGradeColor(String grade) {
    if (['F', 'F(CA)', 'F(ET)'].contains(grade)) return Colors.red;
    if (['I', 'I(ET)', 'I(CA)'].contains(grade)) return Colors.orange;
    if (['A+', 'A', 'A-'].contains(grade)) return Colors.green;
    if (['B+', 'B', 'B-'].contains(grade)) return Colors.blue;
    if (['C+', 'C', 'C-'].contains(grade)) return Colors.cyan;
    if (grade == 'N/A') return Colors.grey;
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
    if (['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C'].contains(grade)) {
      return true;
    }
    return false;
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
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    var semesters = _modules.map((m) => m.semester).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text('Results'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : semesters.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No Results Available',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your academic results will appear here once available.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: semesters.length,
                itemBuilder: (context, index) {
                  int semester = semesters[index];
                  var semesterModules = _modules
                      .where((m) => m.semester == semester)
                      .toList();

                  // Sort modules by grade (highest to lowest)
                  semesterModules.sort((a, b) {
                    var resultA = _results.firstWhere(
                      (r) => r.moduleId == a.moduleId,
                      orElse: () => Result(moduleId: a.moduleId, grade: 'N/A'),
                    );
                    var resultB = _results.firstWhere(
                      (r) => r.moduleId == b.moduleId,
                      orElse: () => Result(moduleId: b.moduleId, grade: 'N/A'),
                    );

                    int pointsA = _getGradePoints(resultA.grade);
                    int pointsB = _getGradePoints(resultB.grade);

                    // Sort by grade points descending (highest first)
                    return pointsB.compareTo(pointsA);
                  });

                  // Calculate pass status for non-GPA modules in this semester
                  int nonGpaTotal = semesterModules
                      .where((m) => m.isNonGpaModule)
                      .length;
                  int nonGpaPassed = semesterModules
                      .where((m) => m.isNonGpaModule)
                      .where((m) {
                        var result = _results.firstWhere(
                          (r) => r.moduleId == m.moduleId,
                          orElse: () =>
                              Result(moduleId: m.moduleId, grade: 'N/A'),
                        );
                        return _isNonGpaPassed(result.grade);
                      })
                      .length;

                  bool allNonGpaPassed =
                      nonGpaTotal == 0 || nonGpaPassed == nonGpaTotal;

                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: allNonGpaPassed
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$semester',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: allNonGpaPassed
                                    ? Colors.blue
                                    : Colors.orange,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          'Semester $semester',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${semesterModules.length} modules'),
                            if (nonGpaTotal > 0)
                              Text(
                                'Non-GPA: $nonGpaPassed/$nonGpaTotal passed',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: allNonGpaPassed
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                          ],
                        ),
                        children: semesterModules.map((module) {
                          var result = _results.firstWhere(
                            (r) => r.moduleId == module.moduleId,
                            orElse: () =>
                                Result(moduleId: module.moduleId, grade: 'N/A'),
                          );
                          bool isNonGpa = module.isNonGpaModule;
                          bool isPassed = isNonGpa
                              ? _isNonGpaPassed(result.grade)
                              : true;
                          int gradePoints = _getGradePoints(result.grade);

                          return Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getGradeColor(result.grade),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          module.moduleId,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (isNonGpa)
                                          Container(
                                            margin: EdgeInsets.only(top: 2),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Non-GPA',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.orange,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                module.moduleName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getGradeColor(
                                    result.grade,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: isNonGpa && !isPassed
                                      ? Border.all(
                                          color: Colors.orange,
                                          width: 1,
                                        )
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          result.grade,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _getGradeColor(result.grade),
                                          ),
                                        ),
                                        if (gradePoints > 0)
                                          Text(
                                            '${(gradePoints / 10).toStringAsFixed(1)} pts',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (isNonGpa && !isPassed)
                                      Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: Icon(
                                          Icons.warning,
                                          size: 14,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    SizedBox(width: 8),
                                    Container(
                                      width: 1,
                                      height: 20,
                                      color: Colors.grey[300],
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.edit,
                                      size: 18,
                                      color: Colors.grey[500],
                                    ),
                                  ],
                                ),
                              ),
                              onTap: () =>
                                  _editResult(module.moduleId, result.grade),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
