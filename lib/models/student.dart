class Student {
  final String studentId;
  final String studentName;
  final String courseId;

  Student({
    required this.studentId,
    required this.studentName,
    required this.courseId,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'courseId': courseId,
    };
  }

  // Get course prefix from student ID
  static String getCoursePrefixFromId(String studentId) {
    if (studentId.contains('/')) {
      final parts = studentId.split('/');
      if (parts.isNotEmpty) {
        return parts[0].toUpperCase();
      }
    }
    return '';
  }

  // Get batch from student ID (B1 or B2)
  static String getBatchFromId(String studentId) {
    if (studentId.contains('/')) {
      final parts = studentId.split('/');
      if (parts.length > 2) {
        final batch = parts[2];
        if (batch == 'B1' || batch == 'B2') {
          return batch;
        }
      }
    }
    return '';
  }

  // Validate student ID format strictly
  static bool isValidStudentIdFormat(String studentId) {
    // Pattern: 3 letters/2 numbers/B1 or B2/2 numbers
    final regex = RegExp(
      r'^(SOF|MMW|NET)/\d{2}/(B1|B2)/\d{2}$',
      caseSensitive: false,
    );
    return regex.hasMatch(studentId.toUpperCase().trim());
  }

  // Validate student ID and return error message
  static String? validateStudentId(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return 'Please enter Student ID';
    }

    if (!trimmed.contains('/')) {
      return 'Format: XXX/XX/BX/XX\nExample: SOF/21/B1/11';
    }

    final parts = trimmed.split('/');

    if (parts.length != 4) {
      return 'Invalid format. Use: XXX/XX/BX/XX\nExample: SOF/21/B1/11';
    }

    // Validate prefix
    final prefix = parts[0].toUpperCase();
    if (prefix != 'SOF' && prefix != 'MMW' && prefix != 'NET') {
      return 'Course code must be SOF, MMW, or NET';
    }

    // Validate year (2 digits)
    final year = parts[1];
    if (!RegExp(r'^\d{2}$').hasMatch(year)) {
      return 'Year must be 2 digits (e.g., 21, 22, 23)';
    }

    // Validate batch (B1 or B2)
    final batch = parts[2].toUpperCase();
    if (batch != 'B1' && batch != 'B2') {
      return 'Batch must be B1 or B2';
    }

    // Validate number (2 digits)
    final number = parts[3];
    if (!RegExp(r'^\d{2}$').hasMatch(number)) {
      return 'Student number must be 2 digits (e.g., 01, 02, 11)';
    }

    return null;
  }

  // Get course name from prefix
  static String getCourseNameFromPrefix(String prefix) {
    switch (prefix.toUpperCase()) {
      case 'SOF':
        return 'B.Tech in Software Technology';
      case 'MMW':
        return 'B.Tech in Multimedia and Web Technology';
      case 'NET':
        return 'B.Tech in Network Technology';
      default:
        return '';
    }
  }

  // Get course ID from prefix
  static String getCourseIdFromPrefix(String prefix) {
    switch (prefix.toUpperCase()) {
      case 'SOF':
        return 'SOFTWARE';
      case 'MMW':
        return 'MULTIMEDIA';
      case 'NET':
        return 'NETWORK';
      default:
        return '';
    }
  }

  // Validate complete student ID
  static bool isValidCompleteId(String studentId, String courseId) {
    final prefix = getCoursePrefixFromId(studentId);
    final expectedCourseId = getCourseIdFromPrefix(prefix);
    return expectedCourseId == courseId && isValidStudentIdFormat(studentId);
  }
}
