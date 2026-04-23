import 'package:flutter/material.dart';
import 'package:result_wave/models/grade.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/services/database_service.dart';

class EditResultPage extends StatefulWidget {
  final String moduleId;
  final String currentGrade;

  EditResultPage({required this.moduleId, required this.currentGrade});

  @override
  _EditResultPageState createState() => _EditResultPageState();
}

class _EditResultPageState extends State<EditResultPage> {
  String? _selectedGrade;
  List<Grade> _grades = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedGrade = widget.currentGrade;
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    try {
      _grades = await DatabaseService().getGrades();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage('Error loading grades: $e', isError: true);
    }
  }

  Future<void> _saveResult() async {
    if (_selectedGrade != null) {
      setState(() {
        _isSaving = true;
      });

      try {
        await DatabaseService().insertResult(
          Result(moduleId: widget.moduleId, grade: _selectedGrade!),
        );

        _showMessage('Result updated successfully!', isError: false);

        await Future.delayed(Duration(milliseconds: 800));
        Navigator.pop(context, _selectedGrade);
      } catch (e) {
        setState(() {
          _isSaving = false;
        });
        _showMessage('Error saving result: $e', isError: true);
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _getGradeColor(String grade) {
    if (['A+', 'A', 'A-'].contains(grade)) return Colors.green;
    if (['B+', 'B', 'B-'].contains(grade)) return Colors.blue;
    if (['C+', 'C', 'C-'].contains(grade)) return Colors.orange;
    if (['D+', 'D'].contains(grade)) return Colors.yellow[800]!;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Result'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Module',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      widget.moduleId,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          Divider(),
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Current Grade',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _getGradeColor(
                                    widget.currentGrade,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  widget.currentGrade,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: _getGradeColor(widget.currentGrade),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select New Grade',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            value: _selectedGrade,
                            items: _grades.map((grade) {
                              return DropdownMenuItem<String>(
                                value: grade.grade,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: _getGradeColor(grade.grade),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      '${grade.grade} (${grade.gradePoint} pts)',
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) =>
                                setState(() => _selectedGrade = value),
                          ),
                          if (_selectedGrade != null &&
                              _selectedGrade != widget.currentGrade)
                            Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Grade will be updated from "${widget.currentGrade}" to "$_selectedGrade"',
                                        style: TextStyle(fontSize: 14),
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
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveResult,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSaving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
