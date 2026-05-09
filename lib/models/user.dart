class AppUser {
  final String studentId;
  final String studentName;
  final String courseId;
  final String password;
  final DateTime createdAt;

  AppUser({
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.password,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'student_name': studentName,
      'course_id': courseId,
      'password': password,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      studentId: map['student_id'] ?? '',
      studentName: map['student_name'] ?? '',
      courseId: map['course_id'] ?? '',
      password: map['password'] ?? '',
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
