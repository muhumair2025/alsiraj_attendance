enum FeeType {
  monthly,
  yearly,
  lifetime,
}

class FeeCourseModel {
  final String id;
  final String name;
  final String description;
  final FeeType feeType;
  final double amount;
  final String currency;
  final String createdBy; // uid of admin
  final DateTime createdAt;
  final bool isActive;
  final String? courseId; // Link to the course this fee is for (optional for backward compatibility)

  FeeCourseModel({
    required this.id,
    required this.name,
    required this.description,
    required this.feeType,
    required this.amount,
    this.currency = 'USD',
    required this.createdBy,
    required this.createdAt,
    this.isActive = true,
    this.courseId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'feeType': feeType.name,
      'amount': amount,
      'currency': currency,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'courseId': courseId,
    };
  }

  factory FeeCourseModel.fromMap(Map<String, dynamic> map, String id) {
    return FeeCourseModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      feeType: FeeType.values.firstWhere(
        (e) => e.name == map['feeType'],
        orElse: () => FeeType.monthly,
      ),
      amount: (map['amount'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? 'USD',
      createdBy: map['createdBy'] ?? '',
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
      isActive: map['isActive'] ?? true,
      courseId: map['courseId'],
    );
  }

  FeeCourseModel copyWith({
    String? id,
    String? name,
    String? description,
    FeeType? feeType,
    double? amount,
    String? currency,
    String? createdBy,
    DateTime? createdAt,
    bool? isActive,
    String? courseId,
  }) {
    return FeeCourseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      feeType: feeType ?? this.feeType,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      courseId: courseId ?? this.courseId,
    );
  }

  String get feeTypeDisplayName {
    switch (feeType) {
      case FeeType.monthly:
        return 'Monthly';
      case FeeType.yearly:
        return 'Yearly';
      case FeeType.lifetime:
        return 'Lifetime';
    }
  }
}
