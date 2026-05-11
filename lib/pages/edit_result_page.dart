import 'package:flutter/material.dart';
import 'package:result_wave/models/grade.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/utils/constants.dart';
import 'package:result_wave/utils/animations.dart';
import 'package:result_wave/widgets/glass_card.dart';
import 'package:result_wave/widgets/grade_card.dart';

class EditResultPage extends StatefulWidget {
  final String moduleId;
  final String moduleName;
  final int credits;
  final bool isGpaModule;
  final String currentGrade;

  const EditResultPage({
    Key? key,
    required this.moduleId,
    required this.moduleName,
    required this.credits,
    required this.isGpaModule,
    required this.currentGrade,
  }) : super(key: key);

  @override
  _EditResultPageState createState() => _EditResultPageState();
}

class _EditResultPageState extends State<EditResultPage>
    with SingleTickerProviderStateMixin {
  String? _selectedGrade;
  List<Grade> _grades = [];
  bool _isLoading = true;
  bool _isSaving = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _selectedGrade = widget.currentGrade;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _loadGrades();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadGrades() async {
    try {
      _grades = await DatabaseService().getGrades();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('Error loading grades: $e');
    }
  }

  Future<void> _saveResult() async {
    if (_selectedGrade != null && _selectedGrade != widget.currentGrade) {
      setState(() => _isSaving = true);

      try {
        await DatabaseService().insertResult(
          Result(moduleId: widget.moduleId, grade: _selectedGrade!),
        );

        ScaffoldMessenger.of(context).clearSnackBars();
        _showSuccessSnackbar(widget.currentGrade, _selectedGrade!);

        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          Navigator.pop(context, _selectedGrade);
        }
      } catch (e) {
        setState(() => _isSaving = false);
        _showErrorSnackbar('Error saving result: $e');
      }
    } else if (_selectedGrade == widget.currentGrade) {
      _showInfoSnackbar('No changes made');
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        Navigator.pop(context);
      }
    }
  }

  Color _getGradeColor(String grade) {
    if (['A+', 'A', 'A-'].contains(grade)) return AppColors.success;
    if (['B+', 'B', 'B-'].contains(grade)) return AppColors.primaryBlue;
    if (['C+', 'C', 'C-'].contains(grade)) return AppColors.accentTeal;
    if (['D+', 'D'].contains(grade)) return Colors.orange;
    if (['F', 'F(CA)', 'F(ET)'].contains(grade)) return AppColors.error;
    if (['I', 'I(ET)', 'I(CA)'].contains(grade)) return AppColors.warning;
    return Colors.grey;
  }

  String _getGradeIcon(String grade) {
    if (['A+', 'A', 'A-'].contains(grade)) return '🎉';
    if (['B+', 'B', 'B-'].contains(grade)) return '👍';
    if (['C+', 'C', 'C-'].contains(grade)) return '📚';
    if (['D+', 'D'].contains(grade)) return '⚠️';
    if (['F', 'F(CA)', 'F(ET)'].contains(grade)) return '❌';
    if (['I', 'I(ET)', 'I(CA)'].contains(grade)) return '⏳';
    return '📝';
  }

  double _getGradePointValue(String grade) {
    var gradeObj = _grades.firstWhere(
      (g) => g.grade == grade,
      orElse: () => Grade(grade: grade, gradePoint: 0.0, status: ''),
    );
    return gradeObj.gradePoint;
  }

  void _showSuccessSnackbar(String oldGrade, String newGrade) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final oldGradeColor = _getGradeColor(oldGrade);
    final newGradeColor = _getGradeColor(newGrade);
    final oldGradeIcon = _getGradeIcon(oldGrade);
    final newGradeIcon = _getGradeIcon(newGrade);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppGradients.successGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Grade Updated Successfully!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            oldGradeIcon,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            oldGrade,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: oldGradeColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            newGradeIcon,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            newGrade,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: newGradeColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+${(_getGradePointValue(newGrade) - _getGradePointValue(oldGrade)).toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Grade points updated from ${_getGradePointValue(oldGrade).toStringAsFixed(1)} to ${_getGradePointValue(newGrade).toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 11,
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update Failed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(message, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: AppColors.info,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(message, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMetadataChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Edit Result'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppGradients.darkBackgroundGradient
                : AppGradients.backgroundGradient,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).clearSnackBars();
            Navigator.pop(context);
          },
        ),
        actions: [
          if (_selectedGrade != widget.currentGrade && _selectedGrade != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppGradients.goldGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Unsaved',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppGradients.darkBackgroundGradient
              : AppGradients.backgroundGradient,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : FadeInAnimation(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        children: [
                          // Enhanced Module Information Card
                          GlassCard(
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.book,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.moduleId,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            widget.moduleName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              _buildMetadataChip(
                                                icon: Icons.credit_card,
                                                label:
                                                    '${widget.credits} Credits',
                                                color: AppColors.accentTeal,
                                                isDark: isDark,
                                              ),
                                              _buildMetadataChip(
                                                icon: widget.isGpaModule
                                                    ? Icons.auto_graph
                                                    : Icons.school,
                                                label: widget.isGpaModule
                                                    ? 'GPA Module'
                                                    : 'Non-GPA Module',
                                                color: widget.isGpaModule
                                                    ? AppColors.primaryBlue
                                                    : AppColors.warning,
                                                isDark: isDark,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Divider(
                                  color: isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade200,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Current Grade',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                _getGradeColor(
                                                  widget.currentGrade,
                                                ),
                                                _getGradeColor(
                                                  widget.currentGrade,
                                                ).withOpacity(0.7),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _getGradeIcon(
                                                  widget.currentGrade,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                widget.currentGrade,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_getGradePointValue(
                                          widget.currentGrade,
                                        ) >
                                        0)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'Grade Points',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getGradePointValue(
                                              widget.currentGrade,
                                            ).toStringAsFixed(1),
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Grade Selection Card
                          GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.goldGradient,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.edit_note,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Select New Grade',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Centered Inline Grade Grid
                                Center(child: _buildInlineGradeGrid(isDark)),

                                if (_selectedGrade != null &&
                                    _selectedGrade != widget.currentGrade)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.success.withOpacity(0.1),
                                            AppColors.success.withOpacity(0.05),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.success.withOpacity(
                                            0.3,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.info_outline,
                                            color: AppColors.success,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Grade Change Summary',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.success,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                RichText(
                                                  text: TextSpan(
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                    ),
                                                    children: [
                                                      TextSpan(
                                                        text:
                                                            widget.currentGrade,
                                                        style: TextStyle(
                                                          color: _getGradeColor(
                                                            widget.currentGrade,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const TextSpan(
                                                        text: ' → ',
                                                      ),
                                                      TextSpan(
                                                        text: _selectedGrade,
                                                        style: TextStyle(
                                                          color: _getGradeColor(
                                                            _selectedGrade!,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const TextSpan(text: ' '),
                                                      TextSpan(
                                                        text:
                                                            '(+${(_getGradePointValue(_selectedGrade!) - _getGradePointValue(widget.currentGrade)).toStringAsFixed(1)} pts)',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              AppColors.success,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).clearSnackBars();
                                    Navigator.pop(context);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveResult,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryBlue,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Save Changes',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildInlineGradeGrid(bool isDark) {
    // All grades in order - no categories, just inline rows
    final gradeRows = [
      ['A+', 'A', 'A-'],
      ['B+', 'B', 'B-'],
      ['C+', 'C', 'C-'],
      ['D+', 'D'],
      ['F', 'F(CA)', 'F(ET)'],
      ['I', 'I(ET)', 'I(CA)'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: gradeRows.map((rowGrades) {
        final rowGradeObjects = _grades
            .where((g) => rowGrades.contains(g.grade))
            .toList();

        if (rowGradeObjects.isEmpty) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: rowGradeObjects.map((grade) {
              final isSelected = _selectedGrade == grade.grade;
              final gradeIcon = _getGradeIcon(grade.grade);

              return GradeCard(
                grade: grade.grade,
                gradeIcon: gradeIcon,
                gradePoint: grade.gradePoint,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedGrade = grade.grade;
                  });
                },
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
