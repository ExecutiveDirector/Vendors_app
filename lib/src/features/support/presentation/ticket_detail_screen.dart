import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/shared_widgets.dart';
import '../data/support_api.dart';

class TicketDetailScreen extends StatefulWidget {
  final SupportTicket ticket;
  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  List<SupportMessage> _messages = [];
  bool _loading = true;
  String? _error;
  final _messageController = TextEditingController();
  bool _sending = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await SupportApi.messages(widget.ticket.ticketId);
      messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load messages.';
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await SupportApi.sendMessage(widget.ticket.ticketId, text);
      _messageController.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send message. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool get _isClosed =>
      widget.ticket.status == 'resolved' || widget.ticket.status == 'closed';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final timeFmt = DateFormat('MMM d, HH:mm');

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(widget.ticket.ticketNumber),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: StatusBadge(status: widget.ticket.status)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: cs.primary.withOpacity(0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.ticket.subject,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 6),
                Text(widget.ticket.description,
                    style: TextStyle(
                        fontSize: 13.5, color: cs.onSurface.withOpacity(0.75))),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const AppLoading()
                : _error != null
                    ? AppError(message: _error!, onRetry: _load)
                    : _messages.isEmpty
                        ? const AppEmpty(
                            icon: Icons.chat_bubble_outline,
                            message:
                                'No replies yet. Our support team will respond here.',
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, i) {
                              final m = _messages[i];
                              final isMine = m.senderType == 'vendor';
                              return Align(
                                alignment: isMine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.75),
                                  decoration: BoxDecoration(
                                    color: isMine
                                        ? cs.primary
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (!isMine)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 3),
                                          child: Text(
                                            m.senderName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: cs.onSurface
                                                  .withOpacity(0.6),
                                            ),
                                          ),
                                        ),
                                      Text(
                                        m.messageText,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isMine
                                              ? Colors.white
                                              : cs.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        timeFmt.format(m.sentAt),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isMine
                                              ? Colors.white.withOpacity(0.7)
                                              : cs.onSurface.withOpacity(0.45),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          if (_isClosed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: Colors.grey[100],
              child: Text(
                'This ticket is ${widget.ticket.status}. Open a new ticket if you need further help.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: cs.onSurface.withOpacity(0.6)),
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message…',
                          isDense: true,
                        ),
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.send, color: cs.primary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
