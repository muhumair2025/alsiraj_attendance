import 'package:flutter/material.dart';
import '../models/notice_board_model.dart';
import '../services/firestore_service.dart';

class NoticeBoardProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  
  List<NoticeBoardModel> _notices = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<NoticeBoardModel> get notices => _notices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get active notices only
  List<NoticeBoardModel> get activeNotices => 
      _notices.where((notice) => notice.isActive).toList();

  // Load all notices
  Future<void> loadNotices() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notices = await _firestoreService.getNotices();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create a new notice
  Future<String?> createNotice({
    required String message,
    required NoticeType type,
    required String createdBy,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final noticeId = await _firestoreService.createNotice(
        message: message,
        type: type,
        createdBy: createdBy,
      );
      
      // Reload notices to get the updated list
      await loadNotices();
      
      _isLoading = false;
      notifyListeners();
      return noticeId;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Update a notice
  Future<bool> updateNotice({
    required String noticeId,
    String? message,
    NoticeType? type,
    bool? isActive,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.updateNotice(
        noticeId: noticeId,
        message: message,
        type: type,
        isActive: isActive,
      );
      
      // Reload notices to get the updated list
      await loadNotices();
      
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

  // Delete a notice
  Future<bool> deleteNotice(String noticeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.deleteNotice(noticeId);
      
      // Reload notices to get the updated list
      await loadNotices();
      
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

  // Toggle notice active status
  Future<bool> toggleNoticeStatus(String noticeId) async {
    final notice = _notices.firstWhere((n) => n.id == noticeId);
    return await updateNotice(
      noticeId: noticeId,
      isActive: !notice.isActive,
    );
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
