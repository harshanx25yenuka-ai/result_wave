import 'package:flutter/material.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/models/course.dart';
import 'package:result_wave/models/module.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/screens/login_screen.dart';
import 'package:result_wave/services/database_service.dart';

class CreateAccountScreen extends StatefulWidget {
  @override
  _CreateAccountScreenState createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _studentNameController = TextEditingController();
  String? _selectedCourseId;
  List<Course> _courses = [];
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      await DatabaseService().loadJsonData();
      final courses = await DatabaseService().getCourses();
      setState(() {
        _courses = courses;
        if (courses.isNotEmpty) {
          _selectedCourseId = courses.first.courseId;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage('Error loading courses: $e', isError: true);
    }
  }

  Future<void> _createAccount() async {
    if (_formKey.currentState!.validate() && _selectedCourseId != null) {
      setState(() {
        _isCreating = true;
      });

      try {
        await DatabaseService().insertStudent(
          Student(
            studentId: _studentIdController.text.toUpperCase(),
            studentName: _studentNameController.text.toUpperCase(),
            courseId: _selectedCourseId!,
          ),
        );

        List<Module> modules = await DatabaseService().getModulesByCourse(
          _selectedCourseId!,
        );

        for (var module in modules) {
          await DatabaseService().insertResult(
            Result(moduleId: module.moduleId, grade: 'N/A'),
          );
        }

        _showMessage('Account created successfully!', isError: false);

        await Future.delayed(Duration(milliseconds: 1200));

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      } catch (e) {
        setState(() {
          _isCreating = false;
        });
        _showMessage('Error creating account: $e', isError: true);
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

  @override
  void dispose() {
    _studentIdController.dispose();
    _studentNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_add,
                            size: 35,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      Center(
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Join ResultWave to track your progress',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ),
                      SizedBox(height: 32),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _studentIdController,
                                  decoration: InputDecoration(
                                    labelText: 'Student ID',
                                    prefixIcon: Icon(Icons.badge),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) => value!.isEmpty
                                      ? 'Enter Student ID'
                                      : null,
                                ),
                                SizedBox(height: 16),
                                TextFormField(
                                  controller: _studentNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Student Name',
                                    prefixIcon: Icon(Icons.person),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) => value!.isEmpty
                                      ? 'Enter Student Name'
                                      : null,
                                ),
                                SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'Course',
                                    prefixIcon: Icon(Icons.school),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  value: _selectedCourseId,
                                  items: _courses.map((course) {
                                    return DropdownMenuItem<String>(
                                      value: course.courseId,
                                      child: Text(course.courseName),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCourseId = value;
                                    });
                                  },
                                  validator: (value) =>
                                      value == null ? 'Select a course' : null,
                                ),
                                SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isCreating
                                        ? null
                                        : _createAccount,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF2563EB),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isCreating
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : Text(
                                            'Create Account',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
