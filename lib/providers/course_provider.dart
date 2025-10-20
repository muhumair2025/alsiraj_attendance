import 'package:flutter/foundation.dart';
import '../models/course_model.dart';
import '../models/class_model.dart';
import '../services/firestore_service.dart';

class CourseProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  
  List<CourseModel> _courses = [];
  List<Map<String, dynamic>> _upcomingClasses = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CourseModel> get courses => _courses;
  List<Map<String, dynamic>> get upcomingClasses => _upcomingClasses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void loadCourses() {
    _firestoreService.getCourses().listen((courses) {
      _courses = courses;
      notifyListeners();
    });
  }

  void loadUpcomingClasses() {
    _firestoreService.getAllUpcomingClasses().listen((classes) {
      _upcomingClasses = classes;
      notifyListeners();
    });
  }

  void loadUpcomingClassesForCourses(List<String> courseIds) {
    _firestoreService.getUpcomingClassesForCourses(courseIds).listen((classes) {
      _upcomingClasses = classes;
      notifyListeners();
    });
  }

  void loadUpcomingClassesForCourse(String courseId) {
    _firestoreService.getUpcomingClassesForCourse(courseId).listen((classes) {
      _upcomingClasses = classes;
      notifyListeners();
    });
  }

  Future<bool> createCourse(String name, String description, String createdBy) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final course = CourseModel(
        id: '',
        name: name,
        description: description,
        createdBy: createdBy,
        createdAt: DateTime.now(),
      );

      await _firestoreService.createCourse(course);
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

  Future<String?> createClass({
    required String courseId,
    required String className,
    required String zoomLink,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final classModel = ClassModel(
        id: '',
        courseId: courseId,
        className: className,
        zoomLink: zoomLink,
        startTime: startTime,
        endTime: endTime,
        createdAt: DateTime.now(),
      );

      final classId = await _firestoreService.createClass(courseId, classModel);
      _isLoading = false;
      notifyListeners();
      return classId;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteCourse(String courseId) async {
    try {
      print('🗑️ Attempting to delete course: $courseId');
      await _firestoreService.deleteCourse(courseId);
      print('✅ Course deleted successfully: $courseId');
    } catch (e) {
      print('❌ Error deleting course: $e');
      _errorMessage = e.toString();
      notifyListeners();
      rethrow; // Re-throw to let the UI handle the error
    }
  }

  Future<bool> updateClass({
    required String courseId,
    required String classId,
    required String className,
    required String zoomLink,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final classModel = ClassModel(
        id: classId,
        courseId: courseId,
        className: className,
        zoomLink: zoomLink,
        startTime: startTime,
        endTime: endTime,
        createdAt: DateTime.now(), // Keep original creation time
      );

      await _firestoreService.updateClass(courseId, classId, classModel.toMap());
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

  Future<void> deleteClass(String courseId, String classId) async {
    try {
      await _firestoreService.deleteClass(courseId, classId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

