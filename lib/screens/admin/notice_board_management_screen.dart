import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/notice_board_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/notice_board_model.dart';
import '../../widgets/custom_text_field.dart';

class NoticeBoardManagementScreen extends StatefulWidget {
  const NoticeBoardManagementScreen({super.key});

  @override
  State<NoticeBoardManagementScreen> createState() => _NoticeBoardManagementScreenState();
}

class _NoticeBoardManagementScreenState extends State<NoticeBoardManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NoticeBoardProvider>(context, listen: false).loadNotices();
    });
  }

  void _showCreateNoticeDialog() {
    final formKey = GlobalKey<FormState>();
    final messageController = TextEditingController();
    NoticeType selectedType = NoticeType.info;

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
                    'Create Notice',
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
                          // Notice Type Selection
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Notice Type',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const Divider(height: 1),
                                ...NoticeType.values.map((type) {
                                  return RadioListTile<NoticeType>(
                                    title: Row(
                                      children: [
                                        Icon(
                                          _getNoticeIcon(type),
                                          color: _getNoticeColor(type),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(type.displayName),
                                      ],
                                    ),
                                    value: type,
                                    groupValue: selectedType,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        selectedType = value!;
                                      });
                                    },
                                    activeColor: _getNoticeColor(type),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Message Input
                          CustomTextField(
                            controller: messageController,
                            label: 'Notice Message',
                            hint: 'Enter the message you want to show to students...',
                            maxLines: 4,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a message';
                              }
                              if (value.length < 10) {
                                return 'Message must be at least 10 characters';
                              }
                              return null;
                            },
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
                      Consumer<NoticeBoardProvider>(
                        builder: (context, noticeProvider, _) {
                          return ElevatedButton(
                            onPressed: noticeProvider.isLoading
                                ? null
                                : () async {
                                    if (formKey.currentState!.validate()) {
                                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                      final success = await noticeProvider.createNotice(
                                        message: messageController.text.trim(),
                                        type: selectedType,
                                        createdBy: authProvider.currentUser?.email ?? 'Admin',
                                      );

                                      if (success != null && mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Notice created successfully!'),
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
                            child: noticeProvider.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Create Notice'),
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

  void _showDeleteConfirmation(NoticeBoardModel notice) {
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
                      'Delete Notice',
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
                      'Are you sure you want to delete this notice?',
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
                        '"${notice.message}"',
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
                        final noticeProvider = Provider.of<NoticeBoardProvider>(context, listen: false);
                        await noticeProvider.deleteNotice(notice.id);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Notice deleted successfully'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notice Board Management'),
        backgroundColor: const Color(0xFF066330),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateNoticeDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Notice'),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        backgroundColor: const Color(0xFF066330),
        foregroundColor: Colors.white,
      ),
      body: Consumer<NoticeBoardProvider>(
        builder: (context, noticeProvider, _) {
          if (noticeProvider.isLoading && noticeProvider.notices.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (noticeProvider.notices.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_active, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notices yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to create your first notice',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: noticeProvider.notices.length,
            itemBuilder: (context, index) {
              final notice = noticeProvider.notices[index];
              return _buildNoticeCard(notice);
            },
          );
        },
      ),
    );
  }

  Widget _buildNoticeCard(NoticeBoardModel notice) {
    final noticeColor = _getNoticeColor(notice.type);
    final noticeIcon = _getNoticeIcon(notice.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with type and actions
              Row(
                children: [
                  Icon(
                    noticeIcon,
                    color: noticeColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    notice.type.displayName,
                    style: TextStyle(
                      color: noticeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: notice.isActive ? Colors.green.shade100 : Colors.grey.shade100,
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Text(
                      notice.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: notice.isActive ? Colors.green.shade700 : Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              notice.isActive ? Icons.visibility_off : Icons.visibility,
                              color: const Color(0xFF066330),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              notice.isActive ? 'Deactivate' : 'Activate',
                              style: const TextStyle(color: Color(0xFF066330)),
                            ),
                          ],
                        ),
                      ),
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
                    onSelected: (value) async {
                      if (value == 'toggle') {
                        final noticeProvider = Provider.of<NoticeBoardProvider>(context, listen: false);
                        await noticeProvider.toggleNoticeStatus(notice.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(notice.isActive ? 'Notice deactivated' : 'Notice activated'),
                              backgroundColor: const Color(0xFF066330),
                            ),
                          );
                        }
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(notice);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                notice.message,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              
              // Footer with date and creator
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    notice.createdBy,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy - hh:mm a').format(notice.createdAt),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
