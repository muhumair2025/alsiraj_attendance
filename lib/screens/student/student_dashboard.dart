import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/course_model.dart';
import '../../models/class_model.dart';
import '../../services/firestore_service.dart';
import '../auth/login_screen.dart';
import '../common/profile_screen.dart';
import 'course_selection_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  final Map<String, bool> _attendanceStatus = {};
  bool _hasLoadedAttendanceStatus = false;
  bool _isRefreshing = false;
  Timer? _refreshTimer;
  DateTime? _lastRefreshed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      // Check if user has selected courses
      if (user?.selectedCourseIds.isEmpty ?? true) {
        // Redirect to course selection screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CourseSelectionScreen()),
        );
        return;
      }
      
      // Load classes for the selected courses
      Provider.of<CourseProvider>(context, listen: false)
          .loadUpcomingClassesForCourses(user!.selectedCourseIds);
      
      // Log analytics event for In-App Messaging targeting
      FirebaseAnalytics.instance.logEvent(
        name: 'student_dashboard_viewed',
        parameters: {'screen': 'student_dashboard'},
      );
      print('📊 Analytics: student_dashboard_viewed event logged');
      
      // Start periodic refresh timer for dynamic updates
      _startPeriodicRefresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    // Refresh every 30 seconds to check for new classes and attendance window changes
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isRefreshing) {
        _refreshData();
      }
    });
  }

  Future<void> _loadAttendanceStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);

    if (authProvider.currentUser == null) return;
    if (courseProvider.upcomingClasses.isEmpty) return;

    _hasLoadedAttendanceStatus = true;

    for (var data in courseProvider.upcomingClasses) {
      final course = data['course'] as CourseModel;
      final classModel = data['class'] as ClassModel;
      
      final hasMarked = await _firestoreService.hasMarkedAttendance(
        course.id,
        classModel.id,
        authProvider.currentUser!.uid,
      );
      
      if (mounted) {
        setState(() {
          _attendanceStatus['${course.id}_${classModel.id}'] = hasMarked;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final courseProvider = Provider.of<CourseProvider>(context, listen: false);
      
      if (authProvider.currentUser?.selectedCourseIds.isNotEmpty == true) {
        // Reload classes
        courseProvider.loadUpcomingClassesForCourses(authProvider.currentUser!.selectedCourseIds);
        
        // Wait a bit for the stream to update
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Reload attendance status
        _hasLoadedAttendanceStatus = false;
        _attendanceStatus.clear();
        await _loadAttendanceStatus();
        
        // Update last refreshed time
        _lastRefreshed = DateTime.now();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _handleSignOut() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _launchZoomLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Zoom link')),
        );
      }
    }
  }

  Future<void> _markAttendance(CourseModel course, ClassModel classModel) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Check if attendance window is open
    if (!classModel.isAttendanceOpen()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance is not open for this class'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Attendance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Course: ${course.name}'),
            Text('Class: ${classModel.className}'),
            const SizedBox(height: 8),
            const Text(
              'Are you sure you want to mark your attendance?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Mark attendance
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final success = await attendanceProvider.markAttendance(
      courseId: course.id,
      classId: classModel.id,
      student: authProvider.currentUser!,
    );

    if (mounted) {
      if (success) {
        // Update attendance status
        setState(() {
          _attendanceStatus['${course.id}_${classModel.id}'] = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance marked successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(attendanceProvider.errorMessage ?? 'Failed to mark attendance'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final courseProvider = Provider.of<CourseProvider>(context);

    // Load attendance status when classes are available
    if (courseProvider.upcomingClasses.isNotEmpty && !_hasLoadedAttendanceStatus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAttendanceStatus();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            icon: _isRefreshing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            tooltip: 'Profile',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleSignOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Stack(
          children: [
            // Background watermark
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: 0.05,
                  child: Image.asset(
                    'assets/images/logo-alsiraj-light.png',
                    width: 300,
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            
            // Main content
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // Welcome card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: const Icon(Icons.person, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome ${authProvider.currentUser?.name ?? "Student"}!',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              authProvider.currentUser?.email ?? '',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

            // Overall Attendance Statistics
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: authProvider.currentUser?.selectedCourseIds.isNotEmpty == true
                  ? _firestoreService.getStudentAttendanceStatsForCourses(
                      authProvider.currentUser?.uid ?? '', 
                      authProvider.currentUser!.selectedCourseIds
                    )
                  : Stream.value([]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final stats = snapshot.data!;
                final totalPresent = stats.where((a) => a['status'] == 'present').length;
                final totalAbsent = stats.where((a) => a['status'] == 'absent').length;
                final totalClasses = totalPresent + totalAbsent;

                // Group stats by course
                final Map<String, Map<String, dynamic>> courseStats = {};
                for (var stat in stats) {
                  final courseId = stat['courseId'] as String;
                  final courseName = stat['courseName'] as String;
                  final status = stat['status'] as String;
                  
                  if (!courseStats.containsKey(courseId)) {
                    courseStats[courseId] = {
                      'present': 0,
                      'absent': 0,
                      'total': 0,
                      'courseName': courseName,
                    };
                  }
                  
                  courseStats[courseId]![status] = (courseStats[courseId]![status] ?? 0) + 1;
                  courseStats[courseId]!['total'] = (courseStats[courseId]!['total'] ?? 0) + 1;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overall Statistics
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: Colors.green.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$totalPresent',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  Text(
                                    'Present',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            color: Colors.red.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Icon(Icons.cancel, color: Colors.red.shade700, size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$totalAbsent',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                  Text(
                                    'Absent',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            color: Colors.blue.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Icon(Icons.school, color: Colors.blue.shade700, size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$totalClasses',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  Text(
                                    'Total',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Per-Course Statistics (if multiple courses)
                    if (courseStats.length > 1) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Per Course Statistics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...courseStats.entries.map((entry) {
                        final courseId = entry.key;
                        final stats = entry.value;
                        final courseName = stats['courseName'] as String;
                        final present = stats['present'] ?? 0;
                        final absent = stats['absent'] ?? 0;
                        final total = stats['total'] ?? 0;
                        final percentage = total > 0 ? (present / total * 100).round() : 0;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        courseName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: percentage >= 75 
                                            ? Colors.green.shade100 
                                            : percentage >= 50 
                                                ? Colors.orange.shade100 
                                                : Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$percentage%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: percentage >= 75 
                                              ? Colors.green.shade700 
                                              : percentage >= 50 
                                                  ? Colors.orange.shade700 
                                                  : Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_circle, 
                                               color: Colors.green.shade600, size: 16),
                                          const SizedBox(width: 4),
                                          Text('$present', 
                                               style: TextStyle(color: Colors.green.shade600, 
                                                              fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(Icons.cancel, 
                                               color: Colors.red.shade600, size: 16),
                                          const SizedBox(width: 4),
                                          Text('$absent', 
                                               style: TextStyle(color: Colors.red.shade600, 
                                                              fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(Icons.school, 
                                               color: Colors.blue.shade600, size: 16),
                                          const SizedBox(width: 4),
                                          Text('$total', 
                                               style: TextStyle(color: Colors.blue.shade600, 
                                                              fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Upcoming classes header
            Row(
              children: [
                const Text(
                  'Upcoming Classes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_lastRefreshed != null)
                  Text(
                    'Updated ${_getTimeAgo(_lastRefreshed!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Classes list
            courseProvider.upcomingClasses.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No upcoming classes',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: courseProvider.upcomingClasses.length,
                    itemBuilder: (context, index) {
                      final data = courseProvider.upcomingClasses[index];
                      final course = data['course'] as CourseModel;
                      final classModel = data['class'] as ClassModel;
                      return _buildClassCard(course, classModel);
                    },
                  ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildClassCard(CourseModel course, ClassModel classModel) {
    final now = DateTime.now();
    final isAttendanceOpen = classModel.isAttendanceOpen();
    final isUpcoming = classModel.startTime.isAfter(now);
    final attendanceKey = '${course.id}_${classModel.id}';
    final hasMarkedAttendance = _attendanceStatus[attendanceKey] ?? false;
    
    // Calculate time until attendance opens
    String timeUntilOpen = '';
    if (!isAttendanceOpen && isUpcoming) {
      final timeUntil = classModel.startTime.difference(now);
      if (timeUntil.inDays > 0) {
        timeUntilOpen = 'Opens in ${timeUntil.inDays}d ${timeUntil.inHours % 24}h';
      } else if (timeUntil.inHours > 0) {
        timeUntilOpen = 'Opens in ${timeUntil.inHours}h ${timeUntil.inMinutes % 60}m';
      } else if (timeUntil.inMinutes > 0) {
        timeUntilOpen = 'Opens in ${timeUntil.inMinutes}m';
      } else {
        timeUntilOpen = 'Opening soon...';
      }
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        classModel.className,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: hasMarkedAttendance
                            ? Colors.green.shade100
                            : (isAttendanceOpen 
                                ? Colors.green.shade50 
                                : (isUpcoming ? Colors.blue.shade50 : Colors.grey.shade50)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hasMarkedAttendance
                            ? 'Marked'
                            : (isAttendanceOpen 
                                ? 'Open' 
                                : (isUpcoming ? 'Upcoming' : 'Closed')),
                        style: TextStyle(
                          color: hasMarkedAttendance
                              ? Colors.green.shade700
                              : (isAttendanceOpen 
                                  ? Colors.green.shade700 
                                  : (isUpcoming ? Colors.blue.shade700 : Colors.grey.shade700)),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (timeUntilOpen.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        timeUntilOpen,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM dd, yyyy').format(classModel.startTime),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('hh:mm a').format(classModel.startTime)} - ${DateFormat('hh:mm a').format(classModel.endTime)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Show both buttons if zoom link exists, otherwise just attendance button
            classModel.zoomLink.isNotEmpty
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _launchZoomLink(classModel.zoomLink),
                          icon: const Icon(Icons.videocam),
                          label: const Text('Join Zoom'),
                          style: OutlinedButton.styleFrom(
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (isAttendanceOpen && !hasMarkedAttendance) 
                              ? () => _markAttendance(course, classModel)
                              : null,
                          icon: Icon(hasMarkedAttendance ? Icons.check_circle_outline : Icons.check_circle),
                          label: Text(hasMarkedAttendance ? 'Marked' : 'Mark Attendance'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasMarkedAttendance 
                                ? Colors.grey.shade400 
                                : (isAttendanceOpen ? Colors.green : null),
                            foregroundColor: hasMarkedAttendance ? Colors.white : null,
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade600,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (isAttendanceOpen && !hasMarkedAttendance) 
                          ? () => _markAttendance(course, classModel)
                          : null,
                      icon: Icon(hasMarkedAttendance ? Icons.check_circle_outline : Icons.check_circle),
                      label: Text(hasMarkedAttendance ? 'Marked' : 'Mark Attendance'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasMarkedAttendance 
                            ? Colors.grey.shade400 
                            : (isAttendanceOpen ? Colors.green : null),
                        foregroundColor: hasMarkedAttendance ? Colors.white : null,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

