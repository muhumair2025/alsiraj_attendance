import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/notice_board_provider.dart';
import '../../models/course_model.dart';
import '../../models/class_model.dart';
import '../../models/notice_board_model.dart';
import '../../services/firestore_service.dart';
import '../../services/cache_service.dart';
import '../../services/notification_service.dart';
import '../auth/login_screen.dart';
import '../common/profile_screen.dart';
import 'course_selection_screen.dart';
import 'fee_courses_screen.dart';
import 'attendance_report_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  final CacheService _cacheService = CacheService();
  final NotificationService _notificationService = NotificationService();
  final Map<String, bool> _attendanceStatus = {};
  final Map<String, bool> _noticeExpandedStates = {}; // Track expanded state for each notice
  bool _hasLoadedAttendanceStatus = false;
  bool _isRefreshing = false;
  Timer? _refreshTimer;
  DateTime? _lastRefreshed;
  
  // Cached attendance statistics
  Map<String, dynamic> _attendanceStats = {};
  bool _isLoadingStats = true;

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
      
      // Load notice board
      Provider.of<NoticeBoardProvider>(context, listen: false).loadNotices();
      
      // Load attendance statistics
      _loadAttendanceStatistics();
      
      // Log analytics event for In-App Messaging targeting
      FirebaseAnalytics.instance.logEvent(
        name: 'student_dashboard_viewed',
        parameters: {'screen': 'student_dashboard'},
      );
      print('📊 Analytics: student_dashboard_viewed event logged');
      
      // Start periodic refresh timer for dynamic updates
      _startPeriodicRefresh();
      
      // Cache attendance schedules and schedule offline notifications
      _cacheAttendanceSchedulesAndNotifications();
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

  Future<void> _loadAttendanceStatistics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.currentUser == null || 
        authProvider.currentUser!.selectedCourseIds.isEmpty) {
      setState(() {
        _isLoadingStats = false;
      });
      return;
    }

    try {
      // Fetch attendance statistics once
      final statsStream = _firestoreService.getStudentAttendanceStatsForCourses(
        authProvider.currentUser!.uid,
        authProvider.currentUser!.selectedCourseIds,
      );
      
      // Get the first snapshot and cancel the stream
      final stats = await statsStream.first;
      
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

      if (mounted) {
        setState(() {
          _attendanceStats = {
            'totalPresent': totalPresent,
            'totalAbsent': totalAbsent,
            'totalClasses': totalClasses,
            'courseStats': courseStats,
          };
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('Error loading attendance statistics: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
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
        
        // Reload attendance statistics
        await _loadAttendanceStatistics();
        
        // Cache attendance schedules (force refresh on manual refresh)
        await _forceCacheAttendanceSchedules();
        
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

  Future<void> _cacheAttendanceSchedulesAndNotifications() async {
    try {
      // Check if cache needs refresh (only cache once per hour or if no cache exists)
      final needsRefresh = await _cacheService.needsCacheRefresh();
      if (!needsRefresh) {
        print('📦 Cache is up to date, skipping re-caching');
        return;
      }
      
      final courseProvider = Provider.of<CourseProvider>(context, listen: false);
      
      if (courseProvider.upcomingClasses.isNotEmpty) {
        // Cache the attendance schedules
        await _cacheService.cacheAttendanceSchedules(courseProvider.upcomingClasses);
        
        print('✅ Cached ${courseProvider.upcomingClasses.length} classes');
      }
    } catch (e) {
      print('❌ Error caching attendance schedules: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error caching attendance schedules: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _forceCacheAttendanceSchedules() async {
    try {
      final courseProvider = Provider.of<CourseProvider>(context, listen: false);
      
      if (courseProvider.upcomingClasses.isNotEmpty) {
        // Force cache the attendance schedules (ignore cache refresh check)
        await _cacheService.cacheAttendanceSchedules(courseProvider.upcomingClasses);
        
        print('✅ Force cached ${courseProvider.upcomingClasses.length} classes');
      }
    } catch (e) {
      print('❌ Error force caching attendance schedules: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error force caching attendance schedules: $e'),
            backgroundColor: Colors.orange,
          ),
        );
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
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: _buildDrawer(context, authProvider),
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
              const SizedBox(height: 16),
              
              // Notice Board Section
              Consumer<NoticeBoardProvider>(
                builder: (context, noticeProvider, _) {
                  if (noticeProvider.activeNotices.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📢 Important Notices',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...noticeProvider.activeNotices.map((notice) => _buildNoticeCard(notice)).toList(),
                        const SizedBox(height: 16),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

            // Overall Attendance Statistics
            _isLoadingStats
                ? _buildAttendanceStatsLoading()
                : _buildAttendanceStats(),
            const SizedBox(height: 12),

            // Upcoming classes header with notification status
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
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

  Widget _buildNoticeCard(NoticeBoardModel notice) {
    final noticeColor = _getNoticeColor(notice.type);
    final noticeIcon = _getNoticeIcon(notice.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: noticeColor,
              width: 4,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                noticeIcon,
                color: noticeColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.type.displayName,
                      style: TextStyle(
                        color: noticeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildExpandableText(notice.id, notice.message),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('MMM dd, yyyy - hh:mm a').format(notice.createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
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

  Widget _buildExpandableText(String noticeId, String text) {
    const int maxLength = 150; // Characters to show before truncation
    
    if (text.length <= maxLength) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.4,
        ),
      );
    }

    final isExpanded = _noticeExpandedStates[noticeId] ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isExpanded ? text : '${text.substring(0, maxLength)}...',
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            setState(() {
              _noticeExpandedStates[noticeId] = !isExpanded;
            });
          },
          child: Text(
            isExpanded ? 'Show Less' : 'Show More',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getNoticeIcon(NoticeType type) {
    switch (type) {
      case NoticeType.success:
        return Icons.check_circle;
      case NoticeType.warning:
        return Icons.warning;
      case NoticeType.danger:
        return Icons.error;
      case NoticeType.info:
        return Icons.info;
    }
  }

  Color _getNoticeColor(NoticeType type) {
    switch (type) {
      case NoticeType.success:
        return Colors.green;
      case NoticeType.warning:
        return Colors.orange;
      case NoticeType.danger:
        return Colors.red;
      case NoticeType.info:
        return Colors.blue;
    }
  }

  Widget _buildAttendanceStatsLoading() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 50,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
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
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 50,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
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
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 50,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttendanceStats() {
    final totalPresent = _attendanceStats['totalPresent'] ?? 0;
    final totalAbsent = _attendanceStats['totalAbsent'] ?? 0;
    final totalClasses = _attendanceStats['totalClasses'] ?? 0;
    final courseStats = _attendanceStats['courseStats'] as Map<String, Map<String, dynamic>>? ?? {};
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Detailed Report Button
        if (totalClasses > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AttendanceReportScreen(
                        studentId: authProvider.currentUser!.uid,
                        courseIds: authProvider.currentUser!.selectedCourseIds,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.assessment, size: 20),
                label: const Text('View Detailed Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF066330),
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        
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
  }

  Widget _buildDrawer(BuildContext context, AuthProvider authProvider) {
    return Drawer(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF066330),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: Text(
                    authProvider.currentUser?.name.substring(0, 1).toUpperCase() ?? 'S',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF066330),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  authProvider.currentUser?.name ?? 'Student',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  authProvider.currentUser?.email ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'STUDENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard,
                  title: 'Dashboard',
                  onTap: () {
                    Navigator.pop(context);
                  },
                  isActive: true,
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.monetization_on,
                  title: 'Fee Courses',
                  subtitle: 'Browse & pay for courses',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FeeCoursesScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.school,
                  title: 'My Courses',
                  subtitle: 'Enrolled courses',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CourseSelectionScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.assessment,
                  title: 'Attendance Report',
                  subtitle: 'Detailed attendance history',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AttendanceReportScreen(
                          studentId: authProvider.currentUser!.uid,
                          courseIds: authProvider.currentUser!.selectedCourseIds,
                        ),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.person,
                  title: 'Profile',
                  subtitle: 'View & edit profile',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                  },
                ),
                const Divider(),
                _buildDrawerItem(
                  context,
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () {
                    Navigator.pop(context);
                    _showHelpDialog(context);
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.info_outline,
                  title: 'About',
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutDialog(context);
                  },
                ),
              ],
            ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                if (_lastRefreshed != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(Icons.sync, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Last updated ${_getTimeAgo(_lastRefreshed!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleSignOut,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF066330).withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive 
                ? const Color(0xFF066330) 
                : const Color(0xFF066330).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : const Color(0xFF066330),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? const Color(0xFF066330) : Colors.black87,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              )
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF066330)),
            SizedBox(width: 12),
            Text('Help & Support'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need help? Here are some quick tips:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('• Mark attendance during class time'),
            Text('• Browse and pay for fee courses'),
            Text('• Check your attendance statistics'),
            Text('• Update your profile information'),
            SizedBox(height: 12),
            Text(
              'For technical support, contact your administrator.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF066330)),
            SizedBox(width: 12),
            Text('About Al-Siraj'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Al-Siraj Attendance System',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
            SizedBox(height: 12),
            Text(
              'A comprehensive attendance and fee management system for educational institutions.',
            ),
            SizedBox(height: 12),
            Text(
              '© 2024 Al-Siraj Educational Institute',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

