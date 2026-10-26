import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../data/payouts_api.dart';

/// Vendor earnings and withdrawals. An admin approves each request, then it is
/// paid to the M-Pesa number or bank account chosen here.
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _money = NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);
  final _amount = TextEditingController();
  final _phone = TextEditingController();
  final _bankName = TextEditingController();
  final _account = TextEditingController();
  final _holder = TextEditingController();
  VendorEarnings? _earnings;
  List<VendorPayout> _payouts = [];
  bool _bank = false;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_amount, _phone, _bankName, _account, _holder]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([PayoutsApi.earnings(), PayoutsApi.list()]);
      if (!mounted) return;
      setState(() {
        _earnings = results[0] as VendorEarnings;
        _payouts = results[1] as List<VendorPayout>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your earnings. Pull down to retry.';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final e = _earnings;
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    String? problem;
    if (e == null || amount == null || amount <= 0) {
      problem = 'Enter the amount to withdraw.';
    } else if (amount < e.minPayout) {
      problem = 'The minimum withdrawal is ${_money.format(e.minPayout)}.';
    } else if (amount > e.available + 0.5) {
      problem = 'You can withdraw up to ${_money.format(e.available)}.';
    } else if (_bank &&
        (_bankName.text.trim().length < 2 || _account.text.trim().length < 6 || _holder.text.trim().length < 3)) {
      problem = 'Fill in the bank, account number and account name.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final err = await PayoutsApi.request(
      amount: amount!,
      bank: _bank,
      mpesaPhone: _phone.text.trim(),
      bankName: _bankName.text.trim(),
      bankAccountNumber: _account.text.trim(),
      bankAccountName: _holder.text.trim(),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    _amount.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Withdrawal requested. Once approved it is paid to your account.')));
    await _load();
  }

  Color _statusColor(String s) => switch (s) {
        'completed' => AppColors.success,
        'rejected' || 'failed' => AppColors.danger,
        _ => AppColors.warning,
      };

  String _statusLabel(String s) => switch (s) {
        'pending' => 'Waiting for approval',
        'approved' => 'Approved, paying soon',
        'processing' => 'Being paid',
        'completed' => 'Paid',
        'rejected' => 'Rejected',
        'failed' => 'Payment failed',
        _ => s,
      };

  @override
  Widget build(BuildContext context) {
    final e = _earnings;
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text('Withdraw earnings')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (e != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Available to withdraw'),
                            const SizedBox(height: 4),
                            Text(_money.format(e.available),
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Earned ${_money.format(e.earned)} · already requested or paid ${_money.format(e.committed)}',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('M-Pesa'), icon: Icon(Icons.phone_android)),
                      ButtonSegment(value: true, label: Text('Bank'), icon: Icon(Icons.account_balance)),
                    ],
                    selected: {_bank},
                    onSelectionChanged: (s) => setState(() {
                      _bank = s.first;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(labelText: 'Amount', prefixText: 'KES '),
                  ),
                  if (!_bank)
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'M-Pesa number (optional)',
                        helperText: 'Leave empty to use the number on your account',
                      ),
                    )
                  else ...[
                    TextField(controller: _bankName, decoration: const InputDecoration(labelText: 'Bank name')),
                    TextField(
                      controller: _account,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Account number'),
                    ),
                    TextField(controller: _holder, decoration: const InputDecoration(labelText: 'Account name')),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _sending ? null : _submit,
                    child: Text(_sending ? 'Sending…' : 'Request withdrawal'),
                  ),
                  const SizedBox(height: 24),
                  const Text('Your requests', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_payouts.isEmpty) const Text('No withdrawals yet.'),
                  for (final p in _payouts)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_money.format(p.amount)),
                      subtitle: Text(
                          '${p.method == 'bank_transfer' ? 'Bank' : 'M-Pesa'} · ${_statusLabel(p.status)}'
                          '${p.rejectionReason != null ? '\n${p.rejectionReason}' : ''}'),
                      trailing: Icon(Icons.circle, size: 12, color: _statusColor(p.status)),
                    ),
                ],
              ),
      ),
    );
  }
}
