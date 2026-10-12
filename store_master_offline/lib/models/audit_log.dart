// مدل AuditLog - لاگ‌های حسابرسی
class AuditLog {
  final int id;
  final int userId;
  final String userName;
  final String userRole;
  final String action;
  final String details;
  final int timestamp;

  AuditLog({
    this.id = 0,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.action,
    required this.details,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
        'action': action,
        'details': details,
        'timestamp': timestamp,
      };

  factory AuditLog.fromMap(Map<String, dynamic> m) => AuditLog(
        id: (m['id'] as num?)?.toInt() ?? 0,
        userId: (m['userId'] as num?)?.toInt() ?? 0,
        userName: (m['userName'] as String?) ?? '',
        userRole: (m['userRole'] as String?) ?? '',
        action: (m['action'] as String?) ?? '',
        details: (m['details'] as String?) ?? '',
        timestamp: (m['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      );
}
