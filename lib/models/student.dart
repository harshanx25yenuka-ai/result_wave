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
}
