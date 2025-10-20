import 'package:flutter/foundation.dart';
import '../models/fee_course_model.dart';
import '../services/firestore_service.dart';

class FeeCourseProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  
  List<FeeCourseModel> _feeCourses = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<FeeCourseModel> get feeCourses => _feeCourses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void loadFeeCourses() {
    _firestoreService.getFeeCourses().listen((courses) {
      _feeCourses = courses;
      notifyListeners();
    });
  }

  Future<bool> createFeeCourse({
    required String name,
    required String description,
    required FeeType feeType,
    required double amount,
    required String currency,
    required String createdBy,
    String? courseId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final feeCourse = FeeCourseModel(
        id: '',
        name: name,
        description: description,
        feeType: feeType,
        amount: amount,
        currency: currency,
        createdBy: createdBy,
        createdAt: DateTime.now(),
        courseId: courseId,
      );

      await _firestoreService.createFeeCourse(feeCourse);
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

  Future<bool> updateFeeCourse({
    required String feeCourseId,
    String? name,
    String? description,
    FeeType? feeType,
    double? amount,
    String? currency,
    String? courseId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updates = <String, dynamic>{};
      
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (feeType != null) updates['feeType'] = feeType.name;
      if (amount != null) updates['amount'] = amount;
      if (currency != null) updates['currency'] = currency;
      if (courseId != null) updates['courseId'] = courseId;

      await _firestoreService.updateFeeCourse(feeCourseId, updates);
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

  Future<bool> deleteFeeCourse(String feeCourseId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.deleteFeeCourse(feeCourseId);
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

  Future<FeeCourseModel?> getFeeCourseById(String feeCourseId) async {
    try {
      return await _firestoreService.getFeeCourseById(feeCourseId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
