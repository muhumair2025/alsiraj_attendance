import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/fee_course_provider.dart';
import '../../providers/course_provider.dart';
import '../../models/fee_course_model.dart';
import '../../models/course_model.dart';
import '../../widgets/custom_text_field.dart';

class FeeCourseManagementScreen extends StatefulWidget {
  const FeeCourseManagementScreen({super.key});

  @override
  State<FeeCourseManagementScreen> createState() => _FeeCourseManagementScreenState();
}

class _FeeCourseManagementScreenState extends State<FeeCourseManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FeeCourseProvider>(context, listen: false).loadFeeCourses();
      Provider.of<CourseProvider>(context, listen: false).loadCourses();
    });
  }

  void _showCreateFeeCourseDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final currencyController = TextEditingController(text: 'USD');
    FeeType selectedFeeType = FeeType.monthly;
    CourseModel? selectedCourse;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          insetPadding: const EdgeInsets.symmetric(vertical: 40, horizontal: 0),
          child: Container(
            width: MediaQuery.of(context).size.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  color: const Color(0xFF066330),
                  child: const Text(
                    'Create New Fee Course',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CustomTextField(
                            controller: nameController,
                            label: 'Course Name',
                            hint: 'e.g., Advanced Mathematics',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter course name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          CustomTextField(
                            controller: descriptionController,
                            label: 'Description',
                            hint: 'Course description',
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter description';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Course Selection (Optional)
                          Consumer<CourseProvider>(
                            builder: (context, courseProvider, _) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Link to Course (Optional)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<CourseModel>(
                                    value: selectedCourse,
                                    decoration: InputDecoration(
                                      hintText: 'Select a course (optional)',
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(color: Colors.grey.shade400),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    items: [
                                      const DropdownMenuItem<CourseModel>(
                                        value: null,
                                        child: Text('None (Available to all students)'),
                                      ),
                                      ...courseProvider.courses.map((course) {
                                        return DropdownMenuItem<CourseModel>(
                                          value: course,
                                          child: Text(course.name),
                                        );
                                      }).toList(),
                                    ],
                                    onChanged: (CourseModel? value) {
                                      setDialogState(() {
                                        selectedCourse = value;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Link this fee to a specific course so only enrolled students can see it',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Fee Type Selection
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fee Type *',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...FeeType.values.map((feeType) {
                                  return RadioListTile<FeeType>(
                                    title: Text(feeType.name.toUpperCase()),
                                    subtitle: Text(_getFeeTypeDescription(feeType)),
                                    value: feeType,
                                    groupValue: selectedFeeType,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        selectedFeeType = value!;
                                      });
                                    },
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: CustomTextField(
                                  controller: amountController,
                                  label: 'Amount',
                                  hint: '0.00',
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter amount';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Please enter valid amount';
                                    }
                                    if (double.parse(value) <= 0) {
                                      return 'Amount must be greater than 0';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 1,
                                child: CustomTextField(
                                  controller: currencyController,
                                  label: 'Currency',
                                  hint: 'USD',
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      Consumer<FeeCourseProvider>(
                        builder: (context, feeCourseProvider, _) {
                          return ElevatedButton(
                            onPressed: feeCourseProvider.isLoading
                                ? null
                                : () async {
                                    if (formKey.currentState!.validate()) {
                                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                      final success = await feeCourseProvider.createFeeCourse(
                                        name: nameController.text.trim(),
                                        description: descriptionController.text.trim(),
                                        feeType: selectedFeeType,
                                        amount: double.parse(amountController.text.trim()),
                                        currency: currencyController.text.trim().toUpperCase(),
                                        createdBy: authProvider.currentUser!.uid,
                                        courseId: selectedCourse?.id,
                                      );

                                      if (success && mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Fee course created successfully'),
                                            backgroundColor: Color(0xFF066330),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF066330),
                              foregroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: feeCourseProvider.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Create Course'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getFeeTypeDescription(FeeType feeType) {
    switch (feeType) {
      case FeeType.monthly:
        return 'Recurring monthly payment';
      case FeeType.yearly:
        return 'Recurring yearly payment';
      case FeeType.lifetime:
        return 'One-time lifetime access';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Course Management'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateFeeCourseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Fee Course'),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        backgroundColor: const Color(0xFF066330),
        foregroundColor: Colors.white,
      ),
      body: Consumer<FeeCourseProvider>(
        builder: (context, feeCourseProvider, _) {
          if (feeCourseProvider.feeCourses.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.monetization_on, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No fee courses yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to create your first fee course',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: feeCourseProvider.feeCourses.length,
            itemBuilder: (context, index) {
              final feeCourse = feeCourseProvider.feeCourses[index];
              return _buildFeeCourseCard(feeCourse);
            },
          );
        },
      ),
    );
  }

  Widget _buildFeeCourseCard(FeeCourseModel feeCourse) {
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
          decoration: const BoxDecoration(
            color: Color(0xFF066330),
            borderRadius: BorderRadius.zero,
          ),
          child: const Icon(Icons.monetization_on, color: Colors.white),
        ),
        title: Text(
          feeCourse.name,
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
              feeCourse.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF066330).withValues(alpha: 0.1),
                    border: Border.all(color: const Color(0xFF066330)),
                  ),
                  child: Text(
                    feeCourse.feeTypeDisplayName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF066330),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCA9A2D).withValues(alpha: 0.1),
                    border: Border.all(color: const Color(0xFFCA9A2D)),
                  ),
                  child: Text(
                    '${feeCourse.amount} ${feeCourse.currency}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFCA9A2D),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Color(0xFF066330)),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditFeeCourseDialog(feeCourse);
            } else if (value == 'delete') {
              _showDeleteConfirmation(feeCourse);
            }
          },
        ),
      ),
    );
  }

  void _showEditFeeCourseDialog(FeeCourseModel feeCourse) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: feeCourse.name);
    final descriptionController = TextEditingController(text: feeCourse.description);
    final amountController = TextEditingController(text: feeCourse.amount.toString());
    final currencyController = TextEditingController(text: feeCourse.currency);
    FeeType selectedFeeType = feeCourse.feeType;
    
    // Find the selected course
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);
    CourseModel? selectedCourse;
    if (feeCourse.courseId != null) {
      selectedCourse = courseProvider.courses
          .where((c) => c.id == feeCourse.courseId)
          .firstOrNull;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          insetPadding: const EdgeInsets.symmetric(vertical: 40, horizontal: 0),
          child: Container(
            width: MediaQuery.of(context).size.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  color: const Color(0xFF066330),
                  child: const Text(
                    'Edit Fee Course',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CustomTextField(
                            controller: nameController,
                            label: 'Course Name',
                            hint: 'e.g., Advanced Mathematics',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter course name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          CustomTextField(
                            controller: descriptionController,
                            label: 'Description',
                            hint: 'Course description',
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter description';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Course Selection (Optional)
                          Consumer<CourseProvider>(
                            builder: (context, courseProvider, _) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Link to Course (Optional)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<CourseModel>(
                                    value: selectedCourse,
                                    decoration: InputDecoration(
                                      hintText: 'Select a course (optional)',
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(color: Colors.grey.shade400),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    items: [
                                      const DropdownMenuItem<CourseModel>(
                                        value: null,
                                        child: Text('None (Available to all students)'),
                                      ),
                                      ...courseProvider.courses.map((course) {
                                        return DropdownMenuItem<CourseModel>(
                                          value: course,
                                          child: Text(course.name),
                                        );
                                      }).toList(),
                                    ],
                                    onChanged: (CourseModel? value) {
                                      setDialogState(() {
                                        selectedCourse = value;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Link this fee to a specific course so only enrolled students can see it',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Fee Type Selection
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fee Type *',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...FeeType.values.map((feeType) {
                                  return RadioListTile<FeeType>(
                                    title: Text(feeType.name.toUpperCase()),
                                    subtitle: Text(_getFeeTypeDescription(feeType)),
                                    value: feeType,
                                    groupValue: selectedFeeType,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        selectedFeeType = value!;
                                      });
                                    },
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: CustomTextField(
                                  controller: amountController,
                                  label: 'Amount',
                                  hint: '0.00',
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter amount';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Please enter valid amount';
                                    }
                                    if (double.parse(value) <= 0) {
                                      return 'Amount must be greater than 0';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 1,
                                child: CustomTextField(
                                  controller: currencyController,
                                  label: 'Currency',
                                  hint: 'USD',
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      Consumer<FeeCourseProvider>(
                        builder: (context, feeCourseProvider, _) {
                          return ElevatedButton(
                            onPressed: feeCourseProvider.isLoading
                                ? null
                                : () async {
                                    if (formKey.currentState!.validate()) {
                                      final success = await feeCourseProvider.updateFeeCourse(
                                        feeCourseId: feeCourse.id,
                                        name: nameController.text.trim(),
                                        description: descriptionController.text.trim(),
                                        feeType: selectedFeeType,
                                        amount: double.parse(amountController.text.trim()),
                                        currency: currencyController.text.trim().toUpperCase(),
                                        courseId: selectedCourse?.id,
                                      );

                                      if (success && mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Fee course updated successfully'),
                                            backgroundColor: Color(0xFF066330),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF066330),
                              foregroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: feeCourseProvider.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Update Course'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(FeeCourseModel feeCourse) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        insetPadding: const EdgeInsets.symmetric(vertical: 100, horizontal: 20),
        child: Container(
          width: MediaQuery.of(context).size.width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.red,
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      'Delete Fee Course',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Are you sure you want to delete this fee course?',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        '"${feeCourse.name}" - ${feeCourse.amount} ${feeCourse.currency} (${feeCourse.feeTypeDisplayName})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This will hide the course from students. This action can be undone by editing the course.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          final feeCourseProvider = Provider.of<FeeCourseProvider>(context, listen: false);
                          final success = await feeCourseProvider.deleteFeeCourse(feeCourse.id);
                          if (success && mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fee course deleted successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting fee course: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
