class Course {
  final String courseId;
  final String courseName;

  Course({required this.courseId, required this.courseName});

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(courseId: json['Course_Id'], courseName: json['Course_Name']);
  }
}
