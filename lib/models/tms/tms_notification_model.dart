class TmsNotificationItem {
  final int id;
  final String message;
  final String link;
  final bool isRead;
  final String? readAt;
  final String? createdAt;

  TmsNotificationItem({
    required this.id,
    required this.message,
    required this.link,
    required this.isRead,
    this.readAt,
    this.createdAt,
  });

  factory TmsNotificationItem.fromJson(Map<String, dynamic> json) {
    return TmsNotificationItem(
      id: json['id'] is int ? json['id'] : int.parse('${json['id']}'),
      message: json['message'] ?? '',
      link: json['link'] ?? '',
      isRead: json['is_read'] == true,
      readAt: json['read_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

class TmsNotificationInbox {
  final List<TmsNotificationItem> items;
  final int unreadCount;

  TmsNotificationInbox({
    required this.items,
    required this.unreadCount,
  });

  factory TmsNotificationInbox.fromJson(Map<String, dynamic> json) {
    var list = <TmsNotificationItem>[];
    if (json['items'] != null && json['items'] is List) {
      list = (json['items'] as List)
          .map((i) => TmsNotificationItem.fromJson(i))
          .toList();
    }
    return TmsNotificationInbox(
      items: list,
      unreadCount: json['unread_count'] is int
          ? json['unread_count']
          : int.tryParse('${json['unread_count']}') ?? 0,
    );
  }
}
