class Module {
  final String moduleId;
  final String moduleName;
  final int credits;
  final List<String> courseIds;
  final int semester;
  final String gpaType; // "gpa" or "non-gpa"

  Module({
    required this.moduleId,
    required this.moduleName,
    required this.credits,
    required this.courseIds,
    required this.semester,
    required this.gpaType,
  });

  factory Module.fromJson(Map<String, dynamic> json) {
    return Module(
      moduleId: json['Module_Id'],
      moduleName: json['Module_Name'],
      credits: json['Credits'],
      courseIds: List<String>.from(json['Course_Id']),
      semester: json['Semester'],
      gpaType: json['gpa_type'] ?? 'gpa', // Default to 'gpa' if not present
    );
  }

  bool get isGpaModule => gpaType == 'gpa';
  bool get isNonGpaModule => gpaType == 'non-gpa';
}
