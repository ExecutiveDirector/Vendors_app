import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/shared_widgets.dart';
import '../data/support_api.dart';
import 'ticket_detail_screen.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  List<SupportTicket> _tickets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tickets = await SupportApi.tickets();
      tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your tickets. Pull down to retry.';
        _loading = false;
      });
    }
  }

  Future<void> _openNewTicketSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewTicketSheet(),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Support'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'FAQ',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const _FaqSheet(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewTicketSheet,
        icon: const Icon(Icons.add),
        label: const Text('New Ticket'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const AppLoading(message: 'Loading your tickets…')
            : _error != null
                ? AppError(message: _error!, onRetry: _load)
                : _tickets.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          AppEmpty(
                            icon: Icons.support_agent_outlined,
                            message:
                                'No support tickets yet.\nTap "New Ticket" if you run into an issue.',
                            onAction: _openNewTicketSheet,
                            actionLabel: 'Create a ticket',
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: _tickets.length,
                        itemBuilder: (context, i) {
                          final t = _tickets[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TicketDetailScreen(ticket: t),
                                  ),
                                );
                                _load();
                              },
                              leading: CircleAvatar(
                                backgroundColor: cs.primary.withOpacity(0.12),
                                child: Icon(Icons.confirmation_number_outlined,
                                    color: cs.primary, size: 20),
                              ),
                              title: Text(
                                t.subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${t.ticketNumber} • ${DateFormat('MMM d, yyyy').format(t.createdAt)}',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              trailing: StatusBadge(status: t.status),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _NewTicketSheet extends StatefulWidget {
  const _NewTicketSheet();

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'order_issue';
  bool _submitting = false;
  String? _error;

  static const _categories = {
    'order_issue': 'Order issue',
    'delivery_problem': 'Delivery problem',
    'payment_issue': 'Payment issue',
    'product_quality': 'Product quality',
    'account_issue': 'Account issue',
    'technical_support': 'Technical support',
    'billing_inquiry': 'Billing inquiry',
    'other': 'Other',
  };

  Future<void> _submit() async {
    if (_subjectController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in both subject and description.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await SupportApi.create(
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not create the ticket. Please try again.';
          _submitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('New Support Ticket',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Subject'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration:
                    const InputDecoration(labelText: 'Describe the issue'),
                maxLines: 4,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit Ticket'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqSheet extends StatefulWidget {
  const _FaqSheet();

  @override
  State<_FaqSheet> createState() => _FaqSheetState();
}

class _FaqSheetState extends State<_FaqSheet> {
  List<FaqItem> _faqs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final faqs = await SupportApi.faq();
      if (mounted) setState(() {
        _faqs = faqs;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _loading
              ? const AppLoading(message: 'Loading FAQs…')
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text('Frequently Asked Questions',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    ..._faqs.map((f) => ExpansionTile(
                          title: Text(f.question,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 0, 16, 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(f.answer,
                                    style: const TextStyle(fontSize: 13.5)),
                              ),
                            ),
                          ],
                        )),
                  ],
                ),
        );
      },
    );
  }
}
