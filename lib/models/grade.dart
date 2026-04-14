class Grade {
  final String grade;
  final double gradePoint;
  final String status;

  Grade({required this.grade, required this.gradePoint, required this.status});

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      grade: json['Grade'],
      gradePoint: json['Grade_Point'].toDouble(),
      status: json['Status'],
    );
  }
}
