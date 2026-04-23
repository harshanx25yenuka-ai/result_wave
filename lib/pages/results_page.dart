import 'package:flutter/material.dart';
import 'package:result_wave/models/module.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/models/student.dart';
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

    setState(() {
      _isLoading = false;
    });
  }

  Color _getGradeColor(String grade) {
    if (['F', 'F(CA)', 'F(ET)', 'I', 'I(ET)', 'I(CA)'].contains(grade)) {
      return Colors.red;
    }
    if (['A+', 'A', 'A-', 'B+', 'B', 'B-'].contains(grade)) {
      return Colors.green;
    }
    if (['C+', 'C', 'C-'].contains(grade)) {
      return Colors.blue;
    }
    if (grade == 'N/A') {
      return Colors.grey;
    }
    return Colors.orange;
  }

  String _getGradeStatus(String grade) {
    if ([
      'A+',
      'A',
      'A-',
      'B+',
      'B',
      'B-',
      'C+',
      'C',
      'C-',
      'D+',
      'D',
    ].contains(grade)) {
      return 'Pass';
    }
    if (['F', 'F(CA)', 'F(ET)'].contains(grade)) {
      return 'Fail';
    }
    if (['I', 'I(ET)', 'I(CA)'].contains(grade)) {
      return 'Incomplete';
    }
    return 'Pending';
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
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$semester',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
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
                        subtitle: Text('${semesterModules.length} modules'),
                        children: semesterModules.map((module) {
                          var result = _results.firstWhere(
                            (r) => r.moduleId == module.moduleId,
                            orElse: () =>
                                Result(moduleId: module.moduleId, grade: 'N/A'),
                          );
                          return ListTile(
                            leading: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getGradeColor(result.grade),
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              module.moduleId,
                              style: TextStyle(fontWeight: FontWeight.w600),
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
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    result.grade,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _getGradeColor(result.grade),
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
