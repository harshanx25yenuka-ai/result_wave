import 'package:flutter/material.dart';
import 'package:result_wave/models/module.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/screens/home_screen.dart';
import 'package:result_wave/screens/create_account_screen.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/services/auth_service.dart';
import 'package:result_wave/services/supabase_service.dart';
import 'package:result_wave/utils/constants.dart';
import 'package:result_wave/utils/animations.dart';
import 'package:result_wave/widgets/glass_card.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoggingIn = false;
  bool _obscurePassword = true;
  late AnimationController _controller;
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRestoreBackup(String studentId) async {
    try {
      final latestBackup = await _supabaseService.getLatestBackup(studentId);

      if (latestBackup.isNotEmpty) {
        final db = await DatabaseService().database;
        final restored = await _supabaseService.restoreBackup(
          latestBackup['id'],
          db,
        );

        if (restored) {
          _showMessage('Latest backup restored successfully!', isError: false);
        }
      }
    } catch (e) {
      print('Backup restore error: $e');
    }
  }

  void _login() async {
    final studentId = _studentIdController.text.trim().toUpperCase();
    final password = _passwordController.text;

    if (studentId.isEmpty) {
      _showMessage('Please enter Student ID', isError: true);
      return;
    }
    if (password.isEmpty) {
      _showMessage('Please enter Password', isError: true);
      return;
    }

    setState(() => _isLoggingIn = true);

    try {
      final result = await _supabaseService.loginUser(
        studentId: studentId,
        password: password,
      );

      if (!result['success']) {
        _showMessage(result['error'], isError: true);
        setState(() => _isLoggingIn = false);
        return;
      }

      final students = await DatabaseService().getStudents();
      var student = students.firstWhere(
        (s) => s.studentId == studentId,
        orElse: () => Student(
          studentId: studentId,
          studentName: result['user']['student_name'],
          courseId: result['user']['course_id'],
        ),
      );

      if (!students.any((s) => s.studentId == studentId)) {
        await DatabaseService().insertStudent(student);

        List<Module> modules = await DatabaseService().getModulesByCourse(
          student.courseId,
        );
        for (var module in modules) {
          await DatabaseService().insertResult(
            Result(moduleId: module.moduleId, grade: 'N/A'),
          );
        }
      }

      await _checkAndRestoreBackup(studentId);
      await _authService.setLoggedIn(studentId);

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(studentId: studentId),
        ),
      );
    } catch (e) {
      _showMessage('Login error: $e', isError: true);
      setState(() => _isLoggingIn = false);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppGradients.darkBackgroundGradient
              : AppGradients.primary,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                FadeInAnimation(
                  child: Container(
                    width: 90,
                    height: 90,
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
                      Icons.waves,
                      size: 45,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FadeInAnimation(
                  delay: 100,
                  child: const Text(
                    'Welcome Back!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeInAnimation(
                  delay: 150,
                  child: Text(
                    'Sign in to continue your journey',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                FadeInAnimation(
                  delay: 200,
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Student ID',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _studentIdController,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.badge,
                              color: AppColors.primaryBlue,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.surfaceDark
                                : Colors.grey.shade50,
                          ),
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.lock,
                              color: AppColors.primaryBlue,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppColors.primaryBlue,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.surfaceDark
                                : Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoggingIn ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoggingIn
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CreateAccountScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Create Account',
                                style: TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
