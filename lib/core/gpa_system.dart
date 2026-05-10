import 'package:result_wave/models/module.dart';
import 'package:result_wave/models/result.dart';
import 'package:result_wave/models/grade.dart';

class GPASystem {
  // Calculate semester GPA
  static double calculateSemesterGPA({
    required List<Module> modules,
    required List<Result> results,
    required List<Grade> grades,
  }) {
    double totalPoints = 0.0;
    int totalCredits = 0;
    bool hasResults = false;

    for (var module in modules.where((m) => m.isGpaModule)) {
      final result = results.firstWhere(
        (r) => r.moduleId == module.moduleId,
        orElse: () => Result(moduleId: module.moduleId, grade: 'N/A'),
      );
      final grade = grades.firstWhere(
        (g) => g.grade == result.grade,
        orElse: () => Grade(grade: 'N/A', gradePoint: 0.0, status: ''),
      );
      if (result.grade != 'N/A') {
        totalPoints += grade.gradePoint * module.credits;
        totalCredits += module.credits;
        hasResults = true;
      }
    }

    if (hasResults && totalCredits > 0) {
      return totalPoints / totalCredits;
    }
    return 0.0;
  }

  // Calculate overall CGPA
  static double calculateCGPA({
    required Map<int, double> semesterGPAs,
    required Map<int, int> semesterCredits,
  }) {
    double totalPoints = 0.0;
    int totalCredits = 0;

    for (var semester in semesterGPAs.keys) {
      totalPoints += semesterGPAs[semester]! * semesterCredits[semester]!;
      totalCredits += semesterCredits[semester]!;
    }

    if (totalCredits > 0) {
      return totalPoints / totalCredits;
    }
    return 0.0;
  }

  // Get GPA color based on value
  static String getGpaLabel(double gpa) {
    if (gpa >= 3.7) return 'Excellent';
    if (gpa >= 3.0) return 'Very Good';
    if (gpa >= 2.0) return 'Good';
    return 'Needs Improvement';
  }

  // Check if non-GPA module is passed
  static bool isNonGpaPassed(String grade) {
    if (grade == 'N/A') return false;
    return ['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C'].contains(grade);
  }

  // Check degree eligibility
  static bool isDegreeEligible({
    required double cgpa,
    required Map<int, int> semesterPassedNonGpa,
    required Map<int, int> semesterTotalNonGpa,
  }) {
    bool allNonGpaPassed = true;
    for (var semester in semesterPassedNonGpa.keys) {
      if (semesterPassedNonGpa[semester] != semesterTotalNonGpa[semester]) {
        allNonGpaPassed = false;
        break;
      }
    }
    return cgpa >= 2.0 && allNonGpaPassed;
  }

  // Get degree status message
  static String getDegreeStatus({
    required double cgpa,
    required bool allNonGpaPassed,
  }) {
    if (cgpa >= 2.0 && allNonGpaPassed) {
      return 'Eligible for Degree';
    } else if (!allNonGpaPassed) {
      return 'Not Eligible: Non-GPA modules need C or above';
    } else if (cgpa < 2.0) {
      return 'Not Eligible: GPA below 2.0';
    } else {
      return 'Not Eligible';
    }
  }

  // Get semester-wise GPA data
  static Map<int, double> getSemesterGPAs({
    required Map<int, List<Module>> semesterGpaModules,
    required List<Result> results,
    required List<Grade> grades,
  }) {
    final Map<int, double> semesterGPAs = {};

    for (var semester in semesterGpaModules.keys) {
      int totalCredits = 0;
      double totalPoints = 0.0;
      bool hasResults = false;

      for (var module in semesterGpaModules[semester]!) {
        totalCredits += module.credits;
        final result = results.firstWhere(
          (r) => r.moduleId == module.moduleId,
          orElse: () => Result(moduleId: module.moduleId, grade: 'N/A'),
        );
        final grade = grades.firstWhere(
          (g) => g.grade == result.grade,
          orElse: () => Grade(grade: 'N/A', gradePoint: 0.0, status: ''),
        );
        if (result.grade != 'N/A') {
          totalPoints += grade.gradePoint * module.credits;
          hasResults = true;
        }
      }

      if (hasResults && totalCredits > 0) {
        semesterGPAs[semester] = totalPoints / totalCredits;
      }
    }

    return semesterGPAs;
  }
}
