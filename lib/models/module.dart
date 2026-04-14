class Module {
  final String moduleId;
  final String moduleName;
  final int credits;
  final List<String> courseIds;
  final int semester;

  Module({
    required this.moduleId,
    required this.moduleName,
    required this.credits,
    required this.courseIds,
    required this.semester,
  });

  factory Module.fromJson(Map<String, dynamic> json) {
    return Module(
      moduleId: json['Module_Id'],
      moduleName: json['Module_Name'],
      credits: json['Credits'],
      courseIds: List<String>.from(json['Course_Id']),
      semester: json['Semester'],
    );
  }
}
