import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/fee_payment_model.dart';
import '../services/firestore_service.dart';

class FeePaymentProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  
  List<FeePaymentModel> _allPayments = [];
  List<FeePaymentModel> _studentPayments = [];
  List<FeePaymentModel> _pendingPayments = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Stream subscriptions to manage
  StreamSubscription? _allPaymentsSubscription;
  StreamSubscription? _pendingPaymentsSubscription;
  StreamSubscription? _studentPaymentsSubscription;

  List<FeePaymentModel> get allPayments => _allPayments;
  List<FeePaymentModel> get studentPayments => _studentPayments;
  List<FeePaymentModel> get pendingPayments => _pendingPayments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Load all payments (for admin)
  void loadAllPayments() {
    _allPaymentsSubscription?.cancel();
    _allPaymentsSubscription = _firestoreService.getAllFeePayments().listen((payments) {
      _allPayments = payments;
      notifyListeners();
    });
  }

  // Load pending payments (for admin)
  void loadPendingPayments() {
    _pendingPaymentsSubscription?.cancel();
    _pendingPaymentsSubscription = _firestoreService.getFeePaymentsByStatus(PaymentStatus.pending).listen((payments) {
      _pendingPayments = payments;
      notifyListeners();
    });
  }
  
  @override
  void dispose() {
    _allPaymentsSubscription?.cancel();
    _pendingPaymentsSubscription?.cancel();
    _studentPaymentsSubscription?.cancel();
    super.dispose();
  }

  // Load student's payments
  Future<void> loadStudentPayments(String studentId) async {
    _studentPaymentsSubscription?.cancel();
    _studentPaymentsSubscription = _firestoreService.getFeePaymentsByStudent(studentId).listen((payments) {
      // Sort by submission date - newest first
      payments.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      _studentPayments = payments;
      notifyListeners();
    });
    // Wait a moment for the stream to emit at least once
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Submit fee payment
  Future<bool> submitFeePayment({
    required String studentId,
    required String studentName,
    required String studentEmail,
    required String feeCourseId,
    required String feeCourseName,
    required double amount,
    required String currency,
    required String paymentScreenshotUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payment = FeePaymentModel(
        id: '',
        studentId: studentId,
        studentName: studentName,
        studentEmail: studentEmail,
        feeCourseId: feeCourseId,
        feeCourseName: feeCourseName,
        amount: amount,
        currency: currency,
        paymentScreenshotUrl: paymentScreenshotUrl,
        submittedAt: DateTime.now(),
      );

      await _firestoreService.submitFeePayment(payment);
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

  // Approve payment
  Future<bool> approvePayment({
    required String paymentId,
    required String reviewedBy,
    String? adminNotes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.updateFeePaymentStatus(
        paymentId: paymentId,
        status: PaymentStatus.approved,
        reviewedBy: reviewedBy,
        adminNotes: adminNotes,
      );
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

  // Reject payment
  Future<bool> rejectPayment({
    required String paymentId,
    required String reviewedBy,
    required String rejectionReason,
    String? adminNotes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.updateFeePaymentStatus(
        paymentId: paymentId,
        status: PaymentStatus.rejected,
        reviewedBy: reviewedBy,
        rejectionReason: rejectionReason,
        adminNotes: adminNotes,
      );
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

  // Check if student has paid for a course
  Future<bool> hasStudentPaidForCourse(String studentId, String feeCourseId) async {
    try {
      return await _firestoreService.hasStudentPaidForFeeCourse(studentId, feeCourseId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Get payment by ID
  Future<FeePaymentModel?> getPaymentById(String paymentId) async {
    try {
      return await _firestoreService.getFeePaymentById(paymentId);
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

  // Check if student can submit payment for a course based on fee type
  Future<Map<String, dynamic>> canSubmitPaymentForCourse({
    required String studentId,
    required String feeCourseId,
    required String feeType, // 'monthly', 'yearly', or 'lifetime'
  }) async {
    try {
      // First check if there's a pending payment for this course
      final hasPending = await _firestoreService.hasPendingPaymentForCourse(
        studentId: studentId,
        feeCourseId: feeCourseId,
      );

      if (hasPending) {
        return {
          'canSubmit': false,
          'message': 'You already have a pending payment submission for this course.\nPlease wait for admin approval or rejection before submitting again.',
        };
      }

      // Get the last approved payment for this student and course
      final lastApprovedPayment = await _firestoreService.getLastApprovedPayment(
        studentId: studentId,
        feeCourseId: feeCourseId,
      );

      // If no previous approved payment, allow submission
      if (lastApprovedPayment == null) {
        return {'canSubmit': true, 'message': null};
      }

      final now = DateTime.now();
      final lastPaymentDate = lastApprovedPayment.reviewedAt ?? lastApprovedPayment.submittedAt;

      // Check based on fee type
      switch (feeType.toLowerCase()) {
        case 'lifetime':
          return {
            'canSubmit': false,
            'message': 'This is a lifetime course. You have already paid for it and cannot submit payment again.',
          };

        case 'yearly':
          // Check if the last payment was in the same year
          if (lastPaymentDate.year == now.year) {
            final monthsRemaining = 12 - (now.month - lastPaymentDate.month);
            return {
              'canSubmit': false,
              'message': 'This is a yearly course. You have already paid for this year.\nYou can submit payment again after ${monthsRemaining} month(s) in ${now.year + 1}.',
            };
          }
          return {'canSubmit': true, 'message': null};

        case 'monthly':
          // Check if the last payment was in the same month and year
          if (lastPaymentDate.year == now.year && lastPaymentDate.month == now.month) {
            // Calculate next available month
            final nextMonth = now.month == 12 ? 1 : now.month + 1;
            final nextYear = now.month == 12 ? now.year + 1 : now.year;
            return {
              'canSubmit': false,
              'message': 'This is a monthly course. You have already paid for this month.\nYou can submit payment again after the current month ends (from $nextMonth/$nextYear).',
            };
          }
          return {'canSubmit': true, 'message': null};

        default:
          return {'canSubmit': true, 'message': null};
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      // In case of error, allow submission (fail-safe)
      return {'canSubmit': true, 'message': null};
    }
  }
}
