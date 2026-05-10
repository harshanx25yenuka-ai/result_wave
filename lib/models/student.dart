class Student {
  final String studentId;
  final String studentName;
  final String courseId;
  final String password; // Added password field

  Student({
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.password,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'courseId': courseId,
      'password': password,
    };
  }

  static String getCoursePrefixFromId(String studentId) {
    if (studentId.contains('/')) {
      final parts = studentId.split('/');
      if (parts.isNotEmpty) {
        return parts[0].toUpperCase();
      }
    }
    return '';
  }

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

  static bool isValidStudentIdFormat(String studentId) {
    final regex = RegExp(
      r'^(SOF|MMW|NET)/\d{2}/(B1|B2)/\d{2}$',
      caseSensitive: false,
    );
    return regex.hasMatch(studentId.toUpperCase().trim());
  }

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

    final prefix = parts[0].toUpperCase();
    if (prefix != 'SOF' && prefix != 'MMW' && prefix != 'NET') {
      return 'Course code must be SOF, MMW, or NET';
    }

    final year = parts[1];
    if (!RegExp(r'^\d{2}$').hasMatch(year)) {
      return 'Year must be 2 digits (e.g., 21, 22, 23)';
    }

    final batch = parts[2].toUpperCase();
    if (batch != 'B1' && batch != 'B2') {
      return 'Batch must be B1 or B2';
    }

    final number = parts[3];
    if (!RegExp(r'^\d{2}$').hasMatch(number)) {
      return 'Student number must be 2 digits (e.g., 01, 02, 11)';
    }

    return null;
  }

  static bool validatePassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[#\$%@_]'))) return false;
    return true;
  }

  static String? getPasswordError(String password) {
    if (password.isEmpty) return 'Please enter a password';
    if (password.length < 8) return 'Password must be at least 8 characters';
    if (!password.contains(RegExp(r'[A-Z]')))
      return 'Password must contain at least one capital letter';
    if (!password.contains(RegExp(r'[a-z]')))
      return 'Password must contain at least one simple letter';
    if (!password.contains(RegExp(r'[0-9]')))
      return 'Password must contain at least one number';
    if (!password.contains(RegExp(r'[#\$%@_]')))
      return 'Password must contain at least one special character (#, \$, _, @)';
    return null;
  }

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
}
