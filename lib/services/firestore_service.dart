import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';
import '../models/class_model.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import '../models/notice_board_model.dart';
import '../models/fee_course_model.dart';
import '../models/fee_payment_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== COURSES ====================

  // Create course
  Future<String> createCourse(CourseModel course) async {
    try {
      final docRef = await _firestore.collection('courses').add(course.toMap());
      return docRef.id;
    } catch (e) {
      throw 'Error creating course: $e';
    }
  }

  // Get all courses
  Stream<List<CourseModel>> getCourses() {
    return _firestore
        .collection('courses')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CourseModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get course by ID
  Future<CourseModel?> getCourseById(String courseId) async {
    try {
      final doc = await _firestore.collection('courses').doc(courseId).get();
      if (doc.exists) {
        return CourseModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting course: $e');
      return null;
    }
  }

  // Update course
  Future<void> updateCourse(String courseId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('courses').doc(courseId).update(updates);
    } catch (e) {
      throw 'Error updating course: $e';
    }
  }

  // Delete course
  Future<void> deleteCourse(String courseId) async {
    try {
      print('🔍 Starting course deletion process for: $courseId');
      
      // Delete all classes in this course
      final classes = await _firestore
          .collection('courses')
          .doc(courseId)
          .collection('classes')
          .get();
      
      print('📚 Found ${classes.docs.length} classes to delete');
      
      for (var classDoc in classes.docs) {
        print('🗑️ Deleting class: ${classDoc.id}');
        await deleteClass(courseId, classDoc.id);
      }
      
      print('🗑️ Deleting course document: $courseId');
      await _firestore.collection('courses').doc(courseId).delete();
      print('✅ Course deletion completed: $courseId');
    } catch (e) {
      print('❌ Error in deleteCourse: $e');
      throw 'Error deleting course: $e';
    }
  }

  // ==================== CLASSES ====================

  // Create class
  Future<String> createClass(String courseId, ClassModel classModel) async {
    try {
      final docRef = await _firestore
          .collection('courses')
          .doc(courseId)
          .collection('classes')
          .add(classModel.toMap());
      return docRef.id;
    } catch (e) {
      throw 'Error creating class: $e';
    }
  }

  // Get classes for a course
  Stream<List<ClassModel>> getClasses(String courseId) {
    return _firestore
        .collection('courses')
        .doc(courseId)
        .collection('classes')
        .orderBy('startTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ClassModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get all upcoming classes (for students) - filtered by multiple courses
  Stream<List<Map<String, dynamic>>> getUpcomingClassesForCourses(List<String> courseIds) {
    if (courseIds.isEmpty) {
      return Stream.value([]);
    }

    final now = DateTime.now();
    
    return _firestore
        .collection('courses')
        .where(FieldPath.documentId, whereIn: courseIds)
        .snapshots()
        .asyncMap((courseSnapshot) async {
      List<Map<String, dynamic>> allClasses = [];
      
      for (var courseDoc in courseSnapshot.docs) {
        final course = CourseModel.fromMap(courseDoc.data(), courseDoc.id);
        
        final classesSnapshot = await _firestore
            .collection('courses')
            .doc(courseDoc.id)
            .collection('classes')
            .where('endTime', isGreaterThan: now.toIso8601String())
            .orderBy('endTime')
            .get();
        
        for (var classDoc in classesSnapshot.docs) {
          final classModel = ClassModel.fromMap(classDoc.data(), classDoc.id);
          allClasses.add({
            'course': course,
            'class': classModel,
          });
        }
      }
      
      // Sort by start time
      allClasses.sort((a, b) => 
        (a['class'] as ClassModel).startTime.compareTo(
          (b['class'] as ClassModel).startTime
        )
      );
      
      return allClasses;
    });
  }

  // Get all upcoming classes (for students) - filtered by single course
  Stream<List<Map<String, dynamic>>> getUpcomingClassesForCourse(String courseId) {
    return getUpcomingClassesForCourses([courseId]);
  }

  // Get all upcoming classes (for students)
  Stream<List<Map<String, dynamic>>> getAllUpcomingClasses() {
    final now = DateTime.now();
    
    return _firestore
        .collection('courses')
        .snapshots()
        .asyncMap((courseSnapshot) async {
      List<Map<String, dynamic>> allClasses = [];
      
      for (var courseDoc in courseSnapshot.docs) {
        final course = CourseModel.fromMap(courseDoc.data(), courseDoc.id);
        
        final classesSnapshot = await _firestore
            .collection('courses')
            .doc(courseDoc.id)
            .collection('classes')
            .where('endTime', isGreaterThan: now.toIso8601String())
            .orderBy('endTime')
            .get();
        
        for (var classDoc in classesSnapshot.docs) {
          final classModel = ClassModel.fromMap(classDoc.data(), classDoc.id);
          allClasses.add({
            'course': course,
            'class': classModel,
          });
        }
      }
      
      // Sort by start time
      allClasses.sort((a, b) => 
        (a['class'] as ClassModel).startTime.compareTo(
          (b['class'] as ClassModel).startTime
        )
      );
      
      return allClasses;
    });
  }

  // Get class by ID
  Future<ClassModel?> getClassById(String courseId, String classId) async {
    try {
      final doc = await _firestore
          .collection('courses')
          .doc(courseId)
          .collection('classes')
          .doc(classId)
          .get();
      
      if (doc.exists) {
        return ClassModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting class: $e');
      return null;
    }
  }

  // Update class
  Future<void> updateClass(String courseId, String classId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection('courses')
          .doc(courseId)
          .collection('classes')
          .doc(classId)
          .update(updates);
    } catch (e) {
      throw 'Error updating class: $e';
    }
  }

  // Delete class
  Future<void> deleteClass(String courseId, String classId) async {
    try {
      // Delete all attendance records for this class
      final attendanceRecords = await _firestore
          .collection('courses')
          .doc(courseId)
          .collection('classes')
          .doc(classId)
          .collection('attendance')
          .get();
      
      for (var doc in attendanceRecords.docs) {
        await doc.reference.delete();
      }
      
      await _firestore
          .collection('courses')
          .doc(courseId)
          .collection('classes')
          .doc(classId)
          .delete();
    } catch (e) {
      throw 'Error deleting class: $e';
    }
  }

  // ==================== USERS ====================

  // Update user's selected courses
  Future<void> updateUserCourses(String userId, List<String> courseIds) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'selectedCourseIds': courseIds,
      });
    } catch (e) {
      throw 'Error updating user courses: $e';
    }
  }

  // Update user's selected course (backward compatibility)
  Future<void> updateUserCourse(String userId, String courseId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'selectedCourseIds': [courseId],
      });
    } catch (e) {
      throw 'Error updating user course: $e';
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // ==================== ATTENDANCE ====================

  // Mark attendance
  Future<void> markAttendance(AttendanceModel attendance) async {
    try {
      await _firestore
          .collection('courses')
          .doc(attendance.courseId)
          .collection('classes')
          .doc(attendance.classId)
          .collection('attendance')
          .doc(attendance.studentId)
          .set(attendance.toMap());
    } catch (e) {
      throw 'Error marking attendance: $e';
    }
  }

  // Check if student has already marked attendance
  Future<bool> hasMarkedAttendance(String courseId, String classId, String studentId) async {
    try {
      final doc = await _firestore
          .collection('courses')
          .doc(courseId)
          .collection('classes')
          .doc(classId)
          .collection('attendance')
          .doc(studentId)
          .get();
      
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get attendance for a class
  Stream<List<AttendanceModel>> getClassAttendance(String courseId, String classId) {
    return _firestore
        .collection('courses')
        .doc(courseId)
        .collection('classes')
        .doc(classId)
        .collection('attendance')
        .orderBy('markedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AttendanceModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get all students for attendance report
  Future<List<UserModel>> getAllStudents() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
      
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting students: $e');
      return [];
    }
  }

  // Get attendance summary for a class
  Future<Map<String, dynamic>> getAttendanceSummary(String courseId, String classId) async {
    try {
      final attendanceSnapshot = await _firestore
          .collection('courses')
          .doc(courseId)
          .collection('classes')
          .doc(classId)
          .collection('attendance')
          .get();
      
      final allStudents = await getAllStudents();
      final presentStudents = attendanceSnapshot.docs
          .map((doc) => AttendanceModel.fromMap(doc.data(), doc.id))
          .toList();
      
      final presentIds = presentStudents.map((a) => a.studentId).toSet();
      final absentStudents = allStudents
          .where((student) => !presentIds.contains(student.uid))
          .toList();
      
      return {
        'present': presentStudents,
        'absent': absentStudents,
        'totalStudents': allStudents.length,
        'presentCount': presentStudents.length,
        'absentCount': absentStudents.length,
      };
    } catch (e) {
      print('Error getting attendance summary: $e');
      return {
        'present': [],
        'absent': [],
        'totalStudents': 0,
        'presentCount': 0,
        'absentCount': 0,
      };
    }
  }

  // Get student attendance statistics - filtered by multiple courses
  Stream<List<Map<String, dynamic>>> getStudentAttendanceStatsForCourses(String studentId, List<String> courseIds) {
    if (studentId.isEmpty || courseIds.isEmpty) {
      return Stream.value([]);
    }
    
    return _firestore
        .collection('courses')
        .where(FieldPath.documentId, whereIn: courseIds)
        .snapshots()
        .asyncMap((courseSnapshot) async {
      List<Map<String, dynamic>> attendanceStats = [];
      
      for (var courseDoc in courseSnapshot.docs) {
        final courseId = courseDoc.id;
        final courseName = courseDoc.data()['name'] ?? 'Unknown Course';
        
        final classesSnapshot = await _firestore
            .collection('courses')
            .doc(courseId)
            .collection('classes')
            .get();
        
        for (var classDoc in classesSnapshot.docs) {
          // Check if student marked attendance for this class
          final attendanceDoc = await _firestore
              .collection('courses')
              .doc(courseId)
              .collection('classes')
              .doc(classDoc.id)
              .collection('attendance')
              .doc(studentId)
              .get();
          
          final classData = classDoc.data();
          final classStartTime = DateTime.parse(classData['startTime']);
          final now = DateTime.now();
          
          // Only include past classes in stats
          if (classStartTime.isBefore(now)) {
            attendanceStats.add({
              'id': classDoc.id,
              'courseId': courseId,
              'courseName': courseName,
              'status': attendanceDoc.exists ? 'present' : 'absent',
              'timestamp': classData['startTime'],
              'className': classData['className'],
            });
          }
        }
      }
      
      return attendanceStats;
    }).handleError((error) {
      print('Error loading attendance stats: $error');
      return <Map<String, dynamic>>[];
    });
  }

  // Get student attendance statistics - filtered by single course
  Stream<List<Map<String, dynamic>>> getStudentAttendanceStatsForCourse(String studentId, String courseId) {
    return getStudentAttendanceStatsForCourses(studentId, [courseId]);
  }

  // Get student attendance statistics
  Stream<List<Map<String, dynamic>>> getStudentAttendanceStats(String studentId) {
    if (studentId.isEmpty) {
      return Stream.value([]);
    }
    
    return _firestore
        .collectionGroup('attendance')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .handleError((error) {
          print('Error loading attendance stats: $error');
          return [];
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'status': doc.data()['status'] ?? 'present',
                  'timestamp': doc.data()['timestamp'],
                })
            .toList());
  }

  // ==================== NOTICE BOARD ====================

  // Create notice
  Future<String> createNotice({
    required String message,
    required NoticeType type,
    required String createdBy,
  }) async {
    try {
      final notice = NoticeBoardModel(
        id: '', // Will be set by Firestore
        message: message,
        type: type,
        createdAt: DateTime.now(),
        createdBy: createdBy,
        isActive: true,
      );

      final docRef = await _firestore.collection('notices').add(notice.toMap());
      return docRef.id;
    } catch (e) {
      throw 'Error creating notice: $e';
    }
  }

  // Get all notices
  Future<List<NoticeBoardModel>> getNotices() async {
    try {
      final snapshot = await _firestore
          .collection('notices')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => NoticeBoardModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Error getting notices: $e';
    }
  }

  // Get active notices stream (for real-time updates)
  Stream<List<NoticeBoardModel>> getActiveNoticesStream() {
    return _firestore
        .collection('notices')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NoticeBoardModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Update notice
  Future<void> updateNotice({
    required String noticeId,
    String? message,
    NoticeType? type,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (message != null) updates['message'] = message;
      if (type != null) updates['type'] = type.name;
      if (isActive != null) updates['isActive'] = isActive;

      await _firestore.collection('notices').doc(noticeId).update(updates);
    } catch (e) {
      throw 'Error updating notice: $e';
    }
  }

  // Delete notice
  Future<void> deleteNotice(String noticeId) async {
    try {
      await _firestore.collection('notices').doc(noticeId).delete();
    } catch (e) {
      throw 'Error deleting notice: $e';
    }
  }

  // ==================== FEE COURSES ====================

  // Create fee course
  Future<String> createFeeCourse(FeeCourseModel feeCourse) async {
    try {
      final docRef = await _firestore.collection('fee_courses').add(feeCourse.toMap());
      return docRef.id;
    } catch (e) {
      throw 'Error creating fee course: $e';
    }
  }

  // Get all fee courses
  Stream<List<FeeCourseModel>> getFeeCourses() {
    return _firestore
        .collection('fee_courses')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FeeCourseModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get fee course by ID
  Future<FeeCourseModel?> getFeeCourseById(String feeCourseId) async {
    try {
      final doc = await _firestore.collection('fee_courses').doc(feeCourseId).get();
      if (doc.exists) {
        return FeeCourseModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting fee course: $e');
      return null;
    }
  }

  // Update fee course
  Future<void> updateFeeCourse(String feeCourseId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('fee_courses').doc(feeCourseId).update(updates);
    } catch (e) {
      throw 'Error updating fee course: $e';
    }
  }

  // Delete fee course (soft delete)
  Future<void> deleteFeeCourse(String feeCourseId) async {
    try {
      await _firestore.collection('fee_courses').doc(feeCourseId).update({
        'isActive': false,
      });
    } catch (e) {
      throw 'Error deleting fee course: $e';
    }
  }

  // ==================== FEE PAYMENTS ====================

  // Submit fee payment
  Future<String> submitFeePayment(FeePaymentModel payment) async {
    try {
      final docRef = await _firestore.collection('fee_payments').add(payment.toMap());
      return docRef.id;
    } catch (e) {
      throw 'Error submitting fee payment: $e';
    }
  }

  // Get all fee payments (for admin)
  Stream<List<FeePaymentModel>> getAllFeePayments() {
    return _firestore
        .collection('fee_payments')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FeePaymentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get fee payments by status
  Stream<List<FeePaymentModel>> getFeePaymentsByStatus(PaymentStatus status) {
    return _firestore
        .collection('fee_payments')
        .where('status', isEqualTo: status.name)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FeePaymentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get fee payments by student
  Stream<List<FeePaymentModel>> getFeePaymentsByStudent(String studentId) {
    return _firestore
        .collection('fee_payments')
        .where('studentId', isEqualTo: studentId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FeePaymentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Update fee payment status (approve/reject)
  Future<void> updateFeePaymentStatus({
    required String paymentId,
    required PaymentStatus status,
    required String reviewedBy,
    String? adminNotes,
    String? rejectionReason,
  }) async {
    try {
      final updates = {
        'status': status.name,
        'reviewedBy': reviewedBy,
        'reviewedAt': DateTime.now().toIso8601String(),
      };

      if (adminNotes != null) {
        updates['adminNotes'] = adminNotes;
      }

      if (rejectionReason != null) {
        updates['rejectionReason'] = rejectionReason;
      }

      await _firestore.collection('fee_payments').doc(paymentId).update(updates);
    } catch (e) {
      throw 'Error updating fee payment status: $e';
    }
  }

  // Check if student has already paid for a fee course
  Future<bool> hasStudentPaidForFeeCourse(String studentId, String feeCourseId) async {
    try {
      final snapshot = await _firestore
          .collection('fee_payments')
          .where('studentId', isEqualTo: studentId)
          .where('feeCourseId', isEqualTo: feeCourseId)
          .where('status', isEqualTo: PaymentStatus.approved.name)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking student payment: $e');
      return false;
    }
  }

  // Get fee payment by ID
  Future<FeePaymentModel?> getFeePaymentById(String paymentId) async {
    try {
      final doc = await _firestore.collection('fee_payments').doc(paymentId).get();
      if (doc.exists) {
        return FeePaymentModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting fee payment: $e');
      return null;
    }
  }

  // Get the last approved payment for a student and course
  Future<FeePaymentModel?> getLastApprovedPayment({
    required String studentId,
    required String feeCourseId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('fee_payments')
          .where('studentId', isEqualTo: studentId)
          .where('feeCourseId', isEqualTo: feeCourseId)
          .where('status', isEqualTo: PaymentStatus.approved.name)
          .orderBy('reviewedAt', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return FeePaymentModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      print('Error getting last approved payment: $e');
      return null;
    }
  }

  // Check if student has a pending payment for a course
  Future<bool> hasPendingPaymentForCourse({
    required String studentId,
    required String feeCourseId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('fee_payments')
          .where('studentId', isEqualTo: studentId)
          .where('feeCourseId', isEqualTo: feeCourseId)
          .where('status', isEqualTo: PaymentStatus.pending.name)
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking pending payment: $e');
      return false;
    }
  }
}

