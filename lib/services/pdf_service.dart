import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:result_wave/models/module.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/models/grade.dart';
import 'package:result_wave/models/student.dart';
import 'package:result_wave/models/course.dart';
import 'package:result_wave/services/database_service.dart';

class PdfService {
  // Color scheme for modern design
  static const primaryColor = PdfColor.fromInt(0xFF1E40AF); // Blue
  static const secondaryColor = PdfColor.fromInt(0xFF3B82F6); // Light Blue
  static const accentColor = PdfColor.fromInt(0xFF10B981); // Green
  static const warningColor = PdfColor.fromInt(0xFFEF4444); // Red
  static const greyColor = PdfColor.fromInt(0xFF6B7280);
  static const lightGreyColor = PdfColor.fromInt(0xFFF3F4F6);
  static const darkTextColor = PdfColor.fromInt(0xFF111827);
  static const orangeColor = PdfColor.fromInt(0xFFF59E0B);

  // Helper function to create color with opacity
  PdfColor _withOpacity(PdfColor color, double opacity) {
    return PdfColor(color.red, color.green, color.blue, opacity);
  }

  Future<String> generateResultsPdf({
    required String studentId,
    int? semester, // If null, generate full report
  }) async {
    final pdf = pw.Document();
    final dbService = DatabaseService();
    final student = (await dbService.getStudents()).firstWhere(
      (s) => s.studentId == studentId,
    );
    final allModules = await dbService.getModulesByCourse(student.courseId);
    final results = await dbService.getResults();
    final grades = await dbService.getGrades();
    final courses = await dbService.getCourses();
    final course = courses.firstWhere((c) => c.courseId == student.courseId);

    // Separate GPA and Non-GPA modules
    final gpaModules = allModules.where((m) => m.isGpaModule).toList();
    final nonGpaModules = allModules.where((m) => m.isNonGpaModule).toList();

    // Load logo
    pw.MemoryImage? logoImage;
    try {
      logoImage = pw.MemoryImage(
        (await rootBundle.load(
          'images/university_logo.png',
        )).buffer.asUint8List(),
      );
    } catch (e) {
      // Logo not found, continue without it
    }

    // Calculate course GPA and performance suggestions
    final semesterGpaModules = <int, List<Module>>{};
    for (var module in gpaModules) {
      semesterGpaModules.putIfAbsent(module.semester, () => []).add(module);
    }

    final semesterNonGpaModules = <int, List<Module>>{};
    for (var module in nonGpaModules) {
      semesterNonGpaModules.putIfAbsent(module.semester, () => []).add(module);
    }

    final semesterGPAs = <int, double>{};
    final semesterGpaCredits = <int, int>{};
    for (var sem in semesterGpaModules.keys) {
      int totalCredits = 0;
      double totalPoints = 0.0;
      bool hasResults = false;
      for (var module in semesterGpaModules[sem]!) {
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
      if (hasResults && totalCredits > 0) {
        semesterGPAs[sem] = totalPoints / totalCredits;
        semesterGpaCredits[sem] = totalCredits;
      }
    }

    double totalSemesterPoints = 0.0;
    int totalSemesterCredits = 0;
    for (var sem in semesterGPAs.keys) {
      totalSemesterPoints += semesterGPAs[sem]! * semesterGpaCredits[sem]!;
      totalSemesterCredits += semesterGpaCredits[sem]!;
    }
    final courseGPA = totalSemesterCredits > 0
        ? totalSemesterPoints / totalSemesterCredits
        : 0.0;

    // Check Non-GPA module pass status
    bool allNonGpaPassed = true;
    final nonGpaStatus = <int, Map<String, dynamic>>{};
    for (var sem in semesterNonGpaModules.keys) {
      int passed = 0;
      int total = semesterNonGpaModules[sem]!.length;
      for (var module in semesterNonGpaModules[sem]!) {
        var result = results.firstWhere(
          (r) => r.moduleId == module.moduleId,
          orElse: () => Result(moduleId: module.moduleId, grade: 'N/A'),
        );
        if (_isNonGpaPassed(result.grade)) {
          passed++;
        }
      }
      bool semesterPassed = passed == total;
      if (!semesterPassed) allNonGpaPassed = false;
      nonGpaStatus[sem] = {
        'passed': passed,
        'total': total,
        'completed': semesterPassed,
      };
    }

    bool isDegreeEligible = courseGPA >= 2.0 && allNonGpaPassed;

    List<String> suggestions = [];
    for (var sem in semesterGPAs.keys) {
      if (semesterGPAs[sem]! < 2.0) {
        suggestions.add(
          'Improve grades in Semester $sem GPA modules to reach GPA of 2.0 or higher.',
        );
      }
    }
    if (courseGPA < 2.0) {
      suggestions.add(
        'Your overall GPA is ${courseGPA.toStringAsFixed(2)}. You need a minimum of 2.0 to be eligible for the degree.',
      );
    }
    for (var sem in nonGpaStatus.keys) {
      if (!nonGpaStatus[sem]!['completed']) {
        int failed = nonGpaStatus[sem]!['total'] - nonGpaStatus[sem]!['passed'];
        suggestions.add(
          'You have $failed non-GPA module(s) in Semester $sem that need at least a C grade.',
        );
      }
    }
    for (var result in results) {
      if ([
        'F',
        'F(CA)',
        'F(ET)',
        'I',
        'I(ET)',
        'I(CA)',
      ].contains(result.grade)) {
        var module = allModules.firstWhere(
          (m) => m.moduleId == result.moduleId,
          orElse: () => Module(
            moduleId: result.moduleId,
            moduleName: '',
            credits: 0,
            courseIds: [],
            semester: 0,
            gpaType: 'gpa',
          ),
        );
        String moduleType = module.isGpaModule
            ? 'GPA module'
            : 'non-GPA module';
        suggestions.add(
          'Upgrade ${result.moduleId} ($moduleType) to at least C.',
        );
      }
    }

    // Header Widget
    pw.Widget buildHeader() {
      return pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.symmetric(vertical: 20, horizontal: 30),
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(
            colors: [primaryColor, secondaryColor],
            begin: pw.Alignment.topLeft,
            end: pw.Alignment.bottomRight,
          ),
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'University of Vocational Technology',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  'Ratmalana, Sri Lanka',
                  style: pw.TextStyle(fontSize: 14, color: PdfColors.white),
                ),
              ],
            ),
            if (logoImage != null)
              pw.Container(
                padding: pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Image(logoImage, width: 50, height: 50),
              ),
          ],
        ),
      );
    }

    // Footer Widget
    pw.Widget buildFooter() {
      return pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.all(15),
        decoration: pw.BoxDecoration(
          color: lightGreyColor,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated by ResultWave',
              style: pw.TextStyle(
                fontSize: 10,
                color: greyColor,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
            pw.Text(
              'Report Generated: ${DateTime.now().toString().substring(0, 10)}',
              style: pw.TextStyle(fontSize: 10, color: greyColor),
            ),
          ],
        ),
      );
    }

    // Info Card Widget
    pw.Widget buildInfoCard(String title, String value, {PdfColor? color}) {
      return pw.Expanded(
        child: pw.Container(
          margin: pw.EdgeInsets.symmetric(horizontal: 5),
          padding: pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            color: color ?? lightGreyColor,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(
              color: color != null ? color : greyColor,
              width: 0.5,
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 12,
                  color: greyColor,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: color != null ? PdfColors.white : darkTextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Section Title Widget
    pw.Widget buildSectionTitle(String title) {
      return pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        margin: pw.EdgeInsets.symmetric(vertical: 10),
        decoration: pw.BoxDecoration(
          color: primaryColor,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      );
    }

    // Enhanced Table Widget
    pw.Widget buildEnhancedTable(
      List<String> headers,
      List<List<String>> data,
    ) {
      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: greyColor, width: 0.5),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Table(
          border: pw.TableBorder.all(color: greyColor, width: 0.5),
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: lightGreyColor),
              children: headers
                  .map(
                    (header) => pw.Container(
                      padding: pw.EdgeInsets.all(12),
                      child: pw.Text(
                        header,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: darkTextColor,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  )
                  .toList(),
            ),
            // Data rows
            ...data.map(
              (row) => pw.TableRow(
                children: row.asMap().entries.map((entry) {
                  final isGradeColumn = entry.key == 3 && headers.length > 3;
                  final isModuleCodeColumn = entry.key == 0;
                  final cellValue = entry.value;
                  PdfColor? bgColor;
                  PdfColor textColor = darkTextColor;

                  if (isGradeColumn) {
                    if (['A+', 'A', 'A-'].contains(cellValue)) {
                      bgColor = accentColor;
                      textColor = PdfColors.white;
                    } else if (['B+', 'B', 'B-'].contains(cellValue)) {
                      bgColor = secondaryColor;
                      textColor = PdfColors.white;
                    } else if (['C+', 'C'].contains(cellValue)) {
                      bgColor = orangeColor;
                      textColor = PdfColors.white;
                    } else if ([
                      'F',
                      'F(CA)',
                      'F(ET)',
                      'I',
                      'I(ET)',
                      'I(CA)',
                    ].contains(cellValue)) {
                      bgColor = warningColor;
                      textColor = PdfColors.white;
                    } else if (cellValue.contains('Non-GPA')) {
                      bgColor = _withOpacity(orangeColor, 0.2);
                    }
                  }

                  if (isModuleCodeColumn && cellValue.contains('Non-GPA')) {
                    bgColor = _withOpacity(orangeColor, 0.1);
                  }

                  return pw.Container(
                    padding: pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(color: bgColor),
                    child: pw.Text(
                      cellValue,
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: textColor,
                        fontWeight: bgColor != null
                            ? pw.FontWeight.bold
                            : pw.FontWeight.normal,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }

    // Cover Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(30),
        build: (pw.Context context) => pw.Column(
          children: [
            buildHeader(),
            pw.Spacer(),
            pw.Container(
              padding: pw.EdgeInsets.all(40),
              decoration: pw.BoxDecoration(
                color: lightGreyColor,
                borderRadius: pw.BorderRadius.circular(15),
                border: pw.Border.all(color: greyColor, width: 1),
              ),
              child: pw.Column(
                children: [
                  pw.Container(
                    padding: pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      shape: pw.BoxShape.circle,
                    ),
                    child: pw.Icon(
                      pw.IconData(0xe24d),
                      color: PdfColors.white,
                      size: 40,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    semester != null
                        ? 'Academic Report'
                        : 'Complete Academic Transcript',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: darkTextColor,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    semester != null
                        ? 'Semester $semester Results'
                        : 'Full Academic Record',
                    style: pw.TextStyle(
                      fontSize: 18,
                      color: greyColor,
                      fontStyle: pw.FontStyle.italic,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 30),
                  pw.Container(
                    padding: pw.EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 25,
                    ),
                    decoration: pw.BoxDecoration(
                      color: secondaryColor,
                      borderRadius: pw.BorderRadius.circular(25),
                    ),
                    child: pw.Text(
                      'Student: ${student.studentName}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.Spacer(),
            buildFooter(),
          ],
        ),
      ),
    );

    // Profile page (only for full report)
    if (semester == null) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(30),
          build: (pw.Context context) => pw.Column(
            children: [
              buildHeader(),
              pw.SizedBox(height: 30),
              buildSectionTitle('Student Profile'),
              pw.SizedBox(height: 20),

              // Student Info Cards
              pw.Row(
                children: [
                  buildInfoCard('Student ID', student.studentId),
                  buildInfoCard('Course', course.courseName),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Row(
                children: [
                  buildInfoCard(
                    'Overall GPA',
                    courseGPA.toStringAsFixed(2),
                    color: courseGPA >= 3.0
                        ? accentColor
                        : courseGPA >= 2.0
                        ? secondaryColor
                        : warningColor,
                  ),
                  buildInfoCard(
                    'Total Credits (GPA)',
                    totalSemesterCredits.toString(),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Degree Eligibility Card
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: isDegreeEligible
                      ? _withOpacity(accentColor, 0.1)
                      : _withOpacity(warningColor, 0.1),
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(
                    color: isDegreeEligible ? accentColor : warningColor,
                    width: 1,
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Icon(
                      isDegreeEligible
                          ? pw.IconData(0xe876)
                          : pw.IconData(0xe002),
                      color: isDegreeEligible ? accentColor : warningColor,
                      size: 32,
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Degree Status',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: isDegreeEligible
                                  ? accentColor
                                  : warningColor,
                            ),
                          ),
                          pw.Text(
                            isDegreeEligible
                                ? 'Eligible for Degree'
                                : 'Not Eligible for Degree',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: isDegreeEligible
                                  ? accentColor
                                  : warningColor,
                            ),
                          ),
                          if (!isDegreeEligible) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(
                              courseGPA < 2.0
                                  ? 'GPA requirement: ${courseGPA.toStringAsFixed(2)}/2.00'
                                  : 'Non-GPA modules: Some modules not passed',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: warningColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Performance Analytics Section
              buildSectionTitle('Performance Analytics'),
              pw.SizedBox(height: 20),

              // Performance Summary Cards
              pw.Row(
                children: [
                  buildInfoCard(
                    'Completed Semesters',
                    semesterGPAs.length.toString(),
                    color: primaryColor,
                  ),
                  buildInfoCard(
                    'Average Performance',
                    courseGPA >= 3.5
                        ? 'Excellent'
                        : courseGPA >= 3.0
                        ? 'Very Good'
                        : courseGPA >= 2.5
                        ? 'Good'
                        : courseGPA >= 2.0
                        ? 'Satisfactory'
                        : 'Needs Improvement',
                    color: courseGPA >= 3.0
                        ? accentColor
                        : courseGPA >= 2.0
                        ? secondaryColor
                        : warningColor,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Semester Performance Breakdown
              if (semesterGPAs.isNotEmpty) ...[
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: lightGreyColor,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: greyColor, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Semester-wise Performance:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: darkTextColor,
                        ),
                      ),
                      pw.SizedBox(height: 15),
                      ...() {
                        final sortedSemesters = semesterGPAs.keys.toList()
                          ..sort();
                        return sortedSemesters.map((sem) {
                          final gpa = semesterGPAs[sem]!;
                          final nonGpaInfo = nonGpaStatus[sem];
                          return pw.Container(
                            margin: pw.EdgeInsets.only(bottom: 10),
                            padding: pw.EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 10,
                            ),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(5),
                              border: pw.Border.all(
                                color: gpa >= 3.0
                                    ? accentColor
                                    : gpa >= 2.0
                                    ? secondaryColor
                                    : warningColor,
                                width: 1,
                              ),
                            ),
                            child: pw.Column(
                              children: [
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      'Semester $sem',
                                      style: pw.TextStyle(
                                        fontSize: 12,
                                        fontWeight: pw.FontWeight.bold,
                                        color: darkTextColor,
                                      ),
                                    ),
                                    pw.Container(
                                      padding: pw.EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: pw.BoxDecoration(
                                        color: gpa >= 3.0
                                            ? accentColor
                                            : gpa >= 2.0
                                            ? secondaryColor
                                            : warningColor,
                                        borderRadius: pw.BorderRadius.circular(
                                          12,
                                        ),
                                      ),
                                      child: pw.Text(
                                        'GPA: ${gpa.toStringAsFixed(2)}',
                                        style: pw.TextStyle(
                                          fontSize: 11,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (nonGpaInfo != null &&
                                    nonGpaInfo['total'] > 0)
                                  pw.SizedBox(height: 8),
                                if (nonGpaInfo != null &&
                                    nonGpaInfo['total'] > 0)
                                  pw.Row(
                                    children: [
                                      pw.Icon(
                                        nonGpaInfo['completed']
                                            ? pw.IconData(0xe876)
                                            : pw.IconData(0xe002),
                                        color: nonGpaInfo['completed']
                                            ? accentColor
                                            : warningColor,
                                        size: 12,
                                      ),
                                      pw.SizedBox(width: 4),
                                      pw.Text(
                                        'Non-GPA: ${nonGpaInfo['passed']}/${nonGpaInfo['total']} passed',
                                        style: pw.TextStyle(
                                          fontSize: 10,
                                          color: nonGpaInfo['completed']
                                              ? accentColor
                                              : warningColor,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        }).toList();
                      }(),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
              ],

              // Recommendations Section
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: suggestions.isEmpty ? accentColor : lightGreyColor,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: suggestions.isEmpty
                      ? null
                      : pw.Border.all(color: warningColor, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          padding: pw.EdgeInsets.all(4),
                          decoration: pw.BoxDecoration(
                            color: suggestions.isEmpty
                                ? PdfColors.white
                                : warningColor,
                            shape: pw.BoxShape.circle,
                          ),
                          child: pw.Container(
                            width: 16,
                            height: 16,
                            decoration: pw.BoxDecoration(
                              color: suggestions.isEmpty
                                  ? accentColor
                                  : PdfColors.white,
                              shape: pw.BoxShape.circle,
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                suggestions.isEmpty ? '✓' : '!',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: suggestions.isEmpty
                                      ? PdfColors.white
                                      : warningColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Text(
                          suggestions.isEmpty
                              ? 'Academic Performance Status'
                              : 'Areas for Improvement',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: suggestions.isEmpty
                                ? PdfColors.white
                                : warningColor,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 15),
                    if (suggestions.isEmpty)
                      pw.Text(
                        'Excellent performance! Your academic standing is strong. You have met both GPA and non-GPA module requirements for degree eligibility.',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.normal,
                        ),
                      )
                    else
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: suggestions
                            .map(
                              (suggestion) => pw.Container(
                                margin: pw.EdgeInsets.only(bottom: 10),
                                padding: pw.EdgeInsets.all(12),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  borderRadius: pw.BorderRadius.circular(6),
                                ),
                                child: pw.Row(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Container(
                                      margin: pw.EdgeInsets.only(top: 2),
                                      width: 6,
                                      height: 6,
                                      decoration: pw.BoxDecoration(
                                        color: warningColor,
                                        shape: pw.BoxShape.circle,
                                      ),
                                    ),
                                    pw.SizedBox(width: 12),
                                    pw.Expanded(
                                      child: pw.Text(
                                        suggestion,
                                        style: pw.TextStyle(
                                          fontSize: 13,
                                          color: darkTextColor,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
              pw.Spacer(),
              buildFooter(),
            ],
          ),
        ),
      );
    }

    // Semester result pages
    final semestersToProcess =
        semester != null
              ? [semester]
              : allModules.map((m) => m.semester).toSet().toList()
          ..sort();

    for (var sem in semestersToProcess) {
      final gpaModulesInSemester = semesterGpaModules[sem] ?? [];
      final nonGpaModulesInSemester = semesterNonGpaModules[sem] ?? [];
      final allModulesInSemester = [
        ...gpaModulesInSemester,
        ...nonGpaModulesInSemester,
      ];

      if (allModulesInSemester.isNotEmpty) {
        final semesterGpa = semesterGPAs[sem];
        final nonGpaInfo = nonGpaStatus[sem];

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.all(30),
            build: (pw.Context context) => pw.Column(
              children: [
                buildHeader(),
                pw.SizedBox(height: 30),

                // Semester Header with GPA
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Container(
                      padding: pw.EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 20,
                      ),
                      decoration: pw.BoxDecoration(
                        color: primaryColor,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Text(
                        'Semester $sem Results',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    if (semesterGpa != null)
                      pw.Container(
                        padding: pw.EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                        decoration: pw.BoxDecoration(
                          color: semesterGpa >= 3.5
                              ? accentColor
                              : semesterGpa >= 2.0
                              ? secondaryColor
                              : warningColor,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          'GPA: ${semesterGpa.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                  ],
                ),

                // Non-GPA status if any
                if (nonGpaInfo != null && nonGpaInfo['total'] > 0)
                  pw.Container(
                    margin: pw.EdgeInsets.only(top: 16),
                    padding: pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: nonGpaInfo['completed']
                          ? _withOpacity(accentColor, 0.1)
                          : _withOpacity(warningColor, 0.1),
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(
                        color: nonGpaInfo['completed']
                            ? accentColor
                            : warningColor,
                        width: 0.5,
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Icon(
                          nonGpaInfo['completed']
                              ? pw.IconData(0xe876)
                              : pw.IconData(0xe002),
                          color: nonGpaInfo['completed']
                              ? accentColor
                              : warningColor,
                          size: 16,
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          'Non-GPA Modules: ${nonGpaInfo['passed']}/${nonGpaInfo['total']} passed',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: nonGpaInfo['completed']
                                ? accentColor
                                : warningColor,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                pw.SizedBox(height: 25),

                // Enhanced Results Table
                buildEnhancedTable(
                  [
                    'Module Code',
                    'Module Name',
                    'Credits',
                    'Grade',
                    'Grade Points',
                  ],
                  allModulesInSemester.map((module) {
                    final result = results.firstWhere(
                      (r) => r.moduleId == module.moduleId,
                      orElse: () =>
                          Result(moduleId: module.moduleId, grade: 'N/A'),
                    );
                    final grade = grades.firstWhere(
                      (g) => g.grade == result.grade,
                      orElse: () =>
                          Grade(grade: 'N/A', gradePoint: 0.0, status: ''),
                    );
                    String moduleCodeDisplay = module.moduleId;
                    if (module.isNonGpaModule) {
                      moduleCodeDisplay = '${module.moduleId} (Non-GPA)';
                    }
                    return [
                      moduleCodeDisplay,
                      module.moduleName,
                      module.credits.toString(),
                      result.grade,
                      grade.gradePoint.toStringAsFixed(1),
                    ];
                  }).toList(),
                ),

                pw.SizedBox(height: 30),

                // Semester Summary
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: lightGreyColor,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: greyColor, width: 0.5),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text(
                            'Total Modules',
                            style: pw.TextStyle(fontSize: 12, color: greyColor),
                          ),
                          pw.Text(
                            allModulesInSemester.length.toString(),
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: darkTextColor,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text(
                            'GPA Credits',
                            style: pw.TextStyle(fontSize: 12, color: greyColor),
                          ),
                          pw.Text(
                            (semesterGpaCredits[sem] ?? 0).toString(),
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: darkTextColor,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text(
                            'Semester GPA',
                            style: pw.TextStyle(fontSize: 12, color: greyColor),
                          ),
                          pw.Text(
                            semesterGpa?.toStringAsFixed(2) ?? 'N/A',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: semesterGpa != null && semesterGpa! >= 3.0
                                  ? accentColor
                                  : semesterGpa != null && semesterGpa! >= 2.0
                                  ? secondaryColor
                                  : warningColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),
                buildFooter(),
              ],
            ),
          ),
        );
      }
    }

    // Save PDF to downloads folder
    final dir = await getDownloadsDirectory();
    final pdfDir = Directory('${dir!.path}/ResultWave');
    await pdfDir.create(recursive: true);
    final fileName = semester != null
        ? 'results_semester_$semester.pdf'
        : 'results_full_report.pdf';
    final file = File('${pdfDir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  bool _isNonGpaPassed(String grade) {
    if (grade == 'N/A') return false;
    if (['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C'].contains(grade)) {
      return true;
    }
    return false;
  }
}
