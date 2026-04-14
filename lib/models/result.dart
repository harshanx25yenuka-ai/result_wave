class Result {
  final String moduleId;
  final String grade;

  Result({required this.moduleId, required this.grade});

  Map<String, dynamic> toMap() {
    return {'moduleId': moduleId, 'grade': grade};
  }
}
