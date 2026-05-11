import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:result_wave/models/material.dart';
import 'package:result_wave/models/module.dart';

class MaterialService {
  static List<ModuleMaterials>? _cachedMaterials;

  Future<List<ModuleMaterials>> loadMaterials() async {
    if (_cachedMaterials != null) {
      return _cachedMaterials!;
    }

    try {
      final String jsonString = await rootBundle.loadString(
        'db/materials.json',
      );
      final List<dynamic> jsonData = json.decode(jsonString);

      _cachedMaterials = jsonData
          .map((item) => ModuleMaterials.fromJson(item))
          .toList();

      return _cachedMaterials!;
    } catch (e) {
      print('Error loading materials: $e');
      return [];
    }
  }

  Future<List<ModuleMaterials>> getMaterialsByCourse(
    List<Module> modules,
  ) async {
    final allMaterials = await loadMaterials();
    final moduleIds = modules.map((m) => m.moduleId).toSet();

    return allMaterials.where((m) => moduleIds.contains(m.moduleId)).toList();
  }

  Future<Map<String, List<MaterialItem>>> getMaterialsGroupedByType(
    List<ModuleMaterials> materials,
  ) async {
    final Map<String, List<MaterialItem>> grouped = {};

    for (var moduleMaterial in materials) {
      for (var material in moduleMaterial.materials) {
        final type = material.materialType;
        if (!grouped.containsKey(type)) {
          grouped[type] = [];
        }
        grouped[type]!.add(material);
      }
    }

    return grouped;
  }

  List<MaterialItem> getMaterialsByType(
    List<ModuleMaterials> materials,
    String type,
  ) {
    final result = <MaterialItem>[];

    for (var moduleMaterial in materials) {
      for (var material in moduleMaterial.materials) {
        if (material.materialType == type) {
          result.add(material);
        }
      }
    }

    return result;
  }

  Future<Map<String, List<MaterialItem>>> getMaterialsByModule(
    List<ModuleMaterials> materials,
  ) async {
    final Map<String, List<MaterialItem>> grouped = {};

    for (var moduleMaterial in materials) {
      grouped[moduleMaterial.moduleId] = moduleMaterial.materials;
    }

    return grouped;
  }

  MaterialItem? getMaterialById(String id) {
    if (_cachedMaterials == null) return null;

    for (var moduleMaterial in _cachedMaterials!) {
      for (var material in moduleMaterial.materials) {
        if (material.id == id) {
          return material;
        }
      }
    }
    return null;
  }

  List<String> getAvailableMaterialTypes() {
    return ['notes', 'past_papers', 'assignments'];
  }

  Map<String, dynamic> getMaterialTypeConfig(String type) {
    final configs = {
      'notes': {'icon': '📝', 'color': '#2563EB', 'label': 'Notes'},
      'past_papers': {'icon': '📄', 'color': '#10B981', 'label': 'Past Papers'},
      'assignments': {'icon': '✏️', 'color': '#F59E0B', 'label': 'Assignments'},
      'tutorials': {'icon': '📚', 'color': '#7C3AED', 'label': 'Tutorials'},
      'labsheets': {'icon': '🔬', 'color': '#EF4444', 'label': 'Lab Sheets'},
    };

    return configs[type] ?? {'icon': '📎', 'color': '#6B7280', 'label': type};
  }
}
