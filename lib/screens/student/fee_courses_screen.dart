import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../providers/fee_course_provider.dart';
import '../../providers/fee_payment_provider.dart';
import '../../models/fee_course_model.dart';
import '../../models/fee_payment_model.dart';

class FeeCoursesScreen extends StatefulWidget {
  const FeeCoursesScreen({super.key});

  @override
  State<FeeCoursesScreen> createState() => _FeeCoursesScreenState();
}

class _FeeCoursesScreenState extends State<FeeCoursesScreen> {
  String _selectedTab = 'submit';
  FeeCourseModel? _selectedFeeCourse;
  File? _selectedImage;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<FeeCourseProvider>(context, listen: false).loadFeeCourses();
      Provider.of<FeePaymentProvider>(context, listen: false)
          .loadStudentPayments(authProvider.currentUser!.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Payments'),
      ),
      body: Column(
        children: [
          // Tab selector
          Container(
            color: const Color(0xFF066330),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 'submit'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedTab == 'submit'
                            ? Colors.white
                            : Colors.transparent,
                      ),
                      child: Text(
                        'Submit Payment',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 'submit'
                              ? const Color(0xFF066330)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 'payments'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedTab == 'payments'
                            ? Colors.white
                            : Colors.transparent,
                      ),
                      child: Text(
                        'My Payments',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 'payments'
                              ? const Color(0xFF066330)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _selectedTab == 'submit'
                ? _buildSubmitPaymentForm()
                : _buildMyPaymentsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitPaymentForm() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentCourseIds = authProvider.currentUser?.selectedCourseIds ?? [];

    return Consumer<FeeCourseProvider>(
      builder: (context, feeCourseProvider, _) {
        // Filter fee courses to only show those matching student's enrolled courses
        final availableFeeCourses = feeCourseProvider.feeCourses.where((feeCourse) {
          // If courseId is null, show it (backward compatibility)
          // If courseId matches any of student's courses, show it
          return feeCourse.courseId == null || 
                 studentCourseIds.contains(feeCourse.courseId);
        }).toList();

        if (availableFeeCourses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monetization_on, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No fee courses available',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'No payment options for your enrolled courses',
                  style: TextStyle(color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Text(
                  'Submit Fee Payment',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF066330),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a course and upload your payment screenshot',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),

                // Course Dropdown
                const Text(
                  'Select Course *',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<FeeCourseModel>(
                  value: _selectedFeeCourse,
                  decoration: InputDecoration(
                    hintText: 'Choose a course to pay for',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF066330), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  // Show only course name when selected (prevents overflow)
                  selectedItemBuilder: (BuildContext context) {
                    return availableFeeCourses.map((feeCourse) {
                      return Text(
                        feeCourse.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    }).toList();
                  },
                  // Show full details in dropdown menu
                  items: availableFeeCourses.map((feeCourse) {
                    return DropdownMenuItem<FeeCourseModel>(
                      value: feeCourse,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            feeCourse.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${feeCourse.amount} ${feeCourse.currency} - ${feeCourse.feeTypeDisplayName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (FeeCourseModel? value) {
                    setState(() {
                      _selectedFeeCourse = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a course';
                    }
                    return null;
                  },
                ),

                if (_selectedFeeCourse != null) ...[
                  const SizedBox(height: 24),
                  
                  // Course Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF066330).withValues(alpha: 0.1),
                      border: Border.all(color: const Color(0xFF066330)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Course Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow('Course', _selectedFeeCourse!.name),
                        _buildDetailRow('Amount', '${_selectedFeeCourse!.amount} ${_selectedFeeCourse!.currency}'),
                        _buildDetailRow('Type', _selectedFeeCourse!.feeTypeDisplayName),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFeeCourse!.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Make payment to the designated account and upload a screenshot of the payment confirmation below.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Screenshot Upload
                  const Text(
                    'Payment Screenshot *',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedImage == null 
                              ? Colors.grey.shade400 
                              : const Color(0xFF066330),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _selectedImage != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: Image.file(
                                    _selectedImage!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedImage = null;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_upload,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tap to upload payment screenshot',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Camera or Gallery',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF066330),
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Payment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFCA9A2D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF066330)),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF066330)),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    
    if (source != null) {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a payment screenshot'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedFeeCourse == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final paymentProvider = Provider.of<FeePaymentProvider>(context, listen: false);

      // Check if student can submit payment
      final canSubmitResult = await paymentProvider.canSubmitPaymentForCourse(
        studentId: authProvider.currentUser!.uid,
        feeCourseId: _selectedFeeCourse!.id,
        feeType: _selectedFeeCourse!.feeType.name,
      );

      if (canSubmitResult['canSubmit'] != true) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Text('Payment Not Allowed'),
                ],
              ),
              content: Text(
                canSubmitResult['message'] ?? 'You cannot submit payment for this course at this time.',
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Upload image to Firebase Storage
      final userId = authProvider.currentUser!.uid;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${userId}_${_selectedFeeCourse!.id}_$timestamp.jpg';
      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('payment_screenshots')
          .child(fileName);
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'studentId': userId,
          'feeCourseId': _selectedFeeCourse!.id,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      
      await storageRef.putFile(_selectedImage!, metadata);
      final downloadUrl = await storageRef.getDownloadURL();

      // Submit payment
      final success = await paymentProvider.submitFeePayment(
        studentId: authProvider.currentUser!.uid,
        studentName: authProvider.currentUser!.name,
        studentEmail: authProvider.currentUser!.email,
        feeCourseId: _selectedFeeCourse!.id,
        feeCourseName: _selectedFeeCourse!.name,
        amount: _selectedFeeCourse!.amount,
        currency: _selectedFeeCourse!.currency,
        paymentScreenshotUrl: downloadUrl,
      );

      if (success && mounted) {
        // Reload student payments
        await paymentProvider.loadStudentPayments(authProvider.currentUser!.uid);
        
        // Reset form
        setState(() {
          _selectedFeeCourse = null;
          _selectedImage = null;
        });
        _formKey.currentState!.reset();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment submitted successfully! Awaiting admin review.'),
            backgroundColor: Color(0xFF066330),
            duration: Duration(seconds: 4),
          ),
        );
        
        // Switch to payments tab
        setState(() {
          _selectedTab = 'payments';
        });
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit payment. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error submitting payment';
        
        if (e.toString().contains('storage/unauthorized')) {
          errorMessage = 'Permission denied. Please check your account status.';
        } else if (e.toString().contains('storage/canceled')) {
          errorMessage = 'Upload was canceled. Please try again.';
        } else if (e.toString().contains('storage/unknown')) {
          errorMessage = 'Upload failed. Please check your internet connection.';
        } else if (e.toString().contains('storage/retry-limit-exceeded')) {
          errorMessage = 'Upload failed after multiple attempts. Please try again later.';
        } else if (e.toString().contains('firestore')) {
          errorMessage = 'Failed to save payment details. Please try again.';
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildMyPaymentsTab() {
    return Consumer<FeePaymentProvider>(
      builder: (context, paymentProvider, _) {
        if (paymentProvider.studentPayments.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payment, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No payments yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Submit your first payment from the other tab',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: paymentProvider.studentPayments.length,
          itemBuilder: (context, index) {
            final payment = paymentProvider.studentPayments[index];
            return _buildPaymentCard(payment);
          },
        );
      },
    );
  }

  Widget _buildPaymentCard(FeePaymentModel payment) {
    Color statusColor;
    IconData statusIcon;
    
    switch (payment.status) {
      case PaymentStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case PaymentStatus.approved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case PaymentStatus.rejected:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            border: Border.all(color: statusColor),
          ),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          payment.feeCourseName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${payment.amount} ${payment.currency}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFCA9A2D),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    payment.statusDisplayName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Submitted: ${_formatDate(payment.submittedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            // Show rejection reason for rejected payments
            if (payment.status == PaymentStatus.rejected && 
                payment.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rejection Reason:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payment.rejectionReason!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Show admin notes for approved payments
            if (payment.status == PaymentStatus.approved && 
                payment.adminNotes != null && payment.adminNotes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Message:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payment.adminNotes!,
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
