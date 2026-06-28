import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/shared_widgets.dart';
import '../data/transactions_api.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<VendorTransaction> _transactions = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  String? _typeFilter;

  static const _typeLabels = {
    null: 'All',
    'payment': 'Payments',
    'refund': 'Refunds',
    'payout': 'Payouts',
    'commission': 'Commission',
    'fee': 'Fees',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final result = await TransactionsApi.list(page: 1, type: _typeFilter);
      if (!mounted) return;
      setState(() {
        _transactions = result.transactions;
        _totalPages = result.pages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load transactions. Pull down to retry.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_page >= _totalPages || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final result = await TransactionsApi.list(page: next, type: _typeFilter);
      if (!mounted) return;
      setState(() {
        _transactions.addAll(result.transactions);
        _page = next;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'payment':
        return Icons.arrow_downward_rounded;
      case 'refund':
        return Icons.replay_rounded;
      case 'payout':
        return Icons.account_balance_wallet_outlined;
      case 'commission':
        return Icons.percent_rounded;
      case 'fee':
        return Icons.receipt_long_outlined;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  Color _typeColor(BuildContext context, String type) {
    final cs = Theme.of(context).colorScheme;
    switch (type) {
      case 'payment':
        return cs.primary;
      case 'refund':
      case 'fee':
      case 'commission':
        return Colors.orange;
      case 'payout':
        return Colors.blue;
      default:
        return cs.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy • HH:mm');

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _typeLabels.entries.map((e) {
                final selected = _typeFilter == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _typeFilter = e.key);
                      _load();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const AppLoading(message: 'Loading transactions…')
                  : _error != null
                      ? AppError(message: _error!, onRetry: _load)
                      : _transactions.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 80),
                                AppEmpty(
                                  icon: Icons.receipt_long_outlined,
                                  message: 'No transactions yet.',
                                ),
                              ],
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                if (n.metrics.pixels >=
                                    n.metrics.maxScrollExtent - 200) {
                                  _loadMore();
                                }
                                return false;
                              },
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 24),
                                itemCount: _transactions.length +
                                    (_loadingMore ? 1 : 0),
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  if (i >= _transactions.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 16),
                                      child: Center(
                                          child:
                                              CircularProgressIndicator(
                                                  strokeWidth: 2)),
                                    );
                                  }
                                  final t = _transactions[i];
                                  final color = _typeColor(
                                      context, t.transactionType);
                                  final isOutgoing = t.transactionType ==
                                          'refund' ||
                                      t.transactionType == 'commission' ||
                                      t.transactionType == 'fee';
                                  return ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 6),
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          color.withOpacity(0.12),
                                      child: Icon(
                                          _typeIcon(t.transactionType),
                                          color: color,
                                          size: 20),
                                    ),
                                    title: Text(
                                      t.orderNumber ?? t.transactionRef,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      '${t.transactionType[0].toUpperCase()}${t.transactionType.substring(1)} • ${dateFmt.format(t.initiatedAt)}',
                                      style:
                                          const TextStyle(fontSize: 12),
                                    ),
                                    trailing: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${isOutgoing ? '-' : ''}${t.currency} ${t.amount.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: isOutgoing
                                                ? Colors.red
                                                : color,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        StatusBadge(status: t.status),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
