enum PaymentStatus {
  pending,
  approved,
  rejected,
}

class FeePaymentModel {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String feeCourseId;
  final String feeCourseName;
  final double amount;
  final String currency;
  final String paymentScreenshotUrl;
  final PaymentStatus status;
  final String? adminNotes;
  final String? rejectionReason;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy; // admin uid

  FeePaymentModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.feeCourseId,
    required this.feeCourseName,
    required this.amount,
    this.currency = 'USD',
    required this.paymentScreenshotUrl,
    this.status = PaymentStatus.pending,
    this.adminNotes,
    this.rejectionReason,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'feeCourseId': feeCourseId,
      'feeCourseName': feeCourseName,
      'amount': amount,
      'currency': currency,
      'paymentScreenshotUrl': paymentScreenshotUrl,
      'status': status.name,
      'adminNotes': adminNotes,
      'rejectionReason': rejectionReason,
      'submittedAt': submittedAt.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewedBy': reviewedBy,
    };
  }

  factory FeePaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return FeePaymentModel(
      id: id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentEmail: map['studentEmail'] ?? '',
      feeCourseId: map['feeCourseId'] ?? '',
      feeCourseName: map['feeCourseName'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? 'USD',
      paymentScreenshotUrl: map['paymentScreenshotUrl'] ?? '',
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PaymentStatus.pending,
      ),
      adminNotes: map['adminNotes'],
      rejectionReason: map['rejectionReason'],
      submittedAt: map['submittedAt'] != null 
          ? DateTime.parse(map['submittedAt']) 
          : DateTime.now(),
      reviewedAt: map['reviewedAt'] != null 
          ? DateTime.parse(map['reviewedAt']) 
          : null,
      reviewedBy: map['reviewedBy'],
    );
  }

  FeePaymentModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? studentEmail,
    String? feeCourseId,
    String? feeCourseName,
    double? amount,
    String? currency,
    String? paymentScreenshotUrl,
    PaymentStatus? status,
    String? adminNotes,
    String? rejectionReason,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return FeePaymentModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      feeCourseId: feeCourseId ?? this.feeCourseId,
      feeCourseName: feeCourseName ?? this.feeCourseName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paymentScreenshotUrl: paymentScreenshotUrl ?? this.paymentScreenshotUrl,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }

  String get statusDisplayName {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending Review';
      case PaymentStatus.approved:
        return 'Approved';
      case PaymentStatus.rejected:
        return 'Rejected';
    }
  }
}
