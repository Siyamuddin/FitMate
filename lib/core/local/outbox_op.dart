class OutboxOp {
  const OutboxOp({
    required this.id,
    required this.type,
    required this.entity,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String type;
  final String entity;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
}
