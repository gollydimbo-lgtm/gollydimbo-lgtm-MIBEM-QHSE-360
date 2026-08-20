/// Modèles de données légers (pas de génération de code, mapping manuel
/// depuis/vers JSON pour rester simple et lisible sur un projet de cette taille).
library;

class AuthUser {
  final String id;
  final String email;
  final String role;
  final String employeeId;
  final String employeeFullName;

  AuthUser({
    required this.id,
    required this.email,
    required this.role,
    required this.employeeId,
    required this.employeeFullName,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final employee = json['employee'] as Map<String, dynamic>;
    return AuthUser(
      id: json['id'],
      email: json['email'],
      role: json['role'],
      employeeId: employee['id'],
      employeeFullName: '${employee['firstName']} ${employee['lastName']}',
    );
  }
}

class ProductionLine {
  final String id;
  final String code;
  final String name;

  ProductionLine({required this.id, required this.code, required this.name});

  factory ProductionLine.fromJson(Map<String, dynamic> json) =>
      ProductionLine(id: json['id'], code: json['code'], name: json['name']);
}

class ProductFormat {
  final String id;
  final String label;

  ProductFormat({required this.id, required this.label});

  factory ProductFormat.fromJson(Map<String, dynamic> json) =>
      ProductFormat(id: json['id'], label: json['label']);
}

class ProductRef {
  final String id;
  final String name;
  final List<ProductFormat> formats;

  ProductRef({required this.id, required this.name, required this.formats});

  factory ProductRef.fromJson(Map<String, dynamic> json) => ProductRef(
        id: json['id'],
        name: json['name'],
        formats: (json['formats'] as List)
            .map((f) => ProductFormat.fromJson(f))
            .toList(),
      );
}

class ReferenceData {
  final List<ProductionLine> productionLines;
  final List<ProductRef> products;

  ReferenceData({required this.productionLines, required this.products});

  factory ReferenceData.fromJson(Map<String, dynamic> json) => ReferenceData(
        productionLines: (json['productionLines'] as List)
            .map((l) => ProductionLine.fromJson(l))
            .toList(),
        products:
            (json['products'] as List).map((p) => ProductRef.fromJson(p)).toList(),
      );
}

enum ControlPointType { booleen, numerique, texte, choixMultiple, photo }

ControlPointType controlPointTypeFromString(String value) {
  switch (value) {
    case 'NUMERIQUE':
      return ControlPointType.numerique;
    case 'TEXTE':
      return ControlPointType.texte;
    case 'CHOIX_MULTIPLE':
      return ControlPointType.choixMultiple;
    case 'PHOTO':
      return ControlPointType.photo;
    default:
      return ControlPointType.booleen;
  }
}

class ControlPoint {
  final String id;
  final String code;
  final String description;
  final int sequence;
  final ControlPointType type;
  final String? unit;
  final double? minValue;
  final double? maxValue;
  final List<String> options;
  final bool isCritical;
  final bool requiresPhoto;

  ControlPoint({
    required this.id,
    required this.code,
    required this.description,
    required this.sequence,
    required this.type,
    this.unit,
    this.minValue,
    this.maxValue,
    this.options = const [],
    this.isCritical = false,
    this.requiresPhoto = false,
  });

  factory ControlPoint.fromJson(Map<String, dynamic> json) => ControlPoint(
        id: json['id'],
        code: json['code'],
        description: json['description'],
        sequence: json['sequence'],
        type: controlPointTypeFromString(json['type'] ?? 'BOOLEEN'),
        unit: json['unit'],
        minValue: json['minValue'] != null ? double.tryParse('${json['minValue']}') : null,
        maxValue: json['maxValue'] != null ? double.tryParse('${json['maxValue']}') : null,
        options: (json['options'] as String?)?.split('|') ?? const [],
        isCritical: json['isCritical'] ?? false,
        requiresPhoto: json['requiresPhoto'] ?? false,
      );
}

class ControlTemplate {
  final String id;
  final String code;
  final String name;
  final List<ControlPoint> points;

  ControlTemplate({
    required this.id,
    required this.code,
    required this.name,
    required this.points,
  });

  factory ControlTemplate.fromJson(Map<String, dynamic> json) => ControlTemplate(
        id: json['id'],
        code: json['code'],
        name: json['name'],
        points: (json['points'] as List)
            .map((p) => ControlPoint.fromJson(p))
            .toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence)),
      );
}

class DashboardOverview {
  final int controls;
  final int nonConformities;
  final int criticalNonConformities;
  final int openNonConformities;
  final int actions;
  final int overdueActions;
  final int pendingSync;
  final double complianceRate;

  DashboardOverview({
    required this.controls,
    required this.nonConformities,
    required this.criticalNonConformities,
    required this.openNonConformities,
    required this.actions,
    required this.overdueActions,
    required this.pendingSync,
    required this.complianceRate,
  });

  factory DashboardOverview.fromJson(Map<String, dynamic> json) => DashboardOverview(
        controls: json['controls'] ?? 0,
        nonConformities: json['nonConformities'] ?? 0,
        criticalNonConformities: json['criticalNonConformities'] ?? 0,
        openNonConformities: json['openNonConformities'] ?? 0,
        actions: json['actions'] ?? 0,
        overdueActions: json['overdueActions'] ?? 0,
        pendingSync: json['pendingSync'] ?? 0,
        complianceRate: (json['complianceRate'] ?? 100).toDouble(),
      );
}

class NonConformitySummary {
  final String id;
  final String reference;
  final String description;
  final String category;
  final String severity;
  final String status;
  final DateTime detectedAt;
  final DateTime? dueDate;

  NonConformitySummary({
    required this.id,
    required this.reference,
    required this.description,
    required this.category,
    required this.severity,
    required this.status,
    required this.detectedAt,
    this.dueDate,
  });

  factory NonConformitySummary.fromJson(Map<String, dynamic> json) => NonConformitySummary(
        id: json['id'],
        reference: json['reference'],
        description: json['description'],
        category: json['category'],
        severity: json['severity'],
        status: json['status'],
        detectedAt: DateTime.parse(json['detectedAt']),
        dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      );
}

class ActionSummary {
  final String id;
  final String reference;
  final String description;
  final String priority;
  final String status;
  final DateTime dueDate;

  ActionSummary({
    required this.id,
    required this.reference,
    required this.description,
    required this.priority,
    required this.status,
    required this.dueDate,
  });

  factory ActionSummary.fromJson(Map<String, dynamic> json) => ActionSummary(
        id: json['id'],
        reference: json['reference'],
        description: json['description'],
        priority: json['priority'],
        status: json['status'],
        dueDate: DateTime.parse(json['dueDate']),
      );
}

// ---- V3 Phase 2 : Risques ----

class RiskSummary {
  final String id;
  final String reference;
  final String title;
  final String category;
  final String status;
  final String? initialLevel;
  final DateTime identifiedAt;

  RiskSummary({
    required this.id,
    required this.reference,
    required this.title,
    required this.category,
    required this.status,
    this.initialLevel,
    required this.identifiedAt,
  });

  factory RiskSummary.fromJson(Map<String, dynamic> json) => RiskSummary(
        id: json['id'],
        reference: json['reference'],
        title: json['title'],
        category: json['category'],
        status: json['status'],
        initialLevel: json['initialLevel'],
        identifiedAt: DateTime.parse(json['identifiedAt']),
      );
}

// ---- V3 Phase 2 : Événements Sécurité ----

class SafetyEventSummary {
  final String id;
  final String reference;
  final String title;
  final String type;
  final String severity;
  final String status;
  final DateTime reportedAt;

  SafetyEventSummary({
    required this.id,
    required this.reference,
    required this.title,
    required this.type,
    required this.severity,
    required this.status,
    required this.reportedAt,
  });

  factory SafetyEventSummary.fromJson(Map<String, dynamic> json) => SafetyEventSummary(
        id: json['id'],
        reference: json['reference'],
        title: json['title'],
        type: json['type'],
        severity: json['severity'],
        status: json['status'],
        reportedAt: DateTime.parse(json['reportedAt']),
      );
}
