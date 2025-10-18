import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:excel/excel.dart' as excel_lib;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/course_model.dart';
import '../../models/class_model.dart';
import '../../models/attendance_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../providers/attendance_provider.dart';

class AttendanceReportsScreen extends StatefulWidget {
  const AttendanceReportsScreen({super.key});

  @override
  State<AttendanceReportsScreen> createState() => _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState extends State<AttendanceReportsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  CourseModel? selectedCourse;
  ClassModel? selectedClass;
  bool _isExporting = false;

  Future<void> _exportToExcel() async {
    if (selectedCourse == null || selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a course and class first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
      final summary = attendanceProvider.attendanceSummary;

      if (summary == null) {
        throw Exception('No attendance data available');
      }

      final presentStudents = summary['present'] as List<AttendanceModel>;
      final absentStudents = summary['absent'] as List<UserModel>;

      // Create Excel file
      var excel = excel_lib.Excel.createExcel();
      excel_lib.Sheet sheetObject = excel['Attendance Report'];

      // Header Style
      excel_lib.CellStyle headerStyle = excel_lib.CellStyle(
        bold: true,
        backgroundColorHex: excel_lib.ExcelColor.fromHexString('#066330'),
        fontColorHex: excel_lib.ExcelColor.white,
        horizontalAlign: excel_lib.HorizontalAlign.Center,
        verticalAlign: excel_lib.VerticalAlign.Center,
      );

      // Title
      sheetObject.merge(
        excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        excel_lib.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0),
      );
      var titleCell = sheetObject.cell(excel_lib.CellIndex.indexByString('A1'));
      titleCell.value = excel_lib.TextCellValue('Al-Siraj Attendance Report');
      titleCell.cellStyle = excel_lib.CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: excel_lib.HorizontalAlign.Center,
        verticalAlign: excel_lib.VerticalAlign.Center,
      );

      // Course and Class Info
      sheetObject.cell(excel_lib.CellIndex.indexByString('A2')).value = excel_lib.TextCellValue('Course:');
      sheetObject.cell(excel_lib.CellIndex.indexByString('B2')).value = excel_lib.TextCellValue(selectedCourse!.name);
      sheetObject.cell(excel_lib.CellIndex.indexByString('A3')).value = excel_lib.TextCellValue('Class:');
      sheetObject.cell(excel_lib.CellIndex.indexByString('B3')).value = excel_lib.TextCellValue(selectedClass!.className);
      sheetObject.cell(excel_lib.CellIndex.indexByString('A4')).value = excel_lib.TextCellValue('Date:');
      sheetObject.cell(excel_lib.CellIndex.indexByString('B4')).value = excel_lib.TextCellValue(
        DateFormat('MMM dd, yyyy').format(selectedClass!.startTime),
      );

      // Column Headers
      int headerRow = 5;
      sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRow)).value = excel_lib.TextCellValue('#');
      sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: headerRow)).value = excel_lib.TextCellValue('Student Name');
      sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: headerRow)).value = excel_lib.TextCellValue('Email');
      sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: headerRow)).value = excel_lib.TextCellValue('Status');
      sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: headerRow)).value = excel_lib.TextCellValue('Time Marked');

      for (int i = 0; i < 5; i++) {
        sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRow)).cellStyle = headerStyle;
      }

      // Present Students
      int currentRow = headerRow + 1;
      excel_lib.CellStyle presentStyle = excel_lib.CellStyle(
        backgroundColorHex: excel_lib.ExcelColor.fromHexString('#E8F5E9'),
      );

      for (int i = 0; i < presentStudents.length; i++) {
        var attendance = presentStudents[i];
        sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel_lib.IntCellValue(i + 1);
        sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = excel_lib.TextCellValue(attendance.studentName);
        sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value = excel_lib.TextCellValue(attendance.studentEmail);
        sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = excel_lib.TextCellValue('Present');
        sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = excel_lib.TextCellValue(
          DateFormat('hh:mm a').format(attendance.markedAt),
        );

        for (int j = 0; j < 5; j++) {
          sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: currentRow)).cellStyle = presentStyle;
        }
        currentRow++;
      }

      // Absent Students
      excel_lib.CellStyle absentStyle = excel_lib.CellStyle(
        backgroundColorHex: excel_lib.ExcelColor.fromHexString('#FFEBEE'),
      );

      for (int i = 0; i < absentStudents.length; i++) {
        var student = absentStudents[i];
        sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel_lib.IntCellValue(presentStudents.length + i + 1);
        sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = excel_lib.TextCellValue(student.name);
        sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value = excel_lib.TextCellValue(student.email);
        sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = excel_lib.TextCellValue('Absent');
        sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = excel_lib.TextCellValue('-');

        for (int j = 0; j < 5; j++) {
          sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: currentRow)).cellStyle = absentStyle;
        }
        currentRow++;
      }

      // Summary
      currentRow += 2;
      sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel_lib.TextCellValue('Summary:');
      sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow + 1)).value = excel_lib.TextCellValue('Total Students:');
      sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow + 1)).value = excel_lib.IntCellValue(presentStudents.length + absentStudents.length);
      sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow + 2)).value = excel_lib.TextCellValue('Present:');
      sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow + 2)).value = excel_lib.IntCellValue(presentStudents.length);
      sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow + 3)).value = excel_lib.TextCellValue('Absent:');
      sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow + 3)).value = excel_lib.IntCellValue(absentStudents.length);

      // Save file
      var fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      // Get file path and save
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'attendance_${selectedCourse!.name}_${selectedClass!.className}_$timestamp.xlsx';
      final filePath = '${directory.path}/$fileName';
      
      File file = File(filePath);
      await file.writeAsBytes(fileBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Attendance Report - ${selectedCourse!.name}',
        text: 'Attendance report for ${selectedClass!.className} on ${DateFormat('MMM dd, yyyy').format(selectedClass!.startTime)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel report exported successfully!'),
            backgroundColor: Color(0xFF066330),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  /// Build enhanced dropdown item for class selection (dropdown list)
  Widget _buildClassDropdownItem(ClassModel classModel) {
    final now = DateTime.now();
    final isPast = classModel.endTime.isBefore(now);
    final isUpcoming = classModel.startTime.isAfter(now);
    
    // Format date and time with 24-hour format and AM/PM
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final dateStr = dateFormat.format(classModel.startTime);
    final timeStr = '${timeFormat.format(classModel.startTime)} - ${timeFormat.format(classModel.endTime)}';
    
    // Determine status
    String status;
    Color statusColor;
    if (isPast) {
      status = 'Past Class';
      statusColor = Colors.grey.shade600;
    } else if (isUpcoming) {
      status = 'Upcoming';
      statusColor = Colors.blue.shade600;
    } else {
      status = 'In Progress';
      statusColor = Colors.green.shade600;
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Class name (main text)
          Text(
            classModel.className,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // Date and time with status on the right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Date and time (left side)
              Expanded(
                child: Text(
                  '$dateStr • $timeStr',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Status (right side)
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build selected class display (simplified for dropdown button)
  Widget _buildSelectedClassDisplay(ClassModel classModel) {
    final now = DateTime.now();
    final isPast = classModel.endTime.isBefore(now);
    final isUpcoming = classModel.startTime.isAfter(now);
    
    // Format date and time with 24-hour format and AM/PM
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final dateStr = dateFormat.format(classModel.startTime);
    final timeStr = '${timeFormat.format(classModel.startTime)} - ${timeFormat.format(classModel.endTime)}';
    
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
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Class name and date/time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                classModel.className,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                '$dateStr • $timeStr',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        // Status
        Text(
          status,
          style: TextStyle(
            fontSize: 10,
            color: statusColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Reports'),
        actions: [
          if (selectedCourse != null && selectedClass != null)
            IconButton(
              onPressed: _isExporting ? null : _exportToExcel,
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.file_download),
              tooltip: 'Export to Excel',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course selection
            const Text(
              'Select Course',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<CourseModel>>(
              stream: _firestoreService.getCourses(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      color: Colors.grey.shade50,
                    ),
                    child: const Center(
                      child: Text('No courses available'),
                    ),
                  );
                }

                final courses = snapshot.data!;
                
                // Find matching course by ID to avoid instance mismatch
                CourseModel? validSelectedCourse;
                if (selectedCourse != null) {
                  try {
                    validSelectedCourse = courses.firstWhere(
                      (c) => c.id == selectedCourse!.id,
                    );
                  } catch (e) {
                    validSelectedCourse = null;
                  }
                }
                
                  return DropdownButtonFormField<CourseModel>(
                  value: validSelectedCourse,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    filled: true,
                  ),
                  hint: const Text('Select a course'),
                  isExpanded: true,
                  items: courses.map((course) {
                    return DropdownMenuItem(
                      value: course,
                      child: Text(
                        course.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (course) {
                    setState(() {
                      selectedCourse = course;
                      selectedClass = null;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Class selection
            if (selectedCourse != null) ...[
              const Text(
                'Select Class',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<ClassModel>>(
                stream: _firestoreService.getClasses(selectedCourse!.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final classes = snapshot.data!;
                  if (classes.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.grey.shade50,
                      ),
                      child: const Center(
                        child: Text('No classes available for this course'),
                      ),
                    );
                  }

                  // Find matching class by ID to avoid instance mismatch
                  ClassModel? validSelectedClass;
                  if (selectedClass != null) {
                    try {
                      validSelectedClass = classes.firstWhere(
                        (c) => c.id == selectedClass!.id,
                      );
                    } catch (e) {
                      validSelectedClass = null;
                    }
                  }

                  return Container(
                    height: 60, // Increased height to accommodate selected item content
                    child: DropdownButtonFormField<ClassModel>(
                      value: validSelectedClass,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        filled: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      hint: const Text('Select a class'),
                      isExpanded: true,
                      selectedItemBuilder: (context) {
                        return classes.map((classModel) {
                          return _buildSelectedClassDisplay(classModel);
                        }).toList();
                      },
                      items: classes.map((classModel) {
                        return DropdownMenuItem(
                          value: classModel,
                          child: _buildClassDropdownItem(classModel),
                        );
                      }).toList(),
                      onChanged: (classModel) {
                        setState(() {
                          selectedClass = classModel;
                        });
                        // Load attendance summary
                        if (classModel != null) {
                          Provider.of<AttendanceProvider>(context, listen: false)
                              .loadAttendanceSummary(selectedCourse!.id, classModel.id);
                        }
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],

            // Attendance Summary
            if (selectedClass != null) ...[
              Expanded(
                child: Consumer<AttendanceProvider>(
                  builder: (context, attendanceProvider, _) {
                    if (attendanceProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final summary = attendanceProvider.attendanceSummary;
                    if (summary == null) {
                      return const Center(child: Text('No data available'));
                    }

                    final presentStudents = summary['present'] as List<AttendanceModel>;
                    final absentStudents = summary['absent'] as List<UserModel>;
                    final totalStudents = summary['totalStudents'] as int;
                    final presentCount = summary['presentCount'] as int;
                    final absentCount = summary['absentCount'] as int;

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Statistics
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Total',
                                  totalStudents.toString(),
                                  const Color(0xFF066330),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  'Present',
                                  presentCount.toString(),
                                  const Color(0xFFCA9A2D),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  'Absent',
                                  absentCount.toString(),
                                  Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Export Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isExporting ? null : _exportToExcel,
                              icon: _isExporting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.file_download),
                              label: Text(_isExporting ? 'Exporting...' : 'Export to Excel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF066330),
                                foregroundColor: Colors.white,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Present Students
                          const Text(
                            'Present Students',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (presentStudents.isEmpty)
                            const Text('No students marked present', style: TextStyle(color: Colors.grey))
                          else
                            ...presentStudents.map((attendance) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 1,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF066330),
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  child: const Icon(Icons.check, color: Colors.white),
                                ),
                                title: Text(attendance.studentName),
                                subtitle: Text(attendance.studentEmail),
                                trailing: Text(
                                  DateFormat('hh:mm a').format(attendance.markedAt),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )),
                          const SizedBox(height: 16),

                          // Absent Students
                          const Text(
                            'Absent Students',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (absentStudents.isEmpty)
                            const Text('All students present!', style: TextStyle(color: Colors.grey))
                          else
                            ...absentStudents.map((student) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 1,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white),
                                ),
                                title: Text(student.name),
                                subtitle: Text(student.email),
                              ),
                            )),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Select a course and class to view attendance',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
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

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      elevation: 2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

