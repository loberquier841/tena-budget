import 'package:flutter/material.dart';
import 'package:tena_budget/services/notification_service_secure.dart';
import 'package:tena_budget/theme/tena_theme.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<BudgetNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await NotificationService.updateNotifications();
    setState(() {
      _notificationsFuture = NotificationService.getNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Marquer tout comme lu',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: FutureBuilder<List<BudgetNotification>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'Aucune notification',
                style: TextStyle(color: TenaColors.textSecondary, fontSize: 16),
              ),
            );
          }
          return ListView.separated(
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              return Dismissible(
                key: Key(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: TenaColors.danger,
                  child: const Icon(Icons.delete, color: TenaColors.background),
                ),
                onDismissed: (_) async {
                  await NotificationService.remove(n.id);
                  _refresh();
                },
                child: ListTile(
                  leading: Icon(
                    _severityIcon(n.severity),
                    color: _severityColor(n.severity),
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.isRead
                          ? FontWeight.normal
                          : FontWeight.bold,
                      color: n.isRead
                          ? TenaColors.textSecondary
                          : TenaColors.textPrimary,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.message,
                        style: TextStyle(color: TenaColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatTime(n.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: TenaColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () async {
                    await NotificationService.markAsRead(n.id);
                    _refresh();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    await NotificationService.markAllAsRead();
    _refresh();
  }

  IconData _severityIcon(NotificationSeverity severity) {
    switch (severity) {
      case NotificationSeverity.info:
        return Icons.info_outline;
      case NotificationSeverity.warning:
        return Icons.warning_amber_outlined;
      case NotificationSeverity.critical:
        return Icons.error_outline;
    }
  }

  Color _severityColor(NotificationSeverity severity) {
    switch (severity) {
      case NotificationSeverity.info:
        return TenaColors.info;
      case NotificationSeverity.warning:
        return TenaColors.danger;
      case NotificationSeverity.critical:
        return TenaColors.danger;
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) {
      return '${diff.inDays} j';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} min';
    } else {
      return 'À l\'instant';
    }
  }
}
