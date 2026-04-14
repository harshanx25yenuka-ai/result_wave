import 'package:flutter/material.dart';
import 'package:result_wave/screens/create_account_screen.dart';
import 'package:result_wave/screens/login_screen.dart';
import 'package:result_wave/services/database_service.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _waveController;
  late AnimationController _particleController;

  late Animation<double> _logoAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _particleAnimation;

  String _loadingText = 'Initializing...';
  List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _generateParticles();
    _startAnimations();
    _navigate();
  }

  void _setupAnimations() {
    _logoController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 1800),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: Duration(seconds: 8),
      vsync: this,
    )..repeat();
    _waveController = AnimationController(
      duration: Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
    _particleController = AnimationController(
      duration: Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_rotationController);

    _waveAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    _particleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_particleController);
  }

  void _generateParticles() {
    _particles = List.generate(20, (index) {
      return Particle(
        x: math.Random().nextDouble(),
        y: math.Random().nextDouble(),
        speed: 0.5 + math.Random().nextDouble() * 0.5,
        size: 2 + math.Random().nextDouble() * 3,
        opacity: 0.3 + math.Random().nextDouble() * 0.4,
      );
    });
  }

  void _startAnimations() async {
    await Future.delayed(Duration(milliseconds: 300));
    _fadeController.forward();

    await Future.delayed(Duration(milliseconds: 500));
    _scaleController.forward();

    await Future.delayed(Duration(milliseconds: 200));
    _logoController.forward();
  }

  Future<void> _navigate() async {
    // Update loading text with delays
    await Future.delayed(Duration(milliseconds: 1000));
    setState(() {
      _loadingText = 'Loading database...';
    });

    await Future.delayed(Duration(milliseconds: 1000));
    setState(() {
      _loadingText = 'Checking students...';
    });

    final students = await DatabaseService().getStudents();

    await Future.delayed(Duration(milliseconds: 800));
    setState(() {
      _loadingText = 'Ready!';
    });

    await Future.delayed(Duration(milliseconds: 500));

    if (students.isEmpty) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              CreateAccountScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      ),
                    ),
                child: child,
              ),
            );
          },
          transitionDuration: Duration(milliseconds: 800),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      ),
                    ),
                child: child,
              ),
            );
          },
          transitionDuration: Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _logoAnimation,
        _rotationAnimation,
        _waveAnimation,
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: _logoAnimation.value,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.cyanAccent.withOpacity(0.9),
                  Colors.blueAccent.withOpacity(0.7),
                  Colors.purpleAccent.withOpacity(0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.4),
                  blurRadius: 30,
                  offset: Offset(0, 15),
                ),
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.3),
                  blurRadius: 60,
                  offset: Offset(0, 30),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Rotating outer ring
                Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),
                ),

                // Pulsing inner circle
                Transform.scale(
                  scale:
                      0.8 +
                      (0.2 * math.sin(_waveAnimation.value * 2 * math.pi)),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Main wave icon
                Transform.rotate(
                  angle: -_rotationAnimation.value * 0.5,
                  child: Icon(Icons.waves, color: Colors.white, size: 60),
                ),

                // Secondary icons
                Positioned(
                  top: 45,
                  child: Transform.rotate(
                    angle: _rotationAnimation.value * 2,
                    child: Icon(
                      Icons.auto_graph,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 45,
                  child: Transform.rotate(
                    angle: -_rotationAnimation.value * 1.5,
                    child: Icon(Icons.school, color: Colors.white70, size: 24),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBrandText() {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 30, end: 0),
      builder: (context, animation, child) {
        return Transform.translate(
          offset: Offset(0, animation),
          child: Column(
            children: [
              Text(
                'ResultWave',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2.0,
                  shadows: [
                    Shadow(
                      color: Colors.cyanAccent.withOpacity(0.5),
                      offset: Offset(0, 2),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Academic Excellence Tracker',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        Container(
          width: 200,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.1),
              ],
            ),
          ),
          child: AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _waveAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [
                        Colors.cyanAccent,
                        Colors.blueAccent,
                        Colors.purpleAccent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withOpacity(0.5),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 20),
        AnimatedSwitcher(
          duration: Duration(milliseconds: 500),
          child: Text(
            _loadingText,
            key: ValueKey(_loadingText),
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticleSystem() {
    return AnimatedBuilder(
      animation: _particleAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: ParticlePainter(_particles, _particleAnimation.value),
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
        child: Stack(
          children: [
            // Particle system background
            _buildParticleSystem(),

            // Main content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Logo
                        _buildAnimatedLogo(),

                        SizedBox(height: 60),

                        // Brand Text
                        _buildBrandText(),

                        SizedBox(height: 80),

                        // Loading Indicator
                        _buildLoadingIndicator(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Particle {
  double x;
  double y;
  final double speed;
  final double size;
  final double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;

  ParticlePainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      // Update particle position
      particle.y -= particle.speed * 0.002;
      if (particle.y < 0) {
        particle.y = 1.0;
        particle.x = math.Random().nextDouble();
      }

      final paint = Paint()
        ..color = Colors.cyanAccent.withOpacity(particle.opacity * 0.6)
        ..style = PaintingStyle.fill;

      final center = Offset(particle.x * size.width, particle.y * size.height);

      canvas.drawCircle(center, particle.size, paint);

      // Add glow effect
      final glowPaint = Paint()
        ..color = Colors.cyanAccent.withOpacity(particle.opacity * 0.2)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, particle.size * 2, glowPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
