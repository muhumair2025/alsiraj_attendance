import 'package:flutter/foundation.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  
  Map<String, dynamic>? _attendanceSummary;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? get attendanceSummary => _attendanceSummary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> markAttendance({
    required String courseId,
    required String classId,
    required UserModel student,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if already marked
      final hasMarked = await _firestoreService.hasMarkedAttendance(
        courseId,
        classId,
        student.uid,
      );

      if (hasMarked) {
        _errorMessage = 'You have already marked attendance for this class.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final attendance = AttendanceModel(
        id: student.uid,
        classId: classId,
        courseId: courseId,
        studentId: student.uid,
        studentName: student.name,
        studentEmail: student.email,
        markedAt: DateTime.now(),
        isPresent: true,
      );

      await _firestoreService.markAttendance(attendance);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadAttendanceSummary(String courseId, String classId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _attendanceSummary = await _firestoreService.getAttendanceSummary(
        courseId,
        classId,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSummary() {
    _attendanceSummary = null;
    notifyListeners();
  }
}

