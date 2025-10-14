class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'admin', 'teacher', 'student'
  final DateTime createdAt;
  final bool isActive; // true = active, false = deleted/inactive
  final String? fcmToken; // Firebase Cloud Messaging token for notifications
  final List<String> selectedCourseIds; // Course IDs that student is enrolled in

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    this.isActive = true,
    this.fcmToken,
    this.selectedCourseIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'fcmToken': fcmToken,
      'selectedCourseIds': selectedCourseIds,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'student',
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
      isActive: map['isActive'] ?? true,
      fcmToken: map['fcmToken'],
      selectedCourseIds: map['selectedCourseIds'] != null 
          ? List<String>.from(map['selectedCourseIds'])
          : (map['selectedCourseId'] != null ? [map['selectedCourseId']] : []), // Backward compatibility
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    DateTime? createdAt,
    bool? isActive,
    String? fcmToken,
    List<String>? selectedCourseIds,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      fcmToken: fcmToken ?? this.fcmToken,
      selectedCourseIds: selectedCourseIds ?? this.selectedCourseIds,
    );
  }
}

