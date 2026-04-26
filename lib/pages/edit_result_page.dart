import 'package:flutter/material.dart';
import 'package:result_wave/models/grade.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/utils/constants.dart';
import 'package:result_wave/utils/animations.dart';
import 'package:result_wave/widgets/glass_card.dart';

class EditResultPage extends StatefulWidget {
  final String moduleId;
  final String currentGrade;

  const EditResultPage({
    Key? key,
    required this.moduleId,
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
      _showMessage('Error loading grades: $e', isError: true);
    }
  }

  Future<void> _saveResult() async {
    if (_selectedGrade != null && _selectedGrade != widget.currentGrade) {
      setState(() => _isSaving = true);

      try {
        await DatabaseService().insertResult(
          Result(moduleId: widget.moduleId, grade: _selectedGrade!),
        );

        _showMessage('Result updated successfully!', isError: false);

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pop(context, _selectedGrade);
        }
      } catch (e) {
        setState(() => _isSaving = false);
        _showMessage('Error saving result: $e', isError: true);
      }
    } else if (_selectedGrade == widget.currentGrade) {
      _showMessage('No changes made', isError: false);
      Navigator.pop(context);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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

  String _getGradeDescription(String grade) {
    switch (grade) {
      case 'A+':
        return 'Exceptional Performance';
      case 'A':
        return 'Excellent Performance';
      case 'A-':
        return 'Very Good Performance';
      case 'B+':
        return 'Good Performance';
      case 'B':
        return 'Satisfactory Performance';
      case 'B-':
        return 'Adequate Performance';
      case 'C+':
        return 'Fair Performance';
      case 'C':
        return 'Passing Performance';
      case 'C-':
        return 'Marginal Performance';
      case 'D+':
        return 'Below Average';
      case 'D':
        return 'Poor Performance';
      case 'F':
        return 'Failed';
      case 'I':
        return 'Incomplete';
      default:
        return '';
    }
  }

  double _getGradePointValue(String grade) {
    var gradeObj = _grades.firstWhere(
      (g) => g.grade == grade,
      orElse: () => Grade(grade: grade, gradePoint: 0.0, status: ''),
    );
    return gradeObj.gradePoint;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Edit Result'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
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
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppGradients.darkBackgroundGradient
              : AppGradients.backgroundGradient,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : FadeInAnimation(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Module Info Card
                      GlassCard(
                        child: Column(
                          children: [
                            Row(
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
                                      const Text(
                                        'Module Information',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.moduleId,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Divider(color: Colors.grey.shade200),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                            _getGradeColor(widget.currentGrade),
                                            _getGradeColor(
                                              widget.currentGrade,
                                            ).withOpacity(0.7),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Text(
                                        widget.currentGrade,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_getGradePointValue(widget.currentGrade) >
                                    0)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
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
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
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

                            // Grade Grid
                            _buildGradeGrid(),

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
                                      color: AppColors.success.withOpacity(0.3),
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
                                            Text(
                                              'Updating from "${widget.currentGrade}" to "$_selectedGrade"',
                                              style: const TextStyle(
                                                fontSize: 13,
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
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                side: BorderSide(color: Colors.grey.shade400),
                              ),
                              child: const Text('Cancel'),
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
    );
  }

  Widget _buildGradeGrid() {
    // Group grades by category
    final List<Map<String, dynamic>> gradeCategories = [
      {
        'name': 'Excellent',
        'grades': ['A+', 'A', 'A-'],
        'color': AppColors.success,
      },
      {
        'name': 'Good',
        'grades': ['B+', 'B', 'B-'],
        'color': AppColors.primaryBlue,
      },
      {
        'name': 'Satisfactory',
        'grades': ['C+', 'C', 'C-'],
        'color': AppColors.accentTeal,
      },
      {
        'name': 'Poor',
        'grades': ['D+', 'D'],
        'color': Colors.orange,
      },
      {
        'name': 'Fail',
        'grades': ['F', 'F(CA)', 'F(ET)'],
        'color': AppColors.error,
      },
      {
        'name': 'Incomplete',
        'grades': ['I', 'I(ET)', 'I(CA)'],
        'color': AppColors.warning,
      },
    ];

    return Column(
      children: gradeCategories.map((category) {
        final categoryGrades = _grades
            .where((g) => category['grades'].contains(g.grade))
            .toList();

        if (categoryGrades.isEmpty) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category['name'],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: categoryGrades.map((grade) {
                  final isSelected = _selectedGrade == grade.grade;
                  final gradeColor = _getGradeColor(grade.grade);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedGrade = grade.grade;
                      });
                      _showMessage(
                        'Selected: ${grade.grade} - ${_getGradeDescription(grade.grade)}',
                        isError: false,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  gradeColor,
                                  gradeColor.withOpacity(0.8),
                                ],
                              )
                            : null,
                        color: isSelected ? null : gradeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? gradeColor
                              : gradeColor.withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: gradeColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            grade.grade,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : gradeColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            grade.gradePoint.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected ? Colors.white70 : gradeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
