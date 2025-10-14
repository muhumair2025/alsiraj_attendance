class ClassModel {
  final String id;
  final String courseId;
  final String className;
  final String zoomLink;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime createdAt;

  ClassModel({
    required this.id,
    required this.courseId,
    required this.className,
    required this.zoomLink,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
  });

  bool isAttendanceOpen() {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'className': className,
      'zoomLink': zoomLink,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ClassModel.fromMap(Map<String, dynamic> map, String id) {
    return ClassModel(
      id: id,
      courseId: map['courseId'] ?? '',
      className: map['className'] ?? '',
      zoomLink: map['zoomLink'] ?? '',
      startTime: map['startTime'] != null 
          ? DateTime.parse(map['startTime']) 
          : DateTime.now(),
      endTime: map['endTime'] != null 
          ? DateTime.parse(map['endTime']) 
          : DateTime.now(),
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
    );
  }

  ClassModel copyWith({
    String? id,
    String? courseId,
    String? className,
    String? zoomLink,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? createdAt,
  }) {
    return ClassModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      className: className ?? this.className,
      zoomLink: zoomLink ?? this.zoomLink,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

