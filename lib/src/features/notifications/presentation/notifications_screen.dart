// lib/src/features/notifications/presentation/notifications_screen.dart
//
// Changes:
//  • Real-time polling every 30 s via Timer.periodic (no FCM setup needed)
//  • Unread badge count exposed via static ValueNotifier so other screens
//    (e.g. dashboard) can listen and show a badge
//  • Uses ApiClient.dio (shared Dio instance with auth token) instead of a
//    raw Dio() with a hardcoded token placeholder
//  • Lifecycle-aware: polling pauses when app is backgrounded (WidgetsBinding)
//  • All previous UI kept intact

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/widgets/shared_widgets.dart';

// ─── Global unread count — listen from anywhere (e.g. dashboard badge) ───────
/// ValueNotifier<int> that holds the current unread notification count.
/// Subscribe with ValueListenableBuilder wherever you need a badge.
final notificationUnreadCount = ValueNotifier<int>(0);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  bool _isLoading = true;
  String? _error;

  String _selectedType = 'all';
  String _selectedPriority = 'all';
  bool _showUnreadOnly = false;

  List<NotificationItem> _notifications = [];

  // ── Polling ────────────────────────────────────────────────────────────────
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 30);

  final List<String> _notificationTypes = [
    'all', 'order_update', 'delivery_update', 'payment_update',
    'promotional', 'system_alert', 'reminder'
  ];
  final List<String> _priorities = ['all', 'low', 'normal', 'high'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _loadNotifications(showSpinner: true);
    _startPolling();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Pause polling when app goes to background, resume on foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotifications(); // immediate refresh on resume
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _loadNotifications());
  }

  // ── Data loading ───────────────────────────────────────────────────────────
  Future<void> _loadNotifications({bool showSpinner = false}) async {
    if (showSpinner && mounted) setState(() { _isLoading = true; _error = null; });
    try {
      final res = await ApiClient.dio.get('/vendors/notifications',
          queryParameters: {'page': 1, 'limit': 100});
      if (!mounted) return;

      final data = res.data;
      final List<dynamic> raw = data is Map
          ? (data['notifications'] as List? ?? [])
          : (data as List? ?? []);

      final items = raw.map((j) => NotificationItem.fromJson(j)).toList();
      final unread = items.where((n) => !n.isRead).length;

      // Update global badge counter
      notificationUnreadCount.value = unread;

      setState(() {
        _notifications = items;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Only show error state on initial load; silent fail on background polls
      if (showSpinner) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ── Mark read / delete ─────────────────────────────────────────────────────
  Future<void> _markAsRead(int id) async {
    try {
      await ApiClient.dio.put('/vendors/notifications/$id/read');
      if (!mounted) return;
      setState(() {
        final idx = _notifications.indexWhere((n) => n.notificationId == id);
        if (idx != -1) {
          _notifications[idx] =
              _notifications[idx].copyWith(isRead: true, readAt: DateTime.now());
        }
      });
      notificationUnreadCount.value =
          _notifications.where((n) => !n.isRead).length;
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiClient.dio.put('/vendors/notifications/mark-all-read');
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true, readAt: DateTime.now()))
            .toList();
      });
      notificationUnreadCount.value = 0;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteNotification(int id) async {
    try {
      await ApiClient.dio.delete('/vendors/notifications/$id');
      if (!mounted) return;
      setState(() => _notifications.removeWhere((n) => n.notificationId == id));
      notificationUnreadCount.value =
          _notifications.where((n) => !n.isRead).length;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Filtered lists ─────────────────────────────────────────────────────────
  List<NotificationItem> get _filtered {
    var list = List<NotificationItem>.from(_notifications);
    if (_selectedType != 'all') {
      list = list.where((n) => n.notificationType == _selectedType).toList();
    }
    if (_selectedPriority != 'all') {
      list = list.where((n) => n.priority == _selectedPriority).toList();
    }
    if (_showUnreadOnly) list = list.where((n) => !n.isRead).toList();
    return list;
  }

  List<NotificationItem> get _unread => _filtered.where((n) => !n.isRead).toList();
  List<NotificationItem> get _read   => _filtered.where((n) => n.isRead).toList();

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('Error: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadNotifications(showSpinner: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Row(
          children: [
            const Text('Notifications'),
            const SizedBox(width: 8),
            // Live unread badge on app bar title
            ValueListenableBuilder<int>(
              valueListenable: notificationUnreadCount,
              builder: (_, count, __) => count == 0
                  ? const SizedBox.shrink()
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange[700],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'mark_all_read') _markAllAsRead();
              if (v == 'refresh') _loadNotifications(showSpinner: true);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'mark_all_read',
                  child: Row(children: [
                    Icon(Icons.mark_email_read),
                    SizedBox(width: 8),
                    Text('Mark All Read')
                  ])),
              PopupMenuItem(
                  value: 'refresh',
                  child: Row(children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh')
                  ])),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey[600],
          tabs: [
            Tab(text: 'All (${_filtered.length})'),
            Tab(text: 'Unread (${_unread.length})'),
            Tab(text: 'Read (${_read.length})'),
          ],
        ),
      ),
      body: Column(children: [
        _buildFilterBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildList(_filtered),
              _buildList(_unread),
              _buildList(_read),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _filterChip(
              _getTypeName(_selectedType), Icons.category, _showTypeSelector),
          const SizedBox(width: 8),
          _filterChip('Priority: ${_selectedPriority.toUpperCase()}',
              Icons.priority_high, _showPrioritySelector),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Unread Only'),
            selected: _showUnreadOnly,
            onSelected: (v) => setState(() => _showUnreadOnly = v),
            selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
            checkmarkColor: Theme.of(context).primaryColor,
          ),
        ]),
      ),
    );
  }

  Widget _filterChip(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const Icon(Icons.arrow_drop_down, size: 16),
        ]),
      ),
    );
  }

  Widget _buildList(List<NotificationItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No notifications', style: TextStyle(color: Colors.grey[600])),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadNotifications(showSpinner: false),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildCard(items[i]),
      ),
    );
  }

  Widget _buildCard(NotificationItem n) {
    final unread = !n.isRead;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: unread ? 3 : 1,
      child: InkWell(
        onTap: () {
          if (unread) _markAsRead(n.notificationId);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: unread
                ? Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.3))
                : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _typeIcon(n.notificationType),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(n.title,
                              style: TextStyle(
                                  fontWeight: unread
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: 16)),
                        ),
                        if (unread)
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle)),
                      ]),
                      const SizedBox(height: 4),
                      Text(n.message,
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'mark_read') _markAsRead(n.notificationId);
                  if (v == 'delete') _confirmDelete(n);
                },
                child: Icon(Icons.more_vert, color: Colors.grey[400]),
                itemBuilder: (_) => [
                  if (!n.isRead)
                    const PopupMenuItem(
                        value: 'mark_read',
                        child: Row(children: [
                          Icon(Icons.mark_email_read, size: 18),
                          SizedBox(width: 8),
                          Text('Mark Read')
                        ])),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: Colors.red))
                      ])),
                ],
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _chip(_getTypeName(n.notificationType), _typeColor(n.notificationType)),
              const SizedBox(width: 8),
              _chip(n.priority.toUpperCase(), _priorityColor(n.priority)),
              const Spacer(),
              Text(_timeAgo(n.createdAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      );

  Widget _typeIcon(String type) {
    final (icon, color) = switch (type) {
      'order_update'    => (Icons.shopping_cart, Colors.blue),
      'delivery_update' => (Icons.local_shipping, Colors.green),
      'payment_update'  => (Icons.payment, Colors.purple),
      'promotional'     => (Icons.local_offer, Colors.orange),
      'system_alert'    => (Icons.warning, Colors.red),
      'reminder'        => (Icons.access_time, Colors.amber),
      _                 => (Icons.notifications, Colors.grey),
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Color _typeColor(String type) => switch (type) {
        'order_update'    => Colors.blue,
        'delivery_update' => Colors.green,
        'payment_update'  => Colors.purple,
        'promotional'     => Colors.orange,
        'system_alert'    => Colors.red,
        'reminder'        => Colors.amber,
        _                 => Colors.grey,
      };

  Color _priorityColor(String p) => switch (p) {
        'high'   => Colors.red,
        'normal' => Colors.blue,
        _        => Colors.grey,
      };

  String _getTypeName(String type) => switch (type) {
        'all'             => 'All Types',
        'order_update'    => 'Orders',
        'delivery_update' => 'Delivery',
        'payment_update'  => 'Payments',
        'promotional'     => 'Promotions',
        'system_alert'    => 'System',
        'reminder'        => 'Reminders',
        _                 => type,
      };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  void _confirmDelete(NotificationItem n) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Delete this notification?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteNotification(n.notificationId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Filter Notifications'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(labelText: 'Type'),
            items: _notificationTypes
                .map((t) =>
                    DropdownMenuItem(value: t, child: Text(_getTypeName(t))))
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedPriority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: _priorities
                .map((p) => DropdownMenuItem(
                    value: p, child: Text(p.toUpperCase())))
                .toList(),
            onChanged: (v) => setState(() => _selectedPriority = v!),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedType = 'all';
                _selectedPriority = 'all';
                _showUnreadOnly = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Apply')),
        ],
      ),
    );
  }

  void _showTypeSelector() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: _notificationTypes
            .map((t) => ListTile(
                  title: Text(_getTypeName(t)),
                  selected: _selectedType == t,
                  onTap: () {
                    setState(() => _selectedType = t);
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }

  void _showPrioritySelector() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: _priorities
            .map((p) => ListTile(
                  title: Text(p.toUpperCase()),
                  selected: _selectedPriority == p,
                  onTap: () {
                    setState(() => _selectedPriority = p);
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────
class NotificationItem {
  final int notificationId;
  final String notificationType;
  final String title;
  final String message;
  final String? actionUrl;
  final String priority;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? relatedEntityType;
  final int? relatedEntityId;

  const NotificationItem({
    required this.notificationId,
    required this.notificationType,
    required this.title,
    required this.message,
    this.actionUrl,
    required this.priority,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.relatedEntityType,
    this.relatedEntityId,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> j) {
    return NotificationItem(
      notificationId: j['notification_id'] ?? 0,
      notificationType: j['notification_type'] ?? 'system_alert',
      title: j['title'] ?? '',
      message: j['message'] ?? '',
      actionUrl: j['action_url'],
      priority: j['priority'] ?? 'normal',
      isRead: j['is_read'] == 1 || j['is_read'] == true,
      createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      readAt: j['read_at'] != null ? DateTime.tryParse(j['read_at']) : null,
      relatedEntityType: j['related_entity_type'],
      relatedEntityId: j['related_entity_id'],
    );
  }

  NotificationItem copyWith({bool? isRead, DateTime? readAt}) =>
      NotificationItem(
        notificationId: notificationId,
        notificationType: notificationType,
        title: title,
        message: message,
        actionUrl: actionUrl,
        priority: priority,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
        relatedEntityType: relatedEntityType,
        relatedEntityId: relatedEntityId,
      );
}
