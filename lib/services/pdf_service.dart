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
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF1E40AF);
  static const PdfColor secondaryColor = PdfColor.fromInt(0xFF2563EB);
  static const PdfColor goldColor = PdfColor.fromInt(0xFFFFD700);
  static const PdfColor successColor = PdfColor.fromInt(0xFF10B981);
  static const PdfColor warningColor = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor errorColor = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor darkTextColor = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor lightTextColor = PdfColor.fromInt(0xFF64748B);
  static const PdfColor borderColor = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor whiteColor = PdfColor.fromInt(0xFFFFFFFF);

  PdfColor _colorWithOpacity(PdfColor color, double opacity) {
    int alpha = (opacity * 255).toInt();
    return PdfColor(color.red, color.green, color.blue, color.alpha);
  }

  Future<String> generateResultsPdf({
    required String studentId,
    int? semester,
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

    final gpaModules = allModules.where((m) => m.isGpaModule).toList();
    final nonGpaModules = allModules.where((m) => m.isNonGpaModule).toList();

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

    double totalCoursePoints = 0.0;
    int totalCourseCredits = 0;
    for (var sem in semesterGPAs.keys) {
      totalCoursePoints += semesterGPAs[sem]! * semesterGpaCredits[sem]!;
      totalCourseCredits += semesterGpaCredits[sem]!;
    }
    final courseGPA = totalCourseCredits > 0
        ? totalCoursePoints / totalCourseCredits
        : 0.0;

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
        if (_isNonGpaPassed(result.grade)) passed++;
      }
      bool semesterPassed = passed == total;
      if (!semesterPassed) allNonGpaPassed = false;
      nonGpaStatus[sem] = {
        'passed': passed,
        'total': total,
        'completed': semesterPassed,
      };
    }

    final List<Map<String, dynamic>> failedModules = [];
    final List<Map<String, dynamic>> incompleteModules = [];

    for (var result in results) {
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

      if (['F', 'F(ET)', 'F(CA)'].contains(result.grade)) {
        failedModules.add({
          'moduleId': module.moduleId,
          'moduleName': module.moduleName,
          'semester': module.semester,
          'grade': result.grade,
          'type': module.isGpaModule ? 'GPA' : 'Non-GPA',
          'credits': module.credits,
        });
      }

      if (['I', 'I(ET)', 'I(CA)'].contains(result.grade)) {
        incompleteModules.add({
          'moduleId': module.moduleId,
          'moduleName': module.moduleName,
          'semester': module.semester,
          'grade': result.grade,
          'type': module.isGpaModule ? 'GPA' : 'Non-GPA',
          'credits': module.credits,
        });
      }
    }

    bool isDegreeEligible = courseGPA >= 2.0 && allNonGpaPassed;

    List<String> suggestions = [];
    for (var sem in semesterGPAs.keys) {
      if (semesterGPAs[sem]! < 2.0) {
        suggestions.add(
          '• Improve grades in Semester $sem GPA modules to reach 2.0+',
        );
      }
    }
    if (courseGPA < 2.0) {
      suggestions.add(
        '• Overall GPA ${courseGPA.toStringAsFixed(2)} needs to reach 2.0',
      );
    }
    for (var sem in nonGpaStatus.keys) {
      if (!nonGpaStatus[sem]!['completed']) {
        int failed = nonGpaStatus[sem]!['total'] - nonGpaStatus[sem]!['passed'];
        suggestions.add(
          '• Complete $failed non-GPA module(s) in Semester $sem',
        );
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) => pw.Column(
          children: [
            _buildHeader(),
            pw.Spacer(),
            pw.Container(
              padding: const pw.EdgeInsets.all(40),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FAFC),
                borderRadius: pw.BorderRadius.circular(20),
                border: pw.Border.all(color: borderColor, width: 1),
              ),
              child: pw.Column(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      gradient: pw.LinearGradient(
                        colors: [goldColor, _colorWithOpacity(goldColor, 0.7)],
                      ),
                      shape: pw.BoxShape.circle,
                    ),
                    child: pw.Icon(
                      pw.IconData(0xe24d),
                      color: whiteColor,
                      size: 50,
                    ),
                  ),
                  pw.SizedBox(height: 25),
                  pw.Text(
                    semester != null
                        ? 'Semester $semester Academic Report'
                        : 'Complete Academic Transcript',
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: darkTextColor,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Official Record of Academic Achievement',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: lightTextColor,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 30,
                    ),
                    decoration: pw.BoxDecoration(
                      gradient: pw.LinearGradient(
                        colors: [primaryColor, secondaryColor],
                      ),
                      borderRadius: pw.BorderRadius.circular(30),
                    ),
                    child: pw.Text(
                      'Student: ${student.studentName}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: whiteColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.Spacer(),
            _buildFooter(),
          ],
        ),
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) => pw.Column(
          children: [
            _buildHeader(),
            pw.SizedBox(height: 20),
            _buildSectionTitle('Student Profile'),
            pw.SizedBox(height: 16),
            pw.Row(
              children: [
                _buildInfoCard('Student ID', student.studentId),
                _buildInfoCard('Course', course.courseName),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                _buildInfoCard(
                  'Overall GPA',
                  courseGPA.toStringAsFixed(2),
                  color: courseGPA >= 3.0 ? successColor : secondaryColor,
                ),
                _buildInfoCard('Total Credits', totalCourseCredits.toString()),
              ],
            ),
            pw.SizedBox(height: 20),
            _buildDegreeStatusCard(isDegreeEligible),
            pw.Spacer(),
            _buildFooter(),
          ],
        ),
      ),
    );

    final semestersToProcess =
        semester != null
              ? [semester]
              : allModules.map((m) => m.semester).toSet().toList()
          ..sort();

    for (var sem in semestersToProcess) {
      final gpaModulesInSemester = semesterGpaModules[sem] ?? [];
      final nonGpaModulesInSemester = semesterNonGpaModules[sem] ?? [];
      final allModulesInSemester = <Module>[
        ...gpaModulesInSemester,
        ...nonGpaModulesInSemester,
      ];

      if (allModulesInSemester.isNotEmpty) {
        final semesterGpa = semesterGPAs[sem];
        final nonGpaInfo = nonGpaStatus[sem];

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(30),
            build: (pw.Context context) => pw.Column(
              children: [
                _buildHeader(),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 20,
                      ),
                      decoration: pw.BoxDecoration(
                        gradient: pw.LinearGradient(
                          colors: [primaryColor, secondaryColor],
                        ),
                        borderRadius: pw.BorderRadius.circular(12),
                      ),
                      child: pw.Text(
                        'Semester $sem Results',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: whiteColor,
                        ),
                      ),
                    ),
                    if (semesterGpa != null)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 20,
                        ),
                        decoration: pw.BoxDecoration(
                          gradient: pw.LinearGradient(
                            colors: [
                              semesterGpa >= 3.0
                                  ? successColor
                                  : secondaryColor,
                              semesterGpa >= 3.0
                                  ? _colorWithOpacity(successColor, 0.7)
                                  : _colorWithOpacity(secondaryColor, 0.7),
                            ],
                          ),
                          borderRadius: pw.BorderRadius.circular(30),
                        ),
                        child: pw.Text(
                          'GPA: ${semesterGpa.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: whiteColor,
                          ),
                        ),
                      ),
                  ],
                ),
                if (nonGpaInfo != null && nonGpaInfo['total'] > 0)
                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 12),
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: nonGpaInfo['completed']
                          ? _colorWithOpacity(successColor, 0.1)
                          : _colorWithOpacity(warningColor, 0.1),
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(
                        color: nonGpaInfo['completed']
                            ? successColor
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
                              ? successColor
                              : warningColor,
                          size: 16,
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          'Non-GPA Modules: ${nonGpaInfo['passed']}/${nonGpaInfo['total']} passed',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: nonGpaInfo['completed']
                                ? successColor
                                : warningColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                pw.SizedBox(height: 20),
                _buildResultsTable(allModulesInSemester, results, grades),
                pw.SizedBox(height: 20),
                _buildSemesterSummary(
                  allModulesInSemester.length,
                  semesterGpaCredits[sem] ?? 0,
                  semesterGpa,
                ),
                pw.Spacer(),
                _buildFooter(),
              ],
            ),
          ),
        );
      }
    }

    if (failedModules.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) => pw.Column(
            children: [
              _buildHeader(),
              pw.SizedBox(height: 20),
              _buildSectionTitle('Failed Modules Summary', color: errorColor),
              pw.SizedBox(height: 16),
              pw.Text(
                'The following modules have been marked as failed and require immediate attention:',
                style: pw.TextStyle(fontSize: 11, color: lightTextColor),
              ),
              pw.SizedBox(height: 20),
              ...failedModules.map((module) => _buildFailedModuleCard(module)),
              pw.Spacer(),
              _buildFooter(),
            ],
          ),
        ),
      );
    }

    if (incompleteModules.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) => pw.Column(
            children: [
              _buildHeader(),
              pw.SizedBox(height: 20),
              _buildSectionTitle(
                'Incomplete Modules Summary',
                color: warningColor,
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'The following modules are incomplete and need to be completed:',
                style: pw.TextStyle(fontSize: 11, color: lightTextColor),
              ),
              pw.SizedBox(height: 20),
              ...incompleteModules.map(
                (module) => _buildIncompleteModuleCard(module),
              ),
              pw.Spacer(),
              _buildFooter(),
            ],
          ),
        ),
      );
    }

    final dir = Platform.isIOS
        ? await getApplicationDocumentsDirectory()
        : await getExternalStorageDirectory();
    final pdfDir = Directory('${dir!.path}/ResultWave');
    if (!await pdfDir.exists()) await pdfDir.create(recursive: true);

    final fileName = semester != null
        ? 'Semester_${semester}_Report_${DateTime.now().millisecondsSinceEpoch}.pdf'
        : 'Complete_Transcript_${DateTime.now().millisecondsSinceEpoch}.pdf';

    final file = File('${pdfDir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  pw.Widget _buildHeader() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 25),
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
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: whiteColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Ratmalana, Sri Lanka',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _colorWithOpacity(whiteColor, 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by ResultWave',
            style: pw.TextStyle(
              fontSize: 8,
              color: lightTextColor,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.Text(
            'Date: ${DateTime.now().toString().substring(0, 10)}',
            style: pw.TextStyle(fontSize: 8, color: lightTextColor),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title, {PdfColor? color}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 15),
      decoration: pw.BoxDecoration(
        color: color ?? primaryColor,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: whiteColor,
        ),
      ),
    );
  }

  pw.Widget _buildInfoCard(String title, String value, {PdfColor? color}) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF8FAFC),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: borderColor, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 9, color: lightTextColor),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: color ?? darkTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildDegreeStatusCard(bool isEligible) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: isEligible
              ? [successColor, _colorWithOpacity(successColor, 0.8)]
              : [warningColor, _colorWithOpacity(warningColor, 0.8)],
        ),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        children: [
          pw.Icon(
            isEligible ? pw.IconData(0xe876) : pw.IconData(0xe002),
            color: whiteColor,
            size: 24,
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Degree Status',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _colorWithOpacity(whiteColor, 0.7),
                  ),
                ),
                pw.Text(
                  isEligible
                      ? 'Eligible for Degree'
                      : 'Not Eligible for Degree',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: whiteColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildResultsTable(
    List<Module> modules,
    List<Result> results,
    List<Grade> grades,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor, width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Table(
        border: pw.TableBorder.all(color: borderColor, width: 0.5),
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: primaryColor),
            children: [
              _buildTableCell('Code', isHeader: true),
              _buildTableCell('Module Name', isHeader: true),
              _buildTableCell('Credits', isHeader: true),
              _buildTableCell('Grade', isHeader: true),
              _buildTableCell('Points', isHeader: true),
            ],
          ),
          ...modules.map((module) {
            final result = results.firstWhere(
              (r) => r.moduleId == module.moduleId,
              orElse: () => Result(moduleId: module.moduleId, grade: 'N/A'),
            );
            final grade = grades.firstWhere(
              (g) => g.grade == result.grade,
              orElse: () => Grade(grade: 'N/A', gradePoint: 0.0, status: ''),
            );
            final gradeColor = _getGradeColorForPdf(result.grade);
            final isNonGpa = module.isNonGpaModule;

            return pw.TableRow(
              children: [
                _buildTableCell(
                  module.moduleId + (isNonGpa ? ' (Non-GPA)' : ''),
                ),
                _buildTableCell(module.moduleName),
                _buildTableCell(module.credits.toString()),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  color: _colorWithOpacity(gradeColor, 0.15),
                  child: pw.Center(
                    child: pw.Text(
                      result.grade,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: gradeColor,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                _buildTableCell(grade.gradePoint.toStringAsFixed(1)),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? whiteColor : darkTextColor,
          fontSize: 9,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildSemesterSummary(int totalModules, int credits, double? gpa) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: borderColor, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            children: [
              pw.Text(
                'Total Modules',
                style: pw.TextStyle(fontSize: 9, color: lightTextColor),
              ),
              pw.Text(
                '$totalModules',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Column(
            children: [
              pw.Text(
                'GPA Credits',
                style: pw.TextStyle(fontSize: 9, color: lightTextColor),
              ),
              pw.Text(
                '$credits',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Column(
            children: [
              pw.Text(
                'Semester GPA',
                style: pw.TextStyle(fontSize: 9, color: lightTextColor),
              ),
              pw.Text(
                gpa?.toStringAsFixed(2) ?? 'N/A',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: gpa != null && gpa >= 3.0
                      ? successColor
                      : secondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFailedModuleCard(Map<String, dynamic> module) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _colorWithOpacity(errorColor, 0.1),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: errorColor, width: 0.5),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 3,
            height: 40,
            decoration: pw.BoxDecoration(
              color: errorColor,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      module['moduleId'],
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: pw.BoxDecoration(
                        color: module['type'] == 'GPA'
                            ? _colorWithOpacity(successColor, 0.1)
                            : _colorWithOpacity(warningColor, 0.1),
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Text(
                        module['type'],
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: module['type'] == 'GPA'
                              ? successColor
                              : warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  module['moduleName'],
                  style: pw.TextStyle(fontSize: 9, color: lightTextColor),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: pw.BoxDecoration(
                  color: _colorWithOpacity(errorColor, 0.1),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  module['grade'],
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: errorColor,
                    fontSize: 9,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Semester ${module['semester']}',
                style: pw.TextStyle(fontSize: 8, color: lightTextColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildIncompleteModuleCard(Map<String, dynamic> module) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _colorWithOpacity(warningColor, 0.1),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: warningColor, width: 0.5),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 3,
            height: 40,
            decoration: pw.BoxDecoration(
              color: warningColor,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      module['moduleId'],
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: pw.BoxDecoration(
                        color: module['type'] == 'GPA'
                            ? _colorWithOpacity(successColor, 0.1)
                            : _colorWithOpacity(warningColor, 0.1),
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Text(
                        module['type'],
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: module['type'] == 'GPA'
                              ? successColor
                              : warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  module['moduleName'],
                  style: pw.TextStyle(fontSize: 9, color: lightTextColor),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: pw.BoxDecoration(
                  color: _colorWithOpacity(warningColor, 0.1),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  module['grade'],
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: warningColor,
                    fontSize: 9,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Semester ${module['semester']}',
                style: pw.TextStyle(fontSize: 8, color: lightTextColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PdfColor _getGradeColorForPdf(String grade) {
    if (['A+', 'A', 'A-'].contains(grade)) return successColor;
    if (['B+', 'B', 'B-'].contains(grade)) return secondaryColor;
    if (['C+', 'C', 'C-'].contains(grade)) return goldColor;
    if (['F', 'F(CA)', 'F(ET)'].contains(grade)) return errorColor;
    if (['I', 'I(ET)', 'I(CA)'].contains(grade)) return warningColor;
    return lightTextColor;
  }

  bool _isNonGpaPassed(String grade) {
    if (grade == 'N/A') return false;
    return ['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C'].contains(grade);
  }
}
