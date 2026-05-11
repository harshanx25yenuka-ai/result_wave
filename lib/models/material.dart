class MaterialItem {
  final String id;
  final String materialType;
  final String title;
  final String filePath;
  final String fileType;

  MaterialItem({
    required this.id,
    required this.materialType,
    required this.title,
    required this.filePath,
    required this.fileType,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      id: json['id'].toString(),
      materialType: json['material_type'],
      title: json['title'],
      filePath: json['file_path'],
      fileType: json['file_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'material_type': materialType,
      'title': title,
      'file_path': filePath,
      'file_type': fileType,
    };
  }

  String getMaterialTypeIcon() {
    switch (materialType.toLowerCase()) {
      case 'notes':
        return '📝';
      case 'past_papers':
        return '📄';
      case 'assignments':
        return '✏️';
      case 'tutorials':
        return '📚';
      case 'labsheets':
        return '🔬';
      default:
        return '📎';
    }
  }

  String getMaterialTypeLabel() {
    switch (materialType.toLowerCase()) {
      case 'notes':
        return 'Notes';
      case 'past_papers':
        return 'Past Papers';
      case 'assignments':
        return 'Assignments';
      case 'tutorials':
        return 'Tutorials';
      case 'labsheets':
        return 'Lab Sheets';
      default:
        return materialType;
    }
  }
}

class ModuleMaterials {
  final String moduleId;
  final List<MaterialItem> materials;

  ModuleMaterials({required this.moduleId, required this.materials});

  factory ModuleMaterials.fromJson(Map<String, dynamic> json) {
    return ModuleMaterials(
      moduleId: json['module_id'],
      materials: (json['materials'] as List)
          .map((item) => MaterialItem.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'module_id': moduleId,
      'materials': materials.map((e) => e.toJson()).toList(),
    };
  }
}
