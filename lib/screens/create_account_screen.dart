import 'package:flutter/material.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/models/course.dart';
import 'package:result_wave/models/module.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/screens/login_screen.dart';
import 'package:result_wave/services/database_service.dart';
import 'dart:math' as math;

class CreateAccountScreen extends StatefulWidget {
  @override
  _CreateAccountScreenState createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String _studentId = '';
  String _studentName = '';
  String? _selectedCourseId;
  List<Course> _courses = [];
  bool _isLoading = false;
  bool _isCreatingAccount = false;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _rotationController;
  late AnimationController _buttonController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadCourses();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _buttonController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_rotationController);

    _buttonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
    });

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

      // Start animations after loading
      _fadeController.forward();
      _scaleController.forward();
      _slideController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error loading courses: $e', isError: true);
    }
  }

  Future<void> _createAccount() async {
    if (_formKey.currentState!.validate() && _selectedCourseId != null) {
      setState(() {
        _isCreatingAccount = true;
      });

      // Button press animation
      _buttonController.forward().then((_) {
        _buttonController.reverse();
      });

      try {
        await DatabaseService().insertStudent(
          Student(
            studentId: _studentId.toUpperCase(),
            studentName: _studentName.toUpperCase(),
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

        setState(() {
          _isCreatingAccount = false;
        });

        _showSnackBar('Account created successfully!', isError: false);

        // Delay navigation to show success message
        await Future.delayed(Duration(milliseconds: 1500));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      } catch (e) {
        setState(() {
          _isCreatingAccount = false;
        });
        _showSnackBar('Error creating account: $e', isError: true);
      }
    } else {
      _showSnackBar(
        'Please fill all fields and select a course',
        isError: true,
      );
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? Colors.redAccent.withOpacity(0.9)
            : Colors.greenAccent.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _rotationController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  Widget _buildGlassmorphicCard({
    required Widget child,
    double? height,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      height: height,
      margin: margin ?? EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      padding: padding ?? EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildGlassmorphicTextField({
    required String label,
    required Function(String) onChanged,
    required String? Function(String?) validator,
    IconData? prefixIcon,
    int delay = 0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: -50, end: 0),
      builder: (context, animation, child) {
        return Transform.translate(
          offset: Offset(0, animation),
          child: Container(
            margin: EdgeInsets.only(bottom: 20),
            child: TextFormField(
              style: TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: prefixIcon != null
                    ? Icon(prefixIcon, color: Colors.cyanAccent, size: 20)
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.cyanAccent, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.redAccent, width: 2),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.redAccent, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
              validator: validator,
              onChanged: onChanged,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassmorphicDropdown() {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: -50, end: 0),
      builder: (context, animation, child) {
        return Transform.translate(
          offset: Offset(0, animation),
          child: Container(
            margin: EdgeInsets.only(bottom: 32),
            child: DropdownButtonFormField<String>(
              style: TextStyle(color: Colors.white, fontSize: 16),
              dropdownColor: Color(0xFF1a1a2e),
              decoration: InputDecoration(
                labelText: 'Course',
                labelStyle: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(
                  Icons.school,
                  color: Colors.purpleAccent,
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.purpleAccent, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
              value: _selectedCourseId,
              items: _courses.map((course) {
                return DropdownMenuItem<String>(
                  value: course.courseId,
                  child: Text(
                    course.courseName,
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCourseId = value;
                });
              },
              validator: (value) =>
                  value == null ? 'Please select a course' : null,
              hint: Text(
                _courses.isEmpty ? 'Loading courses...' : 'Select a Course',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateButton() {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 1000),
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, animation, child) {
        return Transform.scale(
          scale: animation,
          child: ScaleTransition(
            scale: _buttonScale,
            child: Container(
              width: double.infinity,
              height: 56,
              margin: EdgeInsets.symmetric(vertical: 8),
              child: ElevatedButton(
                onPressed: _isCreatingAccount ? null : _createAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: _isCreatingAccount
                          ? [
                              Colors.grey.withOpacity(0.5),
                              Colors.grey.withOpacity(0.3),
                            ]
                          : [Colors.cyanAccent, Colors.blueAccent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withOpacity(0.3),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isCreatingAccount
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Creating Account...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_add,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return _buildGlassmorphicCard(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Transform.rotate(
                angle: _rotationAnimation.value,
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.cyanAccent.withOpacity(0.8),
                        Colors.blueAccent.withOpacity(0.6),
                      ],
                    ),
                  ),
                  child: Icon(Icons.person_add, color: Colors.white, size: 40),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Join Result Wave to track your academic progress',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Welcome',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Container(width: 44), // Balance the back button
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                              ),
                              child: CircularProgressIndicator(
                                color: Colors.cyanAccent,
                                strokeWidth: 3,
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              'Loading courses...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    // Welcome Header
                                    _buildWelcomeHeader(),

                                    SizedBox(height: 32),

                                    // Form Card
                                    _buildGlassmorphicCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Account Details',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 24),

                                          _buildGlassmorphicTextField(
                                            label: 'Student ID',
                                            prefixIcon: Icons.badge,
                                            onChanged: (value) =>
                                                _studentId = value,
                                            validator: (value) => value!.isEmpty
                                                ? 'Please enter Student ID'
                                                : null,
                                            delay: 0,
                                          ),

                                          _buildGlassmorphicTextField(
                                            label: 'Student Name',
                                            prefixIcon: Icons.person,
                                            onChanged: (value) =>
                                                _studentName = value,
                                            validator: (value) => value!.isEmpty
                                                ? 'Please enter Student Name'
                                                : null,
                                            delay: 200,
                                          ),

                                          _buildGlassmorphicDropdown(),

                                          _buildCreateButton(),
                                        ],
                                      ),
                                    ),

                                    SizedBox(height: 32),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
