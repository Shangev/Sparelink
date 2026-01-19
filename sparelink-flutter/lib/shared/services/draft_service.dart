import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_service.dart';

/// Draft Service Provider
final draftServiceProvider = Provider<DraftService>((ref) {
  final storageService = ref.read(storageServiceProvider);
  return DraftService(storageService);
});

/// Request Draft Model
class RequestDraft {
  final String? makeId;
  final String? makeName;
  final String? modelId;
  final String? modelName;
  final String? year;
  final String? vin;
  final String? engineCode;
  final List<Map<String, dynamic>> selectedParts;
  final String? urgencyLevel;
  final double? budgetMin;
  final double? budgetMax;
  final String? notes;
  final DateTime savedAt;

  RequestDraft({
    this.makeId,
    this.makeName,
    this.modelId,
    this.modelName,
    this.year,
    this.vin,
    this.engineCode,
    this.selectedParts = const [],
    this.urgencyLevel,
    this.budgetMin,
    this.budgetMax,
    this.notes,
    required this.savedAt,
  });

  factory RequestDraft.fromJson(Map<String, dynamic> json) {
    return RequestDraft(
      makeId: json['make_id'] as String?,
      makeName: json['make_name'] as String?,
      modelId: json['model_id'] as String?,
      modelName: json['model_name'] as String?,
      year: json['year'] as String?,
      vin: json['vin'] as String?,
      engineCode: json['engine_code'] as String?,
      selectedParts: (json['selected_parts'] as List?)
          ?.map((p) => Map<String, dynamic>.from(p))
          .toList() ?? [],
      urgencyLevel: json['urgency_level'] as String?,
      budgetMin: (json['budget_min'] as num?)?.toDouble(),
      budgetMax: (json['budget_max'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      savedAt: DateTime.parse(json['saved_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'make_id': makeId,
    'make_name': makeName,
    'model_id': modelId,
    'model_name': modelName,
    'year': year,
    'vin': vin,
    'engine_code': engineCode,
    'selected_parts': selectedParts,
    'urgency_level': urgencyLevel,
    'budget_min': budgetMin,
    'budget_max': budgetMax,
    'notes': notes,
    'saved_at': savedAt.toIso8601String(),
  };

  bool get isEmpty =>
      makeId == null &&
      modelId == null &&
      year == null &&
      selectedParts.isEmpty;

  bool get hasVehicleInfo =>
      makeId != null && modelId != null && year != null;
}

/// Request Template Model
class RequestTemplate {
  final String id;
  final String name;
  final String? makeId;
  final String? makeName;
  final String? modelId;
  final String? modelName;
  final List<Map<String, dynamic>> parts;
  final DateTime createdAt;

  RequestTemplate({
    required this.id,
    required this.name,
    this.makeId,
    this.makeName,
    this.modelId,
    this.modelName,
    this.parts = const [],
    required this.createdAt,
  });

  factory RequestTemplate.fromJson(Map<String, dynamic> json) {
    return RequestTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      makeId: json['make_id'] as String?,
      makeName: json['make_name'] as String?,
      modelId: json['model_id'] as String?,
      modelName: json['model_name'] as String?,
      parts: (json['parts'] as List?)
          ?.map((p) => Map<String, dynamic>.from(p))
          .toList() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'make_id': makeId,
    'make_name': makeName,
    'model_id': modelId,
    'model_name': modelName,
    'parts': parts,
    'created_at': createdAt.toIso8601String(),
  };
}

/// Draft Service
/// 
/// Manages request drafts and templates for quick re-use
class DraftService {
  final StorageService _storageService;
  
  static const String _draftKey = 'request_draft';
  static const String _templatesKey = 'request_templates';

  DraftService(this._storageService);

  // ===========================================
  // DRAFT MANAGEMENT
  // ===========================================

  /// Save current request as draft
  Future<void> saveDraft(RequestDraft draft) async {
    final json = jsonEncode(draft.toJson());
    await _storageService.saveString(_draftKey, json);
  }

  /// Load saved draft
  Future<RequestDraft?> loadDraft() async {
    try {
      final json = await _storageService.getString(_draftKey);
      if (json == null) return null;
      
      final data = jsonDecode(json) as Map<String, dynamic>;
      return RequestDraft.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Clear draft
  Future<void> clearDraft() async {
    await _storageService.deleteKey(_draftKey);
  }

  /// Check if draft exists
  Future<bool> hasDraft() async {
    final draft = await loadDraft();
    return draft != null && !draft.isEmpty;
  }

  // ===========================================
  // TEMPLATE MANAGEMENT
  // ===========================================

  /// Get all templates
  Future<List<RequestTemplate>> getTemplates() async {
    try {
      final json = await _storageService.getString(_templatesKey);
      if (json == null) return [];
      
      final data = jsonDecode(json) as List;
      return data
          .map((t) => RequestTemplate.fromJson(t as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save a new template
  Future<void> saveTemplate(RequestTemplate template) async {
    final templates = await getTemplates();
    templates.add(template);
    
    final json = jsonEncode(templates.map((t) => t.toJson()).toList());
    await _storageService.saveString(_templatesKey, json);
  }

  /// Delete a template
  Future<void> deleteTemplate(String templateId) async {
    final templates = await getTemplates();
    templates.removeWhere((t) => t.id == templateId);
    
    final json = jsonEncode(templates.map((t) => t.toJson()).toList());
    await _storageService.saveString(_templatesKey, json);
  }

  /// Create template from current request
  RequestTemplate createTemplateFromRequest({
    required String name,
    String? makeId,
    String? makeName,
    String? modelId,
    String? modelName,
    required List<Map<String, dynamic>> parts,
  }) {
    return RequestTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      makeId: makeId,
      makeName: makeName,
      modelId: modelId,
      modelName: modelName,
      parts: parts,
      createdAt: DateTime.now(),
    );
  }
}
