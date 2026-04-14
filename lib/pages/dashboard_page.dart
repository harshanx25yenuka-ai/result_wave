import 'package:flutter/material.dart';
import 'package:result_wave/models/module.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/models/grade.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/services/database_service.dart';
import 'dart:math' as math;

class DashboardPage extends StatefulWidget {
  final String studentId;

  DashboardPage({required this.studentId});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  int _numModules = 0;
  int _numSemesters = 0;
  Map<int, double> _semesterGPAs = {};
  Map<int, int> _semesterCredits = {};
  double _courseGPA = 0.0;
  List<String> _suggestions = [];

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _rotationController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadData();
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
  }

  Future<void> _loadData() async {
    Student student = (await DatabaseService().getStudents()).firstWhere(
      (s) => s.studentId == widget.studentId,
    );
    List<Module> modules = await DatabaseService().getModulesByCourse(
      student.courseId,
    );
    List<Result> results = await DatabaseService().getResults();
    List<Grade> grades = await DatabaseService().getGrades();

    Map<int, double> semesterGPAs = {};
    Map<int, int> semesterCredits = {};
    Map<int, List<Module>> semesterModules = {};

    for (var module in modules) {
      semesterModules.putIfAbsent(module.semester, () => []).add(module);
    }

    for (var semester in semesterModules.keys) {
      int totalCredits = 0;
      double totalPoints = 0.0;
      bool hasResults = false;

      for (var module in semesterModules[semester]!) {
        totalCredits += module.credits;
        var result = results.firstWhere(
          (r) => r.moduleId == module.moduleId,
          orElse: () => Result(moduleId: module.moduleId, grade: 'N/A'),
        );
        var grade = grades.firstWhere(
          (g) => g.grade == result.grade,
          orElse: () => Grade(grade: 'N/A', gradePoint: 0.0, status: ''),
        );
        if (result.grade != 'N/A') {
          totalPoints += grade.gradePoint * module.credits;
          hasResults = true;
        }
      }

      if (hasResults) {
        semesterGPAs[semester] = totalCredits > 0
            ? totalPoints / totalCredits
            : 0.0;
        semesterCredits[semester] = totalCredits;
      }
    }

    double totalSemesterPoints = 0.0;
    int totalSemesterCredits = 0;
    for (var semester in semesterGPAs.keys) {
      totalSemesterPoints +=
          semesterGPAs[semester]! * semesterCredits[semester]!;
      totalSemesterCredits += semesterCredits[semester]!;
    }
    double courseGPA = totalSemesterCredits > 0
        ? totalSemesterPoints / totalSemesterCredits
        : 0.0;

    List<String> suggestions = [];
    for (var semester in semesterGPAs.keys) {
      if (semesterGPAs[semester]! < 2.0) {
        suggestions.add(
          'Improve grades in Semester $semester to reach GPA of 2.0 or higher.',
        );
      }
    }
    if (courseGPA < 2.0) {
      suggestions.add(
        'Improve overall grades to reach Course GPA of 2.0 or higher.',
      );
    }
    for (var result in results) {
      var grade = grades.firstWhere(
        (g) => g.grade == result.grade,
        orElse: () => Grade(grade: 'N/A', gradePoint: 0.0, status: ''),
      );
      if ([
        'F',
        'F(CA)',
        'F(ET)',
        'I',
        'I(ET)',
        'I(CA)',
      ].contains(result.grade)) {
        suggestions.add('Upgrade ${result.moduleId} to at least C.');
      }
    }

    setState(() {
      _numModules = modules.length;
      _numSemesters = semesterModules.keys.length;
      _semesterGPAs = semesterGPAs;
      _semesterCredits = semesterCredits;
      _courseGPA = courseGPA;
      _suggestions = suggestions;
    });

    // Start animations
    _fadeController.forward();
    _scaleController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _rotationController.dispose();
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
      padding: padding ?? EdgeInsets.all(20),
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    int delay = 0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + delay),
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, animation, child) {
        return Transform.scale(
          scale: animation,
          child: _buildGlassmorphicCard(
            height: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGPAIndicator() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return _buildGlassmorphicCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overall GPA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Transform.rotate(
                    angle: _rotationAnimation.value,
                    child: Icon(
                      Icons.auto_graph,
                      color: Colors.cyanAccent,
                      size: 24,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Container(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.cyanAccent.withOpacity(0.3),
                            Colors.blueAccent.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                    CircularProgressIndicator(
                      value: _courseGPA / 4.0,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _courseGPA >= 3.0
                            ? Colors.greenAccent
                            : _courseGPA >= 2.0
                            ? Colors.orangeAccent
                            : Colors.redAccent,
                      ),
                    ),
                    Text(
                      _courseGPA.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSemesterGPAs() {
    return _buildGlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: Colors.purpleAccent, size: 24),
              SizedBox(width: 12),
              Text(
                'Semester Performance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          ..._semesterGPAs.entries.map((entry) {
            double gpaPercentage = entry.value / 4.0;
            return Container(
              margin: EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Semester ${entry.key}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${entry.value.toStringAsFixed(2)} (${_semesterCredits[entry.key]} credits)',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: gpaPercentage,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: entry.value >= 3.0
                                ? [Colors.greenAccent, Colors.green]
                                : entry.value >= 2.0
                                ? [Colors.orangeAccent, Colors.orange]
                                : [Colors.redAccent, Colors.red],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return _buildGlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.amberAccent,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'AI Suggestions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          if (_suggestions.isEmpty)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Colors.greenAccent.withOpacity(0.2),
                    Colors.green.withOpacity(0.1),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.greenAccent,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Great job! You\'re performing well across all areas.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._suggestions.asMap().entries.map((entry) {
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 600 + (entry.key * 200)),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: -50, end: 0),
                builder: (context, animation, child) {
                  return Transform.translate(
                    offset: Offset(animation, 0),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            Colors.orangeAccent.withOpacity(0.2),
                            Colors.orange.withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: Colors.orangeAccent,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
        ],
      ),
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
                          'Dashboard',
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
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            // Stats Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'Modules',
                                    value: '$_numModules',
                                    icon: Icons.book_outlined,
                                    color: Colors.blueAccent,
                                    delay: 0,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'Semesters',
                                    value: '$_numSemesters',
                                    icon: Icons.calendar_today,
                                    color: Colors.purpleAccent,
                                    delay: 200,
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 20),

                            // GPA Indicator
                            _buildGPAIndicator(),

                            SizedBox(height: 20),

                            // Semester GPAs
                            if (_semesterGPAs.isNotEmpty) _buildSemesterGPAs(),

                            SizedBox(height: 20),

                            // Suggestions
                            _buildSuggestions(),

                            SizedBox(height: 20),
                          ],
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
