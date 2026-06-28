import '../../../core/api/dio_client.dart';

class SupportTicket {
  final int ticketId;
  final String ticketNumber;
  final String subject;
  final String description;
  final String category;
  final String priority;
  final String status;
  final DateTime createdAt;

  SupportTicket({
    required this.ticketId,
    required this.ticketNumber,
    required this.subject,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.createdAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      ticketId: int.tryParse(json['ticket_id']?.toString() ?? '') ?? 0,
      ticketNumber: json['ticket_number']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'other',
      priority: json['priority']?.toString() ?? 'medium',
      status: json['status']?.toString() ?? 'open',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class SupportMessage {
  final int messageId;
  final String senderType;
  final String senderName;
  final String messageText;
  final DateTime sentAt;

  SupportMessage({
    required this.messageId,
    required this.senderType,
    required this.senderName,
    required this.messageText,
    required this.sentAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      messageId: int.tryParse(json['message_id']?.toString() ?? '') ?? 0,
      senderType: json['sender_type']?.toString() ?? 'vendor',
      senderName: json['sender_name']?.toString() ?? '',
      messageText: json['message_text']?.toString() ?? '',
      sentAt: DateTime.tryParse(json['sent_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class FaqItem {
  final int id;
  final String category;
  final String question;
  final String answer;

  FaqItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      category: json['category']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      answer: json['answer']?.toString() ?? '',
    );
  }
}

/// Support is mounted at /api/v1/support (routes/support.js on the
/// backend), not under /vendors — AppConfig.apiBaseUrl already includes
/// /api/v1, so every path here is relative to that.
class SupportApi {
  static Future<List<SupportTicket>> tickets() async {
    final res = await ApiClient.dio.get('/support/tickets');
    final List<dynamic> data = res.data is List ? res.data : [];
    return data
        .map((e) => SupportTicket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<SupportTicket> create({
    required String subject,
    required String description,
    required String category,
  }) async {
    final res = await ApiClient.dio.post('/support/tickets', data: {
      'subject': subject,
      'description': description,
      'category': category,
    });
    final data = res.data is Map && res.data['data'] != null
        ? res.data['data']
        : res.data;
    return SupportTicket.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<SupportMessage>> messages(int ticketId) async {
    final res = await ApiClient.dio.get('/support/tickets/$ticketId/messages');
    final List<dynamic> data = res.data is List ? res.data : [];
    return data
        .map((e) => SupportMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> sendMessage(int ticketId, String message) async {
    await ApiClient.dio.post(
      '/support/tickets/$ticketId/messages',
      data: {'message': message},
    );
  }

  static Future<List<FaqItem>> faq() async {
    final res = await ApiClient.dio.get('/support/faq');
    final List<dynamic> data = res.data is List ? res.data : [];
    return data
        .map((e) => FaqItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
