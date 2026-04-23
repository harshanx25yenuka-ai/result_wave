import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/providers/theme_provider.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/services/pdf_service.dart';

class SettingsPage extends StatefulWidget {
  final String studentId;

  SettingsPage({required this.studentId});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Student? _student;
  List<int> _semesters = [];
  int? _selectedSemester;
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final students = await DatabaseService().getStudents();
    _student = students.firstWhere((s) => s.studentId == widget.studentId);

    final modules = await DatabaseService().getModulesByCourse(
      _student!.courseId,
    );
    _semesters = modules.map((m) => m.semester).toSet().toList()..sort();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _exportPdf({int? semester}) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final path = await PdfService().generateResultsPdf(
        studentId: widget.studentId,
        semester: semester,
      );
      _showMessage('PDF saved to: $path', isError: false);
    } catch (e) {
      _showMessage('Error exporting PDF: $e', isError: true);
    } finally {
      setState(() {
        _isExporting = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                // Profile Section
                Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.badge,
                          'Student ID',
                          _student?.studentId ?? '',
                          Colors.blue,
                        ),
                        Divider(),
                        _buildInfoRow(
                          Icons.person,
                          'Student Name',
                          _student?.studentName ?? '',
                          Colors.green,
                        ),
                        Divider(),
                        _buildInfoRow(
                          Icons.school,
                          'Course',
                          _student?.courseId ?? '',
                          Colors.purple,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Appearance Section
                Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              themeProvider.themeMode == ThemeMode.dark
                                  ? Icons.dark_mode
                                  : Icons.light_mode,
                              color: Colors.amber,
                            ),
                            SizedBox(width: 12),
                            Text(
                              themeProvider.themeMode == ThemeMode.dark
                                  ? 'Dark Mode'
                                  : 'Light Mode',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: themeProvider.themeMode == ThemeMode.dark,
                          onChanged: (value) {
                            themeProvider.toggleTheme(value);
                          },
                          activeColor: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Export Section
                Text(
                  'Export',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.description, color: Colors.green),
                          ),
                          title: Text('Export Full Report'),
                          subtitle: Text(
                            'Download complete academic transcript',
                          ),
                          trailing: _isExporting && _selectedSemester == null
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _exportPdf(),
                        ),
                        Divider(),
                        DropdownButtonFormField<int>(
                          decoration: InputDecoration(
                            labelText: 'Select Semester',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                          value: _selectedSemester,
                          items: _semesters.map((semester) {
                            return DropdownMenuItem<int>(
                              value: semester,
                              child: Text('Semester $semester'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedSemester = value;
                            });
                            if (value != null) {
                              _exportPdf(semester: value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
