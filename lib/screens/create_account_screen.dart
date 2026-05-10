import 'package:flutter/material.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/models/course.dart';
import 'package:result_wave/models/module.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/models/avatar.dart';
import 'package:result_wave/screens/login_screen.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/services/supabase_service.dart';
import 'package:result_wave/utils/constants.dart';
import 'package:result_wave/utils/animations.dart';
import 'package:result_wave/widgets/glass_card.dart';
import 'package:flutter/services.dart';

class CreateAccountScreen extends StatefulWidget {
  @override
  _CreateAccountScreenState createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _studentNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedCourseId;
  List<Course> _courses = [];
  List<Avatar> _avatars = [];
  int? _selectedAvatarId;
  bool _isLoading = true;
  bool _isCreating = false;
  late AnimationController _controller;
  int _currentStep = 0;

  String _detectedCourse = '';
  bool _isIdValid = false;
  String _idError = '';

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _hasCapital = false;
  bool _hasLower = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;
  bool _hasMinLength = false;

  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _loadData();

    _studentIdController.addListener(_validateAndDetectCourse);
    _passwordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _controller.dispose();
    _studentIdController.dispose();
    _studentNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _studentIdController.removeListener(_validateAndDetectCourse);
    _passwordController.removeListener(_validatePassword);
    super.dispose();
  }

  void _validatePassword() {
    final password = _passwordController.text;
    setState(() {
      _hasCapital = password.contains(RegExp(r'[A-Z]'));
      _hasLower = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecial = password.contains(RegExp(r'[#\$%@_]'));
      _hasMinLength = password.length >= 8;
    });
  }

  bool get _isPasswordValid {
    return _hasCapital &&
        _hasLower &&
        _hasNumber &&
        _hasSpecial &&
        _hasMinLength;
  }

  void _validateAndDetectCourse() {
    final text = _studentIdController.text;

    if (text.trim().isEmpty) {
      _isIdValid = false;
      _detectedCourse = '';
      _idError = '';
      setState(() {});
      return;
    }

    final error = Student.validateStudentId(text);

    if (error == null) {
      _isIdValid = true;
      _idError = '';
      final prefix = Student.getCoursePrefixFromId(text);
      _detectedCourse = Student.getCourseNameFromPrefix(prefix);
    } else {
      _isIdValid = false;
      _detectedCourse = '';
      _idError = error;
    }
    setState(() {});
  }

  Future<void> _loadData() async {
    try {
      await DatabaseService().loadJsonData();
      final courses = await DatabaseService().getCourses();
      final avatars = await DatabaseService().getAvatars();
      setState(() {
        _courses = courses;
        _avatars = avatars;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Error loading data: $e', isError: true);
    }
  }

  Future<void> _createAccount() async {
    final studentId = _studentIdController.text.trim().toUpperCase();
    final studentName = _studentNameController.text.trim().toUpperCase();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final idError = Student.validateStudentId(studentId);
    if (idError != null) {
      _showMessage(idError, isError: true);
      return;
    }

    if (!_isPasswordValid) {
      _showMessage('Please meet all password requirements', isError: true);
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match', isError: true);
      return;
    }

    if (_formKey.currentState!.validate()) {
      final prefix = Student.getCoursePrefixFromId(studentId);
      final courseIdFromPrefix = Student.getCourseIdFromPrefix(prefix);

      if (courseIdFromPrefix.isEmpty) {
        _showMessage(
          'Invalid student ID format. Cannot determine course.',
          isError: true,
        );
        return;
      }

      final matchedCourse = _courses.firstWhere(
        (c) => c.courseId == courseIdFromPrefix,
        orElse: () =>
            throw Exception('No matching course found for prefix $prefix'),
      );

      setState(() {
        _selectedCourseId = matchedCourse.courseId;
        _isCreating = true;
      });

      try {
        // First, check if user exists in Supabase
        final userExists = await _supabaseService.userExists(studentId);

        if (!userExists) {
          // Create user in Supabase
          final result = await _supabaseService.createUser(
            studentId: studentId,
            studentName: studentName,
            courseId: _selectedCourseId!,
            password: password,
            avatarId: _selectedAvatarId,
          );

          if (!result['success']) {
            _showMessage(result['error'], isError: true);
            setState(() => _isCreating = false);
            return;
          }
        }

        // Create local student record
        final existingLocalStudent = await DatabaseService().getStudents();
        if (!existingLocalStudent.any((s) => s.studentId == studentId)) {
          await DatabaseService().insertStudent(
            Student(
              studentId: studentId,
              studentName: studentName,
              courseId: _selectedCourseId!,
            ),
          );
        }

        // Create default results for modules
        List<Module> modules = await DatabaseService().getModulesByCourse(
          _selectedCourseId!,
        );
        for (var module in modules) {
          final existingResults = await DatabaseService().getResults();
          if (!existingResults.any((r) => r.moduleId == module.moduleId)) {
            await DatabaseService().insertResult(
              Result(moduleId: module.moduleId, grade: 'N/A'),
            );
          }
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

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _navigateToLogin,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.login,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Login',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                                if (_currentStep == 0)
                                  _buildStudentInfoStep(isDark),
                                if (_currentStep == 1) _buildAvatarStep(isDark),
                                if (_currentStep == 2)
                                  _buildPasswordStep(isDark),
                                if (_currentStep == 3) _buildCourseInfo(isDark),
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
                                                if (_currentStep == 3) {
                                                  _createAccount();
                                                } else {
                                                  if (_currentStep == 0) {
                                                    if (_studentIdController
                                                        .text
                                                        .trim()
                                                        .isEmpty) {
                                                      _showMessage(
                                                        'Please enter Student ID',
                                                        isError: true,
                                                      );
                                                    } else if (!_isIdValid) {
                                                      _showMessage(
                                                        _idError.isEmpty
                                                            ? 'Please enter a valid Student ID'
                                                            : _idError,
                                                        isError: true,
                                                      );
                                                    } else if (_studentNameController
                                                        .text
                                                        .trim()
                                                        .isEmpty) {
                                                      _showMessage(
                                                        'Please enter Student Name',
                                                        isError: true,
                                                      );
                                                    } else {
                                                      setState(
                                                        () => _currentStep++,
                                                      );
                                                    }
                                                  } else if (_currentStep ==
                                                      2) {
                                                    if (!_isPasswordValid) {
                                                      _showMessage(
                                                        'Please meet all password requirements',
                                                        isError: true,
                                                      );
                                                    } else if (_passwordController
                                                            .text !=
                                                        _confirmPasswordController
                                                            .text) {
                                                      _showMessage(
                                                        'Passwords do not match',
                                                        isError: true,
                                                      );
                                                    } else {
                                                      setState(
                                                        () => _currentStep++,
                                                      );
                                                    }
                                                  } else {
                                                    setState(
                                                      () => _currentStep++,
                                                    );
                                                  }
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
                                                _currentStep == 3
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
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.info.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.info.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Already have an account? ',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _navigateToLogin,
                                        child: Text(
                                          'Sign In',
                                          style: TextStyle(
                                            color: AppColors.info,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
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
        _buildStepCircle(1, 'Avatar'),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep >= 2
                ? AppColors.primaryBlue
                : Colors.grey.shade300,
          ),
        ),
        _buildStepCircle(2, 'Password'),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep >= 3
                ? AppColors.primaryBlue
                : Colors.grey.shade300,
          ),
        ),
        _buildStepCircle(3, 'Verify'),
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

  Widget _buildStudentInfoStep(bool isDark) {
    return Column(
      children: [
        TextFormField(
          controller: _studentIdController,
          decoration: InputDecoration(
            labelText: 'Student ID',
            helperText: 'Format: XXX/XX/BX/XX (SOF, MMW, or NET)',
            prefixIcon: Icon(Icons.badge, color: AppColors.primaryBlue),
            suffixIcon: _isIdValid
                ? Icon(Icons.check_circle, color: AppColors.success)
                : (_studentIdController.text.trim().isNotEmpty
                      ? Icon(Icons.error, color: AppColors.error)
                      : null),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
            errorText:
                _studentIdController.text.trim().isNotEmpty &&
                    !_isIdValid &&
                    _idError.isNotEmpty
                ? _idError
                : null,
          ),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9/]')),
          ],
        ),
        const SizedBox(height: 12),
        if (_detectedCourse.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified, color: AppColors.success, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valid Student ID',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      Text(
                        'Course: $_detectedCourse',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
            fillColor: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter Student Name'
              : null,
        ),
      ],
    );
  }

  Widget _buildAvatarStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Profile Avatar',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Select an avatar for your profile (optional)',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _avatars.length,
            itemBuilder: (context, index) {
              final avatar = _avatars[index];
              final isSelected = _selectedAvatarId == avatar.id;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAvatarId = avatar.id;
                  });
                },
                child: Container(
                  width: 90,
                  height: 90,
                  margin: const EdgeInsets.only(right: 16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipOval(
                        child: Image.asset(
                          avatar.avatarPath,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 90,
                              height: 90,
                              color: Colors.grey.shade300,
                              child: const Icon(
                                Icons.person,
                                size: 45,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryBlue,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryBlue.withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      if (isSelected)
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You can change your avatar later in Settings.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep(bool isDark) {
    return Column(
      children: [
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock, color: AppColors.primaryBlue),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
            fillColor: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (_isPasswordValid ? AppColors.success : AppColors.warning)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (_isPasswordValid ? AppColors.success : AppColors.warning)
                  .withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Password Requirements:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              _buildRequirementTile('At least 8 characters', _hasMinLength),
              _buildRequirementTile('Capital letter (A-Z)', _hasCapital),
              _buildRequirementTile('Simple letter (a-z)', _hasLower),
              _buildRequirementTile('Number (0-9)', _hasNumber),
              _buildRequirementTile(
                'Special character (#, \$, _, @)',
                _hasSpecial,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: Icon(Icons.lock_outline, color: AppColors.primaryBlue),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: AppColors.primaryBlue,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementTile(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isValid ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isValid ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseInfo(bool isDark) {
    final studentId = _studentIdController.text.trim().toUpperCase();
    final prefix = Student.getCoursePrefixFromId(studentId);
    final batch = Student.getBatchFromId(studentId);
    final courseName = Student.getCourseNameFromPrefix(prefix);
    String courseDescription;

    switch (prefix) {
      case 'SOF':
        courseDescription =
            'Focus on software development, architecture, enterprise systems, and application programming';
        break;
      case 'MMW':
        courseDescription =
            'Focus on multimedia design, animation, video production, and web technologies';
        break;
      case 'NET':
        courseDescription =
            'Focus on network infrastructure, security protocols, and system administration';
        break;
      default:
        courseDescription =
            'Please enter a valid Student ID with SOF, MMW, or NET prefix';
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppGradients.successGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(Icons.verified, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              Text(
                'Account Ready!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.badge,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Student ID',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          studentId,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.school,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Course',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          courseName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (batch.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.people,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Batch',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            batch,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.info, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        courseDescription,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
