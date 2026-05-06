import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/providers/theme_provider.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/services/pdf_service.dart';
import 'package:result_wave/services/supabase_service.dart';
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

  // Backup related variables
  bool _isBackingUp = false;
  bool _isRestoring = false;
  Map<String, dynamic>? _latestBackup;
  List<Map<String, dynamic>> _backupHistory = [];
  bool _isLoadingBackups = false;
  final SupabaseService _supabaseService = SupabaseService();

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
      // Supabase might not be initialized yet
    }
    await _loadData();
    await _loadBackupInfo();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final students = await DatabaseService().getStudents();
    _student = students.firstWhere((s) => s.studentId == widget.studentId);

    final modules = await DatabaseService().getModulesByCourse(
      _student!.courseId,
    );
    _semesters = modules.map((m) => m.semester).toSet().toList()..sort();

    setState(() => _isLoading = false);
  }

  Future<void> _loadBackupInfo() async {
    setState(() {
      _isLoadingBackups = true;
    });

    try {
      _latestBackup = await _supabaseService.getLatestBackup(widget.studentId);
      _backupHistory = await _supabaseService.getBackups(
        studentId: widget.studentId,
      );
    } catch (e) {
      // Handle error silently
    }

    setState(() {
      _isLoadingBackups = false;
    });
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
        _showMessage(
          'Backup created successfully!\nDate: ${DateFormat('yyyy-MM-dd HH:mm').format(result['backupDate'])}\nSize: ${_supabaseService.formatFileSize(result['backupSize'])}',
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

  Future<void> _restoreBackup(Map<String, dynamic> backup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Restore Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to restore this backup?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚠️ This will overwrite your current data.'),
                  const SizedBox(height: 4),
                  Text(
                    'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(backup['backup_date']))}',
                  ),
                  Text(
                    'Size: ${_supabaseService.formatFileSize(backup['backup_size'])}',
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
              backgroundColor: AppColors.warning,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRestoring = true);

    try {
      final db = await DatabaseService().database;
      final success = await _supabaseService.restoreBackup(backup['id'], db);

      if (success) {
        _showMessage('Data restored successfully!', isError: false);
        await Future.delayed(const Duration(seconds: 1));
        // Reload the app data
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SettingsPage(studentId: widget.studentId),
          ),
        );
      } else {
        _showMessage('Restore failed', isError: true);
      }
    } catch (e) {
      _showMessage('Error restoring backup: $e', isError: true);
    } finally {
      setState(() => _isRestoring = false);
    }
  }

  Future<void> _deleteBackup(Map<String, dynamic> backup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Backup'),
        content: const Text(
          'Are you sure you want to delete this backup? This action cannot be undone.',
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

    final success = await _supabaseService.deleteBackup(backup['id']);
    if (success) {
      await _loadBackupInfo();
      _showMessage('Backup deleted successfully', isError: false);
    } else {
      _showMessage('Failed to delete backup', isError: true);
    }
  }

  void _showBackupHistoryDialog() {
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
        builder: (context, scrollController) => Container(
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
                'Backup History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                              gradient: isLatest ? AppGradients.primary : null,
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.gold,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.restore,
                                        color: isLatest
                                            ? Colors.white
                                            : AppColors.warning,
                                      ),
                                      onPressed: () => _restoreBackup(backup),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: isLatest
                                            ? Colors.white70
                                            : AppColors.error,
                                      ),
                                      onPressed: () => _deleteBackup(backup),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppGradients.darkBackgroundGradient
              : AppGradients.backgroundGradient,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Profile Section
                  FadeInAnimation(
                    child: _buildSectionHeader('Profile', Icons.person_outline),
                  ),
                  const SizedBox(height: 8),
                  FadeInAnimation(
                    delay: 100,
                    child: GlassCard(
                      child: Column(
                        children: [
                          _buildProfileAvatar(),
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
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            Icons.school,
                            'Course',
                            _student?.courseId ?? '',
                            AppColors.primaryBlue,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Backup Section
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
                          // Latest Backup Info
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
                                          DateFormat('yyyy-MM-dd HH:mm').format(
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
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.cloud_off,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'No backups found. Create your first backup now.',
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
                                        : 'Create Backup',
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
                                  onPressed: _showBackupHistoryDialog,
                                  icon: const Icon(Icons.history),
                                  label: const Text('Backup History'),
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
                                  color: Colors.grey.shade500,
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
                          ),
                          const Divider(),
                          _buildSemesterDropdown(),
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
                          _buildAboutRow('Version', '1.0.0'),
                          _buildAboutRow('Developer', 'ResultWave Team'),
                          _buildAboutRow('Contact', 'support@resultwave.com'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
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

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
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
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
              color: Colors.grey.shade400,
            ),
      onTap: onTap,
    );
  }

  Widget _buildSemesterDropdown() {
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

  Widget _buildAboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
