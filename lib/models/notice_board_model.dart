class NoticeBoardModel {
  final String id;
  final String message;
  final NoticeType type;
  final DateTime createdAt;
  final String createdBy;
  final bool isActive;

  NoticeBoardModel({
    required this.id,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.createdBy,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'isActive': isActive,
    };
  }

  factory NoticeBoardModel.fromMap(Map<String, dynamic> map, String id) {
    return NoticeBoardModel(
      id: id,
      message: map['message'] ?? '',
      type: NoticeType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NoticeType.info,
      ),
      createdAt: DateTime.parse(map['createdAt']),
      createdBy: map['createdBy'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }

  NoticeBoardModel copyWith({
    String? id,
    String? message,
    NoticeType? type,
    DateTime? createdAt,
    String? createdBy,
    bool? isActive,
  }) {
    return NoticeBoardModel(
      id: id ?? this.id,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
    );
  }
}

enum NoticeType {
  success,
  warning,
  danger,
  info,
}

extension NoticeTypeExtension on NoticeType {
  String get displayName {
    switch (this) {
      case NoticeType.success:
        return 'Success';
      case NoticeType.warning:
        return 'Warning';
      case NoticeType.danger:
        return 'Danger';
      case NoticeType.info:
        return 'Info';
    }
  }

  String get icon {
    switch (this) {
      case NoticeType.success:
        return 'check_circle';
      case NoticeType.warning:
        return 'warning';
      case NoticeType.danger:
        return 'error';
      case NoticeType.info:
        return 'info';
    }
  }
}
