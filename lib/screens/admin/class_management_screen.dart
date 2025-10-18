import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  
  // Sorting options
  String _currentSortOption = 'newest_first';
  List<ClassModel> _sortedClasses = [];
  
  // Sort options
  final Map<String, String> _sortOptions = {
    'newest_first': 'Newest First',
    'oldest_first': 'Oldest First',
    'class_name_asc': 'Class Name (A-Z)',
    'class_name_desc': 'Class Name (Z-A)',
    'start_time_asc': 'Start Time (Earliest)',
    'start_time_desc': 'Start Time (Latest)',
  };

  @override
  void initState() {
    super.initState();
    _loadSortPreference();
  }

  // Load saved sort preference
  Future<void> _loadSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSort = prefs.getString('class_sort_preference') ?? 'newest_first';
    setState(() {
      _currentSortOption = savedSort;
    });
  }

  // Save sort preference
  Future<void> _saveSortPreference(String sortOption) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('class_sort_preference', sortOption);
  }

  // Sort classes based on selected option
  List<ClassModel> _sortClasses(List<ClassModel> classes) {
    final sortedClasses = List<ClassModel>.from(classes);
    
    switch (_currentSortOption) {
      case 'newest_first':
        sortedClasses.sort((a, b) => b.startTime.compareTo(a.startTime));
        break;
      case 'oldest_first':
        sortedClasses.sort((a, b) => a.startTime.compareTo(b.startTime));
        break;
      case 'class_name_asc':
        sortedClasses.sort((a, b) => a.className.compareTo(b.className));
        break;
      case 'class_name_desc':
        sortedClasses.sort((a, b) => b.className.compareTo(a.className));
        break;
      case 'start_time_asc':
        sortedClasses.sort((a, b) => a.startTime.compareTo(b.startTime));
        break;
      case 'start_time_desc':
        sortedClasses.sort((a, b) => b.startTime.compareTo(a.startTime));
        break;
    }
    
    return sortedClasses;
  }

  // Show sort options dialog
  void _showSortOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        title: const Text('Sort Classes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _sortOptions.entries.map((entry) {
            return RadioListTile<String>(
              title: Text(entry.value),
              value: entry.key,
              groupValue: _currentSortOption,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _currentSortOption = value;
                  });
                  _saveSortPreference(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCreateClassDialog() {
    final formKey = GlobalKey<FormState>();
    final classNameController = TextEditingController();
    final zoomLinkController = TextEditingController();
    DateTime? selectedStartTime;
    DateTime? selectedEndTime;
    bool isRecurring = false;
    int recurringDays = 7;

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
                          const SizedBox(height: 24),
                          
                          // Recurring Class Options
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Recurring Toggle
                                CheckboxListTile(
                                  title: const Text(
                                    'Create Recurring Classes',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: const Text('Create the same class for multiple days'),
                                  value: isRecurring,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      isRecurring = value ?? false;
                                    });
                                  },
                                  activeColor: const Color(0xFF066330),
                                ),
                                
                                // Recurring Days Selection
                                if (isRecurring) ...[
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Number of Days:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            _buildRecurringOption(
                                              context,
                                              setDialogState,
                                              7,
                                              recurringDays,
                                              (value) => recurringDays = value,
                                              '7 Days',
                                              '1 Week',
                                            ),
                                            const SizedBox(width: 12),
                                            _buildRecurringOption(
                                              context,
                                              setDialogState,
                                              15,
                                              recurringDays,
                                              (value) => recurringDays = value,
                                              '15 Days',
                                              '2 Weeks',
                                            ),
                                            const SizedBox(width: 12),
                                            _buildRecurringOption(
                                              context,
                                              setDialogState,
                                              30,
                                              recurringDays,
                                              (value) => recurringDays = value,
                                              '30 Days',
                                              '1 Month',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Classes will be created from ${selectedStartTime != null ? DateFormat('MMM dd, yyyy').format(selectedStartTime!) : 'selected date'} for $recurringDays consecutive days',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
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
                                      
                                      if (isRecurring) {
                                        // Create recurring classes
                                        await _createRecurringClasses(
                                          courseProvider,
                                          classNameController.text.trim(),
                                          zoomLinkController.text.trim(),
                                          selectedStartTime!,
                                          selectedEndTime!,
                                          recurringDays,
                                        );
                                      } else {
                                        // Create single class
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

  // Create recurring classes
  Future<void> _createRecurringClasses(
    CourseProvider courseProvider,
    String className,
    String zoomLink,
    DateTime startTime,
    DateTime endTime,
    int days,
  ) async {
    int successCount = 0;
    int totalClasses = days;
    
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Creating $totalClasses classes...'),
            const SizedBox(height: 8),
            Text('$successCount of $totalClasses completed'),
          ],
        ),
      ),
    );

    try {
      for (int i = 0; i < days; i++) {
        // Calculate the date for this iteration
        final currentDate = startTime.add(Duration(days: i));
        
        // Create new start and end times for this day
        final dayStartTime = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
          startTime.hour,
          startTime.minute,
        );
        
        final dayEndTime = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
          endTime.hour,
          endTime.minute,
        );
        
        // Create the class
        final classId = await courseProvider.createClass(
          courseId: widget.course.id,
          className: className,
          zoomLink: zoomLink,
          startTime: dayStartTime,
          endTime: dayEndTime,
        );
        
        if (classId != null) {
          successCount++;
          
          // Schedule notification for the first class only
          if (i == 0) {
            await NotificationService().sendClassNotification(
              courseId: widget.course.id,
              classId: classId,
              courseName: widget.course.name,
              startTime: dayStartTime,
            );
          }
        }
        
        // Update progress dialog
        if (mounted) {
          setState(() {});
        }
      }
      
      // Close progress dialog
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context); // Close create class dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully created $successCount of $totalClasses classes!'),
            backgroundColor: const Color(0xFF066330),
          ),
        );
      }
    } catch (e) {
      // Close progress dialog
      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating classes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Build recurring option button
  Widget _buildRecurringOption(
    BuildContext context,
    StateSetter setDialogState,
    int value,
    int selectedValue,
    Function(int) onChanged,
    String title,
    String subtitle,
  ) {
    final isSelected = selectedValue == value;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setDialogState(() {
            onChanged(value);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF066330).withOpacity(0.1) : Colors.grey.shade50,
            border: Border.all(
              color: isSelected ? const Color(0xFF066330) : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? const Color(0xFF066330) : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? const Color(0xFF066330) : Colors.grey.shade600,
                ),
              ),
            ],
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
        actions: [
          IconButton(
            onPressed: _showSortOptions,
            icon: const Icon(Icons.sort),
            tooltip: 'Sort Classes',
          ),
        ],
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
          final sortedClasses = _sortClasses(classes);
          
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: sortedClasses.length,
            itemBuilder: (context, index) {
              final classModel = sortedClasses[index];
              return _buildClassCard(classModel);
            },
          );
        },
      ),
    );
  }

  Widget _buildClassCard(ClassModel classModel) {
    final isAttendanceOpen = classModel.isAttendanceOpen();
    final now = DateTime.now();
    final isPast = classModel.endTime.isBefore(now);
    final isUpcoming = classModel.startTime.isAfter(now);
    
    // Determine status
    String status;
    Color statusColor;
    if (isPast) {
      status = 'Past';
      statusColor = Colors.grey.shade600;
    } else if (isUpcoming) {
      status = 'Upcoming';
      statusColor = Colors.blue.shade600;
    } else {
      status = 'Active';
      statusColor = Colors.green.shade600;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with class name and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    classModel.className,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    border: Border.all(color: statusColor, width: 1),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            
            // Date and time row
            Row(
              children: [
                Text(
                  DateFormat('MMM dd, yyyy').format(classModel.startTime),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('hh:mm a').format(classModel.startTime)} - ${DateFormat('hh:mm a').format(classModel.endTime)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            
            // Attendance status row
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isAttendanceOpen ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isAttendanceOpen ? 'Attendance Open' : 'Attendance Closed',
                  style: TextStyle(
                    fontSize: 12,
                    color: isAttendanceOpen ? Colors.green.shade700 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                PopupMenuButton(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 18),
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
              ],
            ),
          ],
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

