import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/class_model.dart';
import '../models/course_model.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _attendanceScheduleKey = 'attendance_schedule';
  static const String _lastCacheUpdateKey = 'last_cache_update';

  /// Cache attendance schedules for offline notifications
  Future<void> cacheAttendanceSchedules(List<Map<String, dynamic>> classesData) async {
    try {
      final List<Map<String, dynamic>> scheduleData = [];
      final now = DateTime.now();

      for (var data in classesData) {
        final course = data['course'] as CourseModel;
        final classModel = data['class'] as ClassModel;
        
        // Only cache future classes
        if (classModel.startTime.isAfter(now)) {
          scheduleData.add({
            'courseId': course.id,
            'courseName': course.name,
            'classId': classModel.id,
            'className': classModel.className,
            'startTime': classModel.startTime.toIso8601String(),
            'endTime': classModel.endTime.toIso8601String(),
            'zoomLink': classModel.zoomLink,
            'notificationScheduled': false,
            'cachedAt': DateTime.now().toIso8601String(),
          });
        }
      }

      await _storage.write(
        key: _attendanceScheduleKey,
        value: jsonEncode(scheduleData),
      );

      await _storage.write(
        key: _lastCacheUpdateKey,
        value: DateTime.now().toIso8601String(),
      );

      print('📦 Cached ${scheduleData.length} future classes for offline notifications');
    } catch (e) {
      print('❌ Error caching attendance schedules: $e');
    }
  }

  /// Get cached attendance schedules
  Future<List<Map<String, dynamic>>> getCachedAttendanceSchedules() async {
    try {
      final String? cachedData = await _storage.read(key: _attendanceScheduleKey);
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('❌ Error reading cached attendance schedules: $e');
      return [];
    }
  }

  /// Get future classes that need notifications scheduled
  Future<List<Map<String, dynamic>>> getFutureClassesForNotification() async {
    try {
      final cachedSchedules = await getCachedAttendanceSchedules();
      final now = DateTime.now();
      
      return cachedSchedules.where((schedule) {
        final startTime = DateTime.parse(schedule['startTime']);
        final notificationScheduled = schedule['notificationScheduled'] ?? false;
        
        // Return classes that are in the future and haven't had notifications scheduled yet
        return startTime.isAfter(now) && !notificationScheduled;
      }).toList();
    } catch (e) {
      print('❌ Error getting future classes for notification: $e');
      return [];
    }
  }

  /// Mark notification as scheduled for a class
  Future<void> markNotificationScheduled(String classId) async {
    try {
      final cachedSchedules = await getCachedAttendanceSchedules();
      bool found = false;
      
      for (var schedule in cachedSchedules) {
        if (schedule['classId'] == classId) {
          schedule['notificationScheduled'] = true;
          schedule['notificationScheduledAt'] = DateTime.now().toIso8601String();
          found = true;
          break;
        }
      }
      
      if (found) {
        await _storage.write(
          key: _attendanceScheduleKey,
          value: jsonEncode(cachedSchedules),
        );
        print('✅ Marked notification as scheduled for class: $classId');
      } else {
        print('⚠️ Class $classId not found in cache when marking as scheduled');
      }
    } catch (e) {
      print('❌ Error marking notification as scheduled: $e');
    }
  }

  /// Check if notifications are already scheduled for a class
  Future<bool> areNotificationsScheduled(String classId) async {
    try {
      final cachedSchedules = await getCachedAttendanceSchedules();
      
      for (var schedule in cachedSchedules) {
        if (schedule['classId'] == classId) {
          return schedule['notificationScheduled'] ?? false;
        }
      }
      
      return false;
    } catch (e) {
      print('❌ Error checking if notifications are scheduled: $e');
      return false;
    }
  }

  /// Clean up old cached data (classes that have already passed)
  Future<void> cleanupOldCache() async {
    try {
      final cachedSchedules = await getCachedAttendanceSchedules();
      final now = DateTime.now();
      
      final activeCaches = cachedSchedules.where((schedule) {
        final endTime = DateTime.parse(schedule['endTime']);
        // Keep classes that haven't ended yet
        return endTime.isAfter(now);
      }).toList();
      
      await _storage.write(
        key: _attendanceScheduleKey,
        value: jsonEncode(activeCaches),
      );
      
      final removedCount = cachedSchedules.length - activeCaches.length;
      if (removedCount > 0) {
        print('🧹 Cleaned up $removedCount old cached classes');
      }
    } catch (e) {
      print('❌ Error cleaning up old cache: $e');
    }
  }

  /// Get last cache update time
  Future<DateTime?> getLastCacheUpdate() async {
    try {
      final String? lastUpdate = await _storage.read(key: _lastCacheUpdateKey);
      if (lastUpdate != null) {
        return DateTime.parse(lastUpdate);
      }
      return null;
    } catch (e) {
      print('❌ Error getting last cache update: $e');
      return null;
    }
  }

  /// Check if cache needs refresh (older than 2 hours)
  Future<bool> needsCacheRefresh() async {
    try {
      final lastUpdate = await getLastCacheUpdate();
      if (lastUpdate == null) return true;
      
      final now = DateTime.now();
      final difference = now.difference(lastUpdate);
      
      // Refresh if cache is older than 2 hours
      return difference.inHours >= 2;
    } catch (e) {
      print('❌ Error checking cache refresh need: $e');
      return true;
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      await _storage.delete(key: _attendanceScheduleKey);
      await _storage.delete(key: _lastCacheUpdateKey);
      print('🗑️ Cleared all cached attendance data');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final cachedSchedules = await getCachedAttendanceSchedules();
      final lastUpdate = await getLastCacheUpdate();
      final now = DateTime.now();
      
      final futureClasses = cachedSchedules.where((schedule) {
        final startTime = DateTime.parse(schedule['startTime']);
        return startTime.isAfter(now);
      }).length;
      
      final scheduledNotifications = cachedSchedules.where((schedule) {
        final startTime = DateTime.parse(schedule['startTime']);
        final notificationScheduled = schedule['notificationScheduled'] ?? false;
        return startTime.isAfter(now) && notificationScheduled;
      }).length;
      
      return {
        'totalCached': cachedSchedules.length,
        'futureClasses': futureClasses,
        'scheduledNotifications': scheduledNotifications,
        'lastUpdate': lastUpdate?.toIso8601String(),
        'needsRefresh': await needsCacheRefresh(),
      };
    } catch (e) {
      print('❌ Error getting cache stats: $e');
      return {
        'totalCached': 0,
        'futureClasses': 0,
        'scheduledNotifications': 0,
        'lastUpdate': null,
        'needsRefresh': true,
      };
    }
  }
}
