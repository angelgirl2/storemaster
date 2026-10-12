class InvoiceDelivery {
  final int id;
  final int invoiceId;
  final String channel;
  final String destination;
  final int sentAt;
  final String status;
  final String note;

  InvoiceDelivery({
    this.id = 0,
    required this.invoiceId,
    required this.channel,
    required this.destination,
    int? sentAt,
    this.status = 'READY',
    this.note = '',
  }) : sentAt = sentAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'invoiceId': invoiceId,
        'channel': channel,
        'destination': destination,
        'sentAt': sentAt,
        'status': status,
        'note': note,
      };

  factory InvoiceDelivery.fromMap(Map<String, dynamic> m) => InvoiceDelivery(
        id: (m['id'] as num?)?.toInt() ?? 0,
        invoiceId: (m['invoiceId'] as num?)?.toInt() ?? 0,
        channel: (m['channel'] as String?) ?? 'FILE',
        destination: (m['destination'] as String?) ?? '',
        sentAt: (m['sentAt'] as num?)?.toInt(),
        status: (m['status'] as String?) ?? 'READY',
        note: (m['note'] as String?) ?? '',
      );
}
