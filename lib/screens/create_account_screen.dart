import 'package:flutter/material.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/models/course.dart';
import 'package:result_wave/models/module.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/screens/login_screen.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/utils/constants.dart';
import 'package:result_wave/utils/animations.dart';
import 'package:result_wave/widgets/glass_card.dart';

class CreateAccountScreen extends StatefulWidget {
  @override
  _CreateAccountScreenState createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _studentNameController = TextEditingController();
  String? _selectedCourseId;
  List<Course> _courses = [];
  bool _isLoading = true;
  bool _isCreating = false;
  late AnimationController _controller;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _loadCourses();
  }

  @override
  void dispose() {
    _controller.dispose();
    _studentIdController.dispose();
    _studentNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    try {
      await DatabaseService().loadJsonData();
      final courses = await DatabaseService().getCourses();
      setState(() {
        _courses = courses;
        if (courses.isNotEmpty) _selectedCourseId = courses.first.courseId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Error loading courses: $e', isError: true);
    }
  }

  Future<void> _createAccount() async {
    if (_formKey.currentState!.validate() && _selectedCourseId != null) {
      setState(() => _isCreating = true);

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

        await Future.delayed(const Duration(milliseconds: 1200));

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      } catch (e) {
        setState(() => _isCreating = false);
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.primary),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: FadeInAnimation(
                          child: Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.person_add,
                                  size: 40,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Join ResultWave to track your progress',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      FadeInAnimation(
                        delay: 100,
                        child: GlassCard(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _buildStepIndicator(),
                                const SizedBox(height: 24),
                                if (_currentStep == 0) _buildStudentInfoStep(),
                                if (_currentStep == 1) _buildCourseStep(),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    if (_currentStep > 0)
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            setState(() => _currentStep--);
                                          },
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text('Back'),
                                        ),
                                      ),
                                    if (_currentStep > 0)
                                      const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isCreating
                                            ? null
                                            : () {
                                                if (_currentStep == 1) {
                                                  _createAccount();
                                                } else {
                                                  setState(
                                                    () => _currentStep++,
                                                  );
                                                }
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.primaryBlue,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: _isCreating
                                            ? SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                            : Text(
                                                _currentStep == 1
                                                    ? 'Create Account'
                                                    : 'Next',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
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

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepCircle(0, 'Student'),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep >= 1
                ? AppColors.primaryBlue
                : Colors.grey.shade300,
          ),
        ),
        _buildStepCircle(1, 'Course'),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label) {
    bool isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.primaryBlue : Colors.grey.shade300,
            border: Border.all(
              color: isActive ? AppColors.primaryBlue : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? AppColors.primaryBlue : Colors.grey.shade500,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentInfoStep() {
    return Column(
      children: [
        TextFormField(
          controller: _studentIdController,
          decoration: InputDecoration(
            labelText: 'Student ID',
            prefixIcon: Icon(Icons.badge, color: AppColors.primaryBlue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: (value) => value!.isEmpty ? 'Enter Student ID' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _studentNameController,
          decoration: InputDecoration(
            labelText: 'Student Name',
            prefixIcon: Icon(Icons.person, color: AppColors.primaryBlue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: (value) => value!.isEmpty ? 'Enter Student Name' : null,
        ),
      ],
    );
  }

  Widget _buildCourseStep() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Select Course',
            prefixIcon: Icon(Icons.school, color: AppColors.primaryBlue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          value: _selectedCourseId,
          items: _courses.map((course) {
            return DropdownMenuItem<String>(
              value: course.courseId,
              child: Text(course.courseName),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedCourseId = value),
          validator: (value) => value == null ? 'Select a course' : null,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primaryBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your modules and results will be automatically configured based on your selected course.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
