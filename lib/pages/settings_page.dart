import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/models/avatar.dart';
import 'package:result_wave/providers/theme_provider.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/services/pdf_service.dart';
import 'package:result_wave/services/supabase_service.dart';
import 'package:result_wave/services/auth_service.dart';
import 'package:result_wave/screens/login_screen.dart';
import 'package:result_wave/utils/constants.dart';
import 'package:result_wave/utils/animations.dart';
import 'package:result_wave/widgets/glass_card.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class SettingsPage extends StatefulWidget {
  final String studentId;

  const SettingsPage({Key? key, required this.studentId}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  Student? _student;
  List<int> _semesters = [];
  int? _selectedSemester;
  bool _isLoading = true;
  bool _isExporting = false;
  late AnimationController _animationController;

  bool _isBackingUp = false;
  bool _isRestoring = false;
  Map<String, dynamic>? _latestBackup;
  List<Map<String, dynamic>> _backupHistory = [];
  bool _isLoadingBackups = true;
  final SupabaseService _supabaseService = SupabaseService();
  final AuthService _authService = AuthService();

  List<Avatar> _avatars = [];
  int? _selectedAvatarId;
  bool _isUpdatingAvatar = false;
  String? _courseName;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
    _initSupabaseAndLoadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initSupabaseAndLoadData() async {
    try {
      await _supabaseService.initSupabase();
    } catch (e) {
      print('Supabase init error: $e');
    }

    // Load all data in parallel
    await Future.wait([
      _loadData(),
      _loadAvatars(),
      _loadUserAvatar(),
      _loadBackupInfo(),
    ]);

    setState(() {
      _isLoading = false;
      _isLoadingBackups = false;
    });
  }

  Future<void> _loadData() async {
    try {
      final students = await DatabaseService().getStudents();
      _student = students.firstWhere((s) => s.studentId == widget.studentId);

      final modules = await DatabaseService().getModulesByCourse(
        _student!.courseId,
      );
      _semesters = modules.map((m) => m.semester).toSet().toList()..sort();

      final courses = await DatabaseService().getCourses();
      final course = courses.firstWhere(
        (c) => c.courseId == _student!.courseId,
      );
      _courseName = course.courseName;
    } catch (e) {
      print('Load data error: $e');
    }
  }

  Future<void> _loadAvatars() async {
    try {
      final avatars = await DatabaseService().getAvatars();
      setState(() {
        _avatars = avatars;
      });
    } catch (e) {
      print('Error loading avatars: $e');
    }
  }

  Future<void> _loadUserAvatar() async {
    try {
      final result = await _supabaseService.getUserAvatar(widget.studentId);
      print('Load user avatar result: $result');

      if (result['success'] && result['avatarId'] != null) {
        setState(() {
          _selectedAvatarId = result['avatarId'];
        });
        print('Avatar loaded: $_selectedAvatarId');
      } else {
        print('No avatar found: ${result['error']}');
        setState(() {
          _selectedAvatarId = null;
        });
      }
    } catch (e) {
      print('Error loading user avatar: $e');
      setState(() {
        _selectedAvatarId = null;
      });
    }
  }

  Future<void> _loadBackupInfo() async {
    try {
      _latestBackup = await _supabaseService.getLatestBackup(widget.studentId);
      _backupHistory = await _supabaseService.getBackups(
        studentId: widget.studentId,
      );
      print('Backup history count: ${_backupHistory.length}');
    } catch (e) {
      print('Load backup info error: $e');
      _backupHistory = [];
      _latestBackup = null;
    }
  }

  Future<void> _updateAvatar(int? avatarId) async {
    setState(() => _isUpdatingAvatar = true);

    try {
      final result = await _supabaseService.updateUserAvatar(
        studentId: widget.studentId,
        avatarId: avatarId,
      );

      if (result['success']) {
        setState(() {
          _selectedAvatarId = avatarId;
        });
        _showMessage('Avatar updated successfully!', isError: false);
      } else {
        _showMessage(
          'Failed to update avatar: ${result['error']}',
          isError: true,
        );
      }
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
      builder: (context) => StatefulBuilder(
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
                            _updateAvatar(null);
                            Navigator.pop(context);
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
                          _updateAvatar(avatar.id);
                          Navigator.pop(context);
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
                                      color: AppColors.primaryBlue.withOpacity(
                                        0.3,
                                      ),
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
      ),
    );
  }

  Future<void> _createBackup() async {
    setState(() => _isBackingUp = true);

    try {
      final backupData = await _supabaseService.prepareBackupData(
        widget.studentId,
      );

      final result = await _supabaseService.createBackup(
        studentId: widget.studentId,
        studentName: _student?.studentName ?? '',
        courseId: _student?.courseId ?? '',
        backupData: backupData,
      );

      if (result['success']) {
        await _loadBackupInfo();

        final action = result['isUpdate'] == true ? 'updated' : 'created';
        final backupDate = result['backupDate'] as DateTime;
        final backupSize = result['backupSize'] as int;

        _showMessage(
          'Backup $action successfully!\nDate: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(backupDate)}\nSize: ${_supabaseService.formatFileSize(backupSize)}',
          isError: false,
        );
      } else {
        _showMessage('Backup failed: ${result['error']}', isError: true);
      }
    } catch (e) {
      _showMessage('Error creating backup: $e', isError: true);
    } finally {
      setState(() => _isBackingUp = false);
    }
  }

  Future<void> _deleteBackup(Map<String, dynamic> backup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this backup?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ This action cannot be undone.',
                    style: TextStyle(color: AppColors.error),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(backup['backup_date']))}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Size: ${_supabaseService.formatFileSize(backup['backup_size'])}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRestoring = true);

    try {
      final success = await _supabaseService.deleteBackup(backup['id']);

      if (success) {
        await _loadBackupInfo();
        _showMessage('Backup deleted successfully', isError: false);
      } else {
        _showMessage('Failed to delete backup', isError: true);
      }
    } catch (e) {
      _showMessage('Error deleting backup: $e', isError: true);
    } finally {
      setState(() => _isRestoring = false);
    }
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
      await _supabaseService.logout();
      await _authService.logout();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    }
  }

  void _showBackupListDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              padding: const EdgeInsets.all(20),
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
                    'Backup List',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your backups - only latest backup is kept',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _backupHistory.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_off,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No backups found',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Click "Sync Backup" to create your first backup',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _backupHistory.length,
                            itemBuilder: (context, index) {
                              final backup = _backupHistory[index];
                              final backupDate = DateTime.parse(
                                backup['backup_date'],
                              );
                              final isLatest = index == 0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: isLatest
                                      ? AppGradients.primary
                                      : null,
                                  color: isLatest ? null : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isLatest
                                        ? Colors.transparent
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 45,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        color: isLatest
                                            ? Colors.white.withOpacity(0.2)
                                            : AppColors.primaryBlue.withOpacity(
                                                0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.backup,
                                        color: isLatest
                                            ? Colors.white
                                            : AppColors.primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (isLatest)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.gold,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'Latest',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          Text(
                                            DateFormat(
                                              'yyyy-MM-dd HH:mm:ss',
                                            ).format(backupDate),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: isLatest
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Size: ${_supabaseService.formatFileSize(backup['backup_size'])}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isLatest
                                                  ? Colors.white70
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: isLatest
                                            ? Colors.white70
                                            : AppColors.error,
                                      ),
                                      onPressed: () => _deleteBackup(backup),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _exportPdf({int? semester}) async {
    setState(() => _isExporting = true);

    try {
      final path = await PdfService().generateResultsPdf(
        studentId: widget.studentId,
        semester: semester,
      );
      _showMessage('PDF saved to Downloads/ResultWave/', isError: false);
      _showShareDialog(path);
    } catch (e) {
      _showMessage('Error exporting PDF: $e', isError: true);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showShareDialog(String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('PDF Generated Successfully!'),
        content: const Text('Would you like to share the PDF?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Share.shareXFiles([
                XFile(path),
              ], text: 'My Academic Report from ResultWave');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Share'),
          ),
        ],
      ),
    );
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppGradients.darkBackgroundGradient
              : AppGradients.backgroundGradient,
        ),
        child: _isLoading
            ? _buildSkeletonLoader(isDark)
            : RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    _loadData(),
                    _loadAvatars(),
                    _loadUserAvatar(),
                    _loadBackupInfo(),
                  ]);
                  setState(() {});
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Profile Section
                    FadeInAnimation(
                      child: _buildSectionHeader(
                        'Profile',
                        Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeInAnimation(
                      delay: 100,
                      child: GlassCard(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                _buildProfileAvatar(),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _showAvatarPicker,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: _isUpdatingAvatar
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.edit,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _student?.studentName ?? '',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _student?.studentId ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              Icons.school,
                              'Course',
                              _courseName ?? _student?.courseId ?? '',
                              AppColors.primaryBlue,
                              isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Cloud Backup Section
                    FadeInAnimation(
                      delay: 150,
                      child: _buildSectionHeader(
                        'Cloud Backup',
                        Icons.cloud_outlined,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeInAnimation(
                      delay: 200,
                      child: GlassCard(
                        child: Column(
                          children: [
                            if (_latestBackup != null &&
                                _latestBackup!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: AppGradients.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.cloud_done,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Latest Backup',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          Text(
                                            DateFormat(
                                              'yyyy-MM-dd HH:mm:ss',
                                            ).format(
                                              DateTime.parse(
                                                _latestBackup!['backup_date'],
                                              ),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            'Size: ${_supabaseService.formatFileSize(_latestBackup!['backup_size'])}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.surfaceDark
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.cloud_off,
                                      color: isDark
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'No backups found. Create your first backup now.',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isBackingUp
                                        ? null
                                        : _createBackup,
                                    icon: _isBackingUp
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.cloud_upload),
                                    label: Text(
                                      _isBackingUp
                                          ? 'Backing up...'
                                          : 'Sync Backup',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryBlue,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _showBackupListDialog,
                                    icon: const Icon(Icons.list_alt),
                                    label: const Text('View Backups'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_backupHistory.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  '${_backupHistory.length} backup(s) available',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Appearance Section
                    FadeInAnimation(
                      delay: 250,
                      child: _buildSectionHeader(
                        'Appearance',
                        Icons.palette_outlined,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeInAnimation(
                      delay: 300,
                      child: GlassCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: AppGradients.goldGradient,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    themeProvider.themeMode == ThemeMode.dark
                                        ? Icons.dark_mode
                                        : Icons.light_mode,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  themeProvider.themeMode == ThemeMode.dark
                                      ? 'Dark Mode'
                                      : 'Light Mode',
                                  style: const TextStyle(
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
                              activeColor: AppColors.primaryBlue,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Export Section
                    FadeInAnimation(
                      delay: 350,
                      child: _buildSectionHeader(
                        'Export',
                        Icons.download_outlined,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeInAnimation(
                      delay: 400,
                      child: GlassCard(
                        child: Column(
                          children: [
                            _buildExportOption(
                              icon: Icons.description,
                              title: 'Export Full Report',
                              subtitle: 'Complete academic transcript',
                              color: AppColors.success,
                              onTap: () => _exportPdf(),
                              isLoading:
                                  _isExporting && _selectedSemester == null,
                              isDark: isDark,
                            ),
                            const Divider(),
                            _buildSemesterDropdown(isDark),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // About Section
                    FadeInAnimation(
                      delay: 450,
                      child: _buildSectionHeader('About', Icons.info_outline),
                    ),
                    const SizedBox(height: 8),
                    FadeInAnimation(
                      delay: 500,
                      child: GlassCard(
                        child: Column(
                          children: [
                            _buildAboutRow('Version', '1.0.0', isDark),
                            _buildAboutRow(
                              'Developer',
                              'ResultWave Team',
                              isDark,
                            ),
                            _buildAboutRow(
                              'Email',
                              'support@resultwave.com',
                              isDark,
                            ),
                            _buildAboutRow(
                              'Website',
                              'www.resultwave.com',
                              isDark,
                            ),
                            const Divider(),
                            _buildAboutRow(
                              'Built with',
                              'Flutter & Supabase',
                              isDark,
                            ),
                            _buildAboutRow('License', 'MIT', isDark),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.info.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.copyright,
                                    size: 16,
                                    color: AppColors.info,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '© 2024 ResultWave. All rights reserved.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
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
                    const SizedBox(height: 20),

                    // Logout Button at Bottom
                    FadeInAnimation(
                      delay: 550,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                            label: const Text(
                              'Logout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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

  Widget _buildSkeletonLoader(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile Section Skeleton
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: GlassCard(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 150,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 50,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 120,
                            height: 14,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Backup Section Skeleton
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: GlassCard(
            child: Column(
              children: [
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Appearance Section Skeleton
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: GlassCard(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Container(
                  width: 50,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    final selectedAvatar = _avatars.firstWhere(
      (a) => a.id == _selectedAvatarId,
      orElse: () => Avatar(id: 0, avatarPath: ''),
    );

    if (_selectedAvatarId != null && selectedAvatar.avatarPath.isNotEmpty) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 3),
        ),
        child: ClipOval(
          child: Image.asset(
            selectedAvatar.avatarPath,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.person, size: 40, color: Colors.white),
              );
            },
          ),
        ),
      );
    } else {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 3),
        ),
        child: Center(
          child: Text(
            _student?.studentName.isNotEmpty == true
                ? _student!.studentName[0].toUpperCase()
                : 'U',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isLoading,
    required bool isDark,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
      trailing: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
      onTap: onTap,
    );
  }

  Widget _buildSemesterDropdown(bool isDark) {
    return DropdownButtonFormField<int>(
      decoration: InputDecoration(
        labelText: 'Export Specific Semester',
        prefixIcon: const Icon(Icons.calendar_today, size: 18),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      value: _selectedSemester,
      items: _semesters.map((semester) {
        return DropdownMenuItem<int>(
          value: semester,
          child: Text('Semester $semester'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _selectedSemester = value);
        if (value != null) _exportPdf(semester: value);
      },
    );
  }

  Widget _buildAboutRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : null,
            ),
          ),
        ],
      ),
    );
  }
}
