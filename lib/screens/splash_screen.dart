import 'package:flutter/material.dart';
import 'package:result_wave/screens/create_account_screen.dart';
import 'package:result_wave/screens/login_screen.dart';
import 'package:result_wave/screens/home_screen.dart';
import 'package:result_wave/services/auth_service.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/services/api_service.dart';
import 'package:result_wave/utils/constants.dart';
import 'package:result_wave/utils/animations.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  String _connectionStatus = 'Checking connection...';
  bool _isConnected = false;
  bool _checkComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
    _initializeAndNavigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeAndNavigate() async {
    // First check server connection
    await _checkServerConnection();

    if (!_checkComplete) return;

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    if (!_isConnected) {
      // Show error and stay on splash with retry option
      setState(() {});
      return;
    }

    final isLoggedIn = await _authService.isLoggedIn();

    if (isLoggedIn) {
      final studentId = await _authService.getCurrentStudentId();
      final students = await DatabaseService().getStudents();
      final existingStudent = students.any((s) => s.studentId == studentId);

      if (existingStudent && studentId != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(studentId: studentId),
          ),
        );
      } else {
        await _authService.clearLoginData();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    } else {
      final students = await DatabaseService().getStudents();
      if (students.isEmpty && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CreateAccountScreen()),
        );
      } else if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    }
  }

  Future<void> _checkServerConnection() async {
    setState(() {
      _connectionStatus = 'Connecting to server...';
    });

    final result = await _apiService.testConnection();

    setState(() {
      if (result['success']) {
        _isConnected = true;
        _connectionStatus = '✓ Server connected';
        _checkComplete = true;
      } else {
        _isConnected = false;
        _connectionStatus = '✗ Server connection failed';
        _checkComplete = true;
      }
    });
  }

  Future<void> _retryConnection() async {
    setState(() {
      _checkComplete = false;
      _connectionStatus = 'Retrying connection...';
    });

    await _checkServerConnection();

    if (_isConnected && mounted) {
      await _initializeAndNavigate();
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.primary),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Opacity(
                              opacity: _fadeAnimation.value,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.waves,
                                  size: 60,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeAnimation.value,
                            child: const Text(
                              'ResultWave',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeAnimation.value,
                            child: Text(
                              'Academic Excellence Tracker',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                                letterSpacing: 0.5,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Connection Status at Bottom
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Retry button if connection failed
                    if (_checkComplete && !_isConnected)
                      ElevatedButton(
                        onPressed: _retryConnection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh, size: 18),
                            SizedBox(width: 8),
                            Text('Retry Connection'),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Connection Status Text
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _isConnected
                                  ? AppColors.success.withOpacity(0.2)
                                  : (_checkComplete
                                        ? AppColors.error.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isConnected
                                      ? Icons.check_circle
                                      : (_checkComplete
                                            ? Icons.error
                                            : Icons.hourglass_empty),
                                  size: 14,
                                  color: _isConnected
                                      ? AppColors.success
                                      : (_checkComplete
                                            ? AppColors.error
                                            : Colors.white70),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _connectionStatus,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _isConnected
                                        ? AppColors.success
                                        : (_checkComplete
                                              ? AppColors.error
                                              : Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Loading indicator while checking
                    if (!_checkComplete || (!_isConnected && _checkComplete))
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeAnimation.value,
                            child: Container(
                              width: 40,
                              height: 40,
                              child: const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
