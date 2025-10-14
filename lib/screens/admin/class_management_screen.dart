import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/course_model.dart';
import '../../models/class_model.dart';
import '../../providers/course_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/custom_text_field.dart';

class ClassManagementScreen extends StatefulWidget {
  final CourseModel course;

  const ClassManagementScreen({super.key, required this.course});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  void _showCreateClassDialog() {
    final formKey = GlobalKey<FormState>();
    final classNameController = TextEditingController();
    final zoomLinkController = TextEditingController();
    DateTime? selectedStartTime;
    DateTime? selectedEndTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          insetPadding: const EdgeInsets.symmetric(vertical: 40),
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
                    'Create New Class',
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
                            controller: classNameController,
                            label: 'Class Name',
                            hint: 'e.g., Lesson 1',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter class name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          CustomTextField(
                            controller: zoomLinkController,
                            label: 'Zoom Link (Optional)',
                            hint: 'https://zoom.us/j/...',
                          ),
                          const SizedBox(height: 24),
                          
                          // Start Time
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: ListTile(
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              title: const Text(
                                'Start Time',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                selectedStartTime != null
                                    ? DateFormat('MMM dd, yyyy - hh:mm a').format(selectedStartTime!)
                                    : 'Tap to select date and time',
                                style: TextStyle(
                                  color: selectedStartTime != null 
                                      ? const Color(0xFF066330)
                                      : Colors.grey,
                                ),
                              ),
                              leading: Icon(
                                Icons.calendar_today,
                                color: const Color(0xFF066330),
                              ),
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFF066330),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                
                                if (date != null && context.mounted) {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: Color(0xFF066330),
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  
                                  if (time != null) {
                                    setDialogState(() {
                                      selectedStartTime = DateTime(
                                        date.year,
                                        date.month,
                                        date.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  }
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // End Time
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: ListTile(
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              title: const Text(
                                'End Time',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                selectedEndTime != null
                                    ? DateFormat('MMM dd, yyyy - hh:mm a').format(selectedEndTime!)
                                    : 'Tap to select date and time',
                                style: TextStyle(
                                  color: selectedEndTime != null 
                                      ? const Color(0xFF066330)
                                      : Colors.grey,
                                ),
                              ),
                              leading: Icon(
                                Icons.calendar_today,
                                color: const Color(0xFF066330),
                              ),
                              onTap: () async {
                                if (selectedStartTime == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please select start time first'),
                                      backgroundColor: Color(0xFFCA9A2D),
                                    ),
                                  );
                                  return;
                                }
                                
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: selectedStartTime!,
                                  firstDate: selectedStartTime!,
                                  lastDate: selectedStartTime!.add(const Duration(days: 1)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFF066330),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                
                                if (date != null && context.mounted) {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(
                                      selectedStartTime!.add(const Duration(hours: 1)),
                                    ),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: Color(0xFF066330),
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  
                                  if (time != null) {
                                    setDialogState(() {
                                      selectedEndTime = DateTime(
                                        date.year,
                                        date.month,
                                        date.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  }
                                }
                              },
                            ),
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
                      Consumer<CourseProvider>(
                        builder: (context, courseProvider, _) {
                          return ElevatedButton(
                            onPressed: courseProvider.isLoading
                                ? null
                                : () async {
                                    if (formKey.currentState!.validate()) {
                                      if (selectedStartTime == null || selectedEndTime == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Please select start and end times'),
                                            backgroundColor: Color(0xFFCA9A2D),
                                          ),
                                        );
                                        return;
                                      }
                                      
                                      if (selectedEndTime!.isBefore(selectedStartTime!)) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('End time must be after start time'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }
                                      
                                      final classId = await courseProvider.createClass(
                                        courseId: widget.course.id,
                                        className: classNameController.text.trim(),
                                        zoomLink: zoomLinkController.text.trim(),
                                        startTime: selectedStartTime!,
                                        endTime: selectedEndTime!,
                                      );

                                      if (classId != null && mounted) {
                                        // Schedule notification for students
                                        await NotificationService().sendClassNotification(
                                          courseId: widget.course.id,
                                          classId: classId,
                                          courseName: widget.course.name,
                                          startTime: selectedStartTime!,
                                        );
                                        
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Class created and notification scheduled!'),
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
                            child: courseProvider.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Create Class'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateClassDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Class'),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        backgroundColor: const Color(0xFF066330),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<ClassModel>>(
        stream: _firestoreService.getClasses(widget.course.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.class_, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No classes yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to create your first class',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final classes = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final classModel = classes[index];
              return _buildClassCard(classModel);
            },
          );
        },
      ),
    );
  }

  Widget _buildClassCard(ClassModel classModel) {
    final isAttendanceOpen = classModel.isAttendanceOpen();
    
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
            color: isAttendanceOpen ? const Color(0xFF066330) : Colors.grey,
            borderRadius: BorderRadius.zero,
          ),
          child: const Icon(Icons.class_, color: Colors.white),
        ),
        title: Text(
          classModel.className,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.play_arrow, size: 16, color: Color(0xFF066330)),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy - hh:mm a').format(classModel.startTime),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.stop, size: 16, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy - hh:mm a').format(classModel.endTime),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isAttendanceOpen ? const Color(0xFF066330).withValues(alpha: 0.1) : Colors.grey.shade100,
                border: Border.all(
                  color: isAttendanceOpen ? const Color(0xFF066330) : Colors.grey,
                  width: 1,
                ),
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                isAttendanceOpen ? 'Attendance Open' : 'Attendance Closed',
                style: TextStyle(
                  color: isAttendanceOpen ? const Color(0xFF066330) : Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          itemBuilder: (context) => [
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
            if (value == 'delete') {
              _showDeleteConfirmation(classModel);
            }
          },
        ),
      ),
    );
  }

  void _showDeleteConfirmation(ClassModel classModel) {
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
                      'Delete Class',
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
                      'Are you sure you want to delete this class?',
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
                        '"${classModel.className}"',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This action cannot be undone.',
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
                        final courseProvider = Provider.of<CourseProvider>(context, listen: false);
                        await courseProvider.deleteClass(widget.course.id, classModel.id);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Class deleted successfully'),
                              backgroundColor: Colors.red,
                            ),
                          );
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

