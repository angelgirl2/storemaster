// مدل AttendanceRecord - حضور و غیاب
class AttendanceRecord {
  final int id;
  final int userId;
  final String userName;
  final int dateMillis;
  final int clockInTime;
  final int? clockOutTime;
  final String shiftType; // MORNING, EVENING, FULL_DAY
  final String status; // PRESENT, LATE, LEAVE
  final String note;
  final int overtimeMinutes;

  AttendanceRecord({
    this.id = 0,
    required this.userId,
    required this.userName,
    int? dateMillis,
    required this.clockInTime,
    this.clockOutTime,
    this.shiftType = 'MORNING',
    this.status = 'PRESENT',
    this.note = '',
    this.overtimeMinutes = 0,
  }) : dateMillis = dateMillis ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'userId': userId,
        'userName': userName,
        'dateMillis': dateMillis,
        'clockInTime': clockInTime,
        'clockOutTime': clockOutTime,
        'shiftType': shiftType,
        'status': status,
        'note': note,
        'overtimeMinutes': overtimeMinutes,
      };

  factory AttendanceRecord.fromMap(Map<String, dynamic> m) => AttendanceRecord(
        id: (m['id'] as num?)?.toInt() ?? 0,
        userId: (m['userId'] as num?)?.toInt() ?? 0,
        userName: (m['userName'] as String?) ?? '',
        dateMillis: (m['dateMillis'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        clockInTime: (m['clockInTime'] as num?)?.toInt() ?? 0,
        clockOutTime: (m['clockOutTime'] as num?)?.toInt(),
        shiftType: (m['shiftType'] as String?) ?? 'MORNING',
        status: (m['status'] as String?) ?? 'PRESENT',
        note: (m['note'] as String?) ?? '',
        overtimeMinutes: (m['overtimeMinutes'] as num?)?.toInt() ?? 0,
      );
}
