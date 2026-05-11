import 'package:flutter/material.dart';
import 'package:result_wave/models/module.dart';
import 'package:result_wave/models/material.dart';
import 'package:result_wave/services/database_service.dart';
import 'package:result_wave/services/material_service.dart';
import 'package:result_wave/utils/constants.dart';
import 'package:result_wave/utils/animations.dart';
import 'package:result_wave/widgets/glass_card.dart';
import 'package:open_file/open_file.dart';

class MaterialsPage extends StatefulWidget {
  final String studentId;

  const MaterialsPage({Key? key, required this.studentId}) : super(key: key);

  @override
  _MaterialsPageState createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  List<Module> _modules = [];
  List<ModuleMaterials> _materials = [];
  Map<String, Module> _moduleMap = {};
  Map<String, List<MaterialItem>> _groupedByModule = {};
  List<String> _materialTypes = [];
  String? _selectedType;
  String? _selectedModuleId;
  bool _isLoading = true;

  final MaterialService _materialService = MaterialService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final student = (await DatabaseService().getStudents()).firstWhere(
        (s) => s.studentId == widget.studentId,
      );

      _modules = await DatabaseService().getModulesByCourse(student.courseId);

      _moduleMap = {for (var module in _modules) module.moduleId: module};

      final allMaterials = await _materialService.loadMaterials();

      _materials = await _materialService.getMaterialsByCourse(_modules);

      _groupedByModule = {};
      for (var material in _materials) {
        _groupedByModule[material.moduleId] = material.materials;
      }

      _materialTypes = _materialService.getAvailableMaterialTypes();
    } catch (e) {
      print('Error loading materials: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openMaterial(MaterialItem material) async {
    try {
      await OpenFile.open(material.filePath);
    } catch (e) {
      _showMessage('Error opening file: $e', isError: true);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<ModuleMaterials> _getFilteredMaterials() {
    var filtered = List<ModuleMaterials>.from(_materials);

    // Filter by type
    if (_selectedType != null && _selectedType != 'all') {
      filtered = filtered
          .map((moduleMaterial) {
            final filteredMaterials = moduleMaterial.materials
                .where((m) => m.materialType == _selectedType)
                .toList();

            if (filteredMaterials.isEmpty) return null;

            return ModuleMaterials(
              moduleId: moduleMaterial.moduleId,
              materials: filteredMaterials,
            );
          })
          .whereType<ModuleMaterials>()
          .toList();
    }

    // Filter by module
    if (_selectedModuleId != null && _selectedModuleId != 'all') {
      filtered = filtered
          .where((m) => m.moduleId == _selectedModuleId)
          .toList();
    }

    return filtered;
  }

  int _getTotalMaterialsCount() {
    int count = 0;
    for (var material in _materials) {
      count += material.materials.length;
    }
    return count;
  }

  int _getMaterialsByTypeCount(String type) {
    int count = 0;
    for (var moduleMaterial in _materials) {
      count += moduleMaterial.materials
          .where((m) => m.materialType == type)
          .length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredMaterials = _getFilteredMaterials();
    final totalMaterials = _getTotalMaterialsCount();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Course Materials'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Module Filter
          if (_modules.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_alt_outlined),
              onSelected: (value) {
                setState(() {
                  _selectedModuleId = value == 'all' ? null : value;
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'all',
                  child: Row(
                    children: [
                      Icon(Icons.all_inclusive, size: 20),
                      SizedBox(width: 12),
                      Text('All Modules'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                ..._modules.map((module) {
                  final materialCount =
                      _groupedByModule[module.moduleId]?.length ?? 0;
                  return PopupMenuItem(
                    value: module.moduleId,
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: AppGradients.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${module.semester}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                module.moduleName,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$materialCount materials',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          // Type Filter
          if (_materialTypes.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort_by_alpha),
              onSelected: (value) {
                setState(() {
                  _selectedType = value == 'all' ? null : value;
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'all',
                  child: Row(
                    children: [
                      Icon(Icons.all_inclusive, size: 20),
                      SizedBox(width: 12),
                      Text('All Types'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                ..._materialTypes.map((type) {
                  final config = _materialService.getMaterialTypeConfig(type);
                  final count = _getMaterialsByTypeCount(type);
                  return PopupMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Text(
                          config['icon'],
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(config['label']),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getColorFromHex(
                              config['color'],
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getColorFromHex(config['color']),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppGradients.darkBackgroundGradient
              : AppGradients.backgroundGradient,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredMaterials.isEmpty
            ? _buildEmptyState(isDark)
            : RefreshIndicator(
                onRefresh: _loadData,
                child: Column(
                  children: [
                    // Stats Bar
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            Icons.folder,
                            '${_modules.length}',
                            'Modules',
                            Colors.white,
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildStatItem(
                            Icons.description,
                            '$totalMaterials',
                            'Materials',
                            Colors.white,
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildStatItem(
                            Icons.download,
                            '${_getTotalMaterialsCount()}',
                            'Available',
                            Colors.white,
                          ),
                        ],
                      ),
                    ),
                    // Materials List
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredMaterials.length,
                        itemBuilder: (context, index) {
                          final moduleMaterial = filteredMaterials[index];
                          final module = _moduleMap[moduleMaterial.moduleId];
                          final moduleName =
                              module?.moduleName ?? moduleMaterial.moduleId;
                          final semester = module?.semester ?? 0;

                          return FadeInAnimation(
                            delay: index * 50,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: _buildModuleCard(
                                moduleMaterial,
                                moduleName,
                                semester,
                                isDark,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModuleCard(
    ModuleMaterials moduleMaterial,
    String moduleName,
    int semester,
    bool isDark,
  ) {
    final materialsByType = <String, List<MaterialItem>>{};

    for (var material in moduleMaterial.materials) {
      if (!materialsByType.containsKey(material.materialType)) {
        materialsByType[material.materialType] = [];
      }
      materialsByType[material.materialType]!.add(material);
    }

    final typeOrder = ['notes', 'past_papers', 'assignments'];
    final sortedTypes = typeOrder
        .where((t) => materialsByType.containsKey(t))
        .toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Module Header
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$semester',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moduleName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Semester $semester • ${moduleMaterial.materials.length} materials',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 12,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Semester $semester',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Materials by Type
          ...sortedTypes.map((type) {
            final materials = materialsByType[type]!;
            final config = _materialService.getMaterialTypeConfig(type);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        config['icon'],
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        config['label'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _getColorFromHex(config['color']),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getColorFromHex(
                            config['color'],
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${materials.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getColorFromHex(config['color']),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...materials.map(
                  (material) => _buildMaterialItem(material, isDark),
                ),
                if (type != sortedTypes.last) const SizedBox(height: 8),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMaterialItem(MaterialItem material, bool isDark) {
    final config = _materialService.getMaterialTypeConfig(
      material.materialType,
    );

    return GestureDetector(
      onTap: () => _openMaterial(material),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getColorFromHex(config['color']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  config['icon'],
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getColorFromHex(
                            config['color'],
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          material.fileType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            color: _getColorFromHex(config['color']),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getFileNameFromPath(material.filePath),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new,
              size: 18,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  String _getFileNameFromPath(String path) {
    final parts = path.split('/');
    return parts.last;
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Materials Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Study materials will appear here',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}
