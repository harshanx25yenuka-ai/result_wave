import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/providers/theme_provider.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/services/pdf_service.dart';
import 'package:result_wave/utils/constants.dart';
import 'package:result_wave/utils/animations.dart';
import 'package:result_wave/widgets/glass_card.dart';
import 'package:share_plus/share_plus.dart';

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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
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

    final students = await DatabaseService().getStudents();
    _student = students.firstWhere((s) => s.studentId == widget.studentId);

    final modules = await DatabaseService().getModulesByCourse(
      _student!.courseId,
    );
    _semesters = modules.map((m) => m.semester).toSet().toList()..sort();

    setState(() => _isLoading = false);
  }

  Future<void> _exportPdf({int? semester}) async {
    setState(() => _isExporting = true);

    try {
      final path = await PdfService().generateResultsPdf(
        studentId: widget.studentId,
        semester: semester,
      );
      _showMessage('PDF saved to Downloads/ResultWave/', isError: false);

      // Show share option
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

                  // Appearance Section
                  FadeInAnimation(
                    delay: 200,
                    child: _buildSectionHeader(
                      'Appearance',
                      Icons.palette_outlined,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeInAnimation(
                    delay: 250,
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
                    delay: 300,
                    child: _buildSectionHeader(
                      'Export',
                      Icons.download_outlined,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeInAnimation(
                    delay: 350,
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
                    delay: 400,
                    child: _buildSectionHeader('About', Icons.info_outline),
                  ),
                  const SizedBox(height: 8),
                  FadeInAnimation(
                    delay: 450,
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
