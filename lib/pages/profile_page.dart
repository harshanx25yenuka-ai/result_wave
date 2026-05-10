import 'package:flutter/material.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/models/avatar.dart';
import 'package:result_wave/models/course.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/services/avatar_cache_service.dart';
import 'package:result_wave/services/auth_service.dart';
import 'package:result_wave/screens/login_screen.dart';
import 'package:result_wave/utils/constants.dart';
import 'package:result_wave/utils/animations.dart';
import 'package:result_wave/widgets/glass_card.dart';

class ProfilePage extends StatefulWidget {
  final String studentId;

  const ProfilePage({Key? key, required this.studentId}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Student? _student;
  String? _courseName;
  List<Avatar> _avatars = [];
  int? _selectedAvatarId;
  bool _isLoading = true;
  bool _isUpdatingAvatar = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final students = await DatabaseService().getStudents();
      _student = students.firstWhere((s) => s.studentId == widget.studentId);

      final courses = await DatabaseService().getCourses();
      final course = courses.firstWhere(
        (c) => c.courseId == _student!.courseId,
      );
      _courseName = course.courseName;

      final avatars = await DatabaseService().getAvatars();
      _avatars = avatars;

      final cachedAvatarId = await AvatarCacheService.getAvatar(
        widget.studentId,
      );
      if (cachedAvatarId != null) {
        setState(() {
          _selectedAvatarId = cachedAvatarId;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAvatar(int? avatarId) async {
    setState(() => _isUpdatingAvatar = true);

    try {
      await AvatarCacheService.saveAvatar(widget.studentId, avatarId);

      setState(() {
        _selectedAvatarId = avatarId;
      });

      _showMessage('Avatar updated successfully!', isError: false);
    } catch (e) {
      _showMessage('Error updating avatar: $e', isError: true);
    } finally {
      setState(() => _isUpdatingAvatar = false);
    }
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Choose Avatar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a profile picture for your account',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1,
                          ),
                      itemCount: _avatars.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final isSelected = _selectedAvatarId == null;
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _updateAvatar(null);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryBlue
                                      : Colors.grey.shade300,
                                  width: 3,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primaryBlue
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: ClipOval(
                                child: Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final avatar = _avatars[index - 1];
                        final isSelected = _selectedAvatarId == avatar.id;
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _updateAvatar(avatar.id);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primaryBlue
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                avatar.avatarPath,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(
                                      Icons.person,
                                      size: 30,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? AppGradients.darkBackgroundGradient
            : AppGradients.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Profile'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          _buildProfileAvatar(),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isUpdatingAvatar
                                  ? null
                                  : _showAvatarPicker,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: AppGradients.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                                child: _isUpdatingAvatar
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _student?.studentName ?? '',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _student?.studentId ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      GlassCard(
                        child: Column(
                          children: [
                            _buildInfoTile(
                              icon: Icons.school,
                              label: 'Course',
                              value: _courseName ?? '',
                              color: AppColors.primaryBlue,
                              isDark: isDark,
                            ),
                            const Divider(),
                            _buildInfoTile(
                              icon: Icons.date_range,
                              label: 'Enrolled Year',
                              value: _getEnrolledYear(),
                              color: AppColors.accentTeal,
                              isDark: isDark,
                            ),
                            const Divider(),
                            _buildInfoTile(
                              icon: Icons.people,
                              label: 'Batch',
                              value: _getBatch(),
                              color: AppColors.accentPurple,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      GlassCard(
                        child: Column(
                          children: [
                            _buildInfoTile(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: _generateEmail(),
                              color: AppColors.info,
                              isDark: isDark,
                            ),
                            const Divider(),
                            _buildInfoTile(
                              icon: Icons.phone_outlined,
                              label: 'Phone',
                              value: '+94 XX XXX XXXX',
                              color: AppColors.warning,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified,
                              size: 16,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Member since ${DateTime.now().year}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
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
    );
  }

  Widget _buildProfileAvatar() {
    final selectedAvatar = _avatars.firstWhere(
      (a) => a.id == _selectedAvatarId,
      orElse: () => Avatar(id: 0, avatarPath: ''),
    );

    if (_selectedAvatarId != null && selectedAvatar.avatarPath.isNotEmpty) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            selectedAvatar.avatarPath,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade300,
                child: Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.grey.shade600,
                ),
              );
            },
          ),
        ),
      );
    } else {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            _student?.studentName.isNotEmpty == true
                ? _student!.studentName[0].toUpperCase()
                : 'U',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _generateEmail() {
    final studentId = _student?.studentId ?? '';
    final cleanId = studentId.replaceAll('/', '').toLowerCase();
    return '$cleanId@uovt.ac.lk';
  }

  String _getEnrolledYear() {
    final studentId = _student?.studentId ?? '';
    if (studentId.contains('/') && studentId.split('/').length > 1) {
      final yearPart = studentId.split('/')[1];
      if (yearPart.length >= 2) {
        return '20${yearPart.substring(0, 2)}';
      }
    }
    return 'Not specified';
  }

  String _getBatch() {
    final studentId = _student?.studentId ?? '';
    if (studentId.contains('/') && studentId.split('/').length > 2) {
      final batchPart = studentId.split('/')[2];
      return batchPart;
    }
    return 'Not specified';
  }
}
