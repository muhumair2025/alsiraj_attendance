class AttendanceModel {
  final String id;
  final String classId;
  final String courseId;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final DateTime markedAt;
  final bool isPresent;

  AttendanceModel({
    required this.id,
    required this.classId,
    required this.courseId,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.markedAt,
    this.isPresent = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'classId': classId,
      'courseId': courseId,
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'markedAt': markedAt.toIso8601String(),
      'isPresent': isPresent,
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map, String id) {
    return AttendanceModel(
      id: id,
      classId: map['classId'] ?? '',
      courseId: map['courseId'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentEmail: map['studentEmail'] ?? '',
      markedAt: map['markedAt'] != null 
          ? DateTime.parse(map['markedAt']) 
          : DateTime.now(),
      isPresent: map['isPresent'] ?? true,
    );
  }
}

