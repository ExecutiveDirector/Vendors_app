// lib/src/features/wholesaler_sync/presentation/wholesaler_sync_screen.dart
//
// Vendor-facing screen for the WhatsApp wholesaler -> catalog automation:
//   - "Review Queue" tab: approve/reject items the pipeline couldn't
//     confidently auto-apply (new products, big price jumps, low-confidence
//     matches).
//   - "WhatsApp Sources" tab: register/pause the WhatsApp groups that feed
//     this vendor's catalog.

import 'package:flutter/material.dart';
import '../data/wholesaler_sync_models.dart';
import '../data/wholesaler_sync_service.dart';

class WholesalerSyncScreen extends StatefulWidget {
  const WholesalerSyncScreen({super.key});

  @override
  State<WholesalerSyncScreen> createState() => _WholesalerSyncScreenState();
}

class _WholesalerSyncScreenState extends State<WholesalerSyncScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = WholesalerSyncService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wholesaler Sync'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Review Queue'),
            Tab(text: 'WhatsApp Sources'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ReviewQueueTab(service: _service),
          _SourcesTab(service: _service),
        ],
      ),
    );
  }
}

// ============================================================================
// REVIEW QUEUE TAB
// ============================================================================

class _ReviewQueueTab extends StatefulWidget {
  final WholesalerSyncService service;
  const _ReviewQueueTab({required this.service});

  @override
  State<_ReviewQueueTab> createState() => _ReviewQueueTabState();
}

class _ReviewQueueTabState extends State<_ReviewQueueTab> {
  List<CatalogStagingItem> _items = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

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
      final items = await widget.service.fetchStagingItems();
      if (mounted) setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _approve(CatalogStagingItem item) async {
    setState(() => _busyId = item.stagingId);
    try {
      await widget.service.approveStagingItem(
        item.stagingId,
        categoryId: item.suggestedCategoryId,
      );
      if (mounted) {
        setState(() => _items.removeWhere((i) => i.stagingId == item.stagingId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.extractedName} published to your catalog')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(CatalogStagingItem item) async {
    setState(() => _busyId = item.stagingId);
    try {
      await widget.service.rejectStagingItem(item.stagingId);
      if (mounted) {
        setState(() => _items.removeWhere((i) => i.stagingId == item.stagingId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Icon(Icons.check_circle_outline, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Nothing pending review — wholesaler updates either '
                  'published automatically or haven\'t come in yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _StagingItemCard(
          item: _items[i],
          busy: _busyId == _items[i].stagingId,
          onApprove: () => _approve(_items[i]),
          onReject: () => _reject(_items[i]),
        ),
      ),
    );
  }
}

class _StagingItemCard extends StatelessWidget {
  final CatalogStagingItem item;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _StagingItemCard({
    required this.item,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.extractedName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                _Badge(
                  label: item.isNewProduct
                      ? 'New product'
                      : 'Update: ${item.matchedProductName ?? ''}',
                  color: item.isNewProduct ? Colors.orange : Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${item.extractedSize ?? '—'} · Wholesale cost KES ${item.wholesaleCost.toStringAsFixed(0)}'
              '${item.computedRetailPrice != null ? ' → Retail KES ${item.computedRetailPrice!.toStringAsFixed(0)}' : ''}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            if (item.reviewReason != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber.shade800),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.friendlyReviewReason,
                      style: TextStyle(color: Colors.amber.shade800, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (item.isNewProduct && item.suggestedCategoryName != null) ...[
              const SizedBox(height: 6),
              Text(
                'Suggested category: ${item.suggestedCategoryName}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                  label: const Text('Reject', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: busy ? null : onApprove,
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ============================================================================
// SOURCES TAB
// ============================================================================

class _SourcesTab extends StatefulWidget {
  final WholesalerSyncService service;
  const _SourcesTab({required this.service});

  @override
  State<_SourcesTab> createState() => _SourcesTabState();
}

class _SourcesTabState extends State<_SourcesTab> {
  List<WholesalerSource> _sources = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sources = await widget.service.fetchSources();
      if (mounted) setState(() {
        _sources = sources;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _toggleStatus(WholesalerSource source) async {
    final next = source.status == 'active' ? 'paused' : 'active';
    try {
      await widget.service.updateSource(source.sourceId, status: next);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _showAddDialog() async {
    final jidCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final wholesalerCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register WhatsApp Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: jidCtrl,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp Group JID',
                  hintText: 'e.g. 12345678901234-1234567890@g.us',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(labelText: 'Label (optional)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: wholesalerCtrl,
                decoration: const InputDecoration(labelText: 'Wholesaler name (optional)'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ask AquaGas support for the group JID if you don\'t have it yet — '
                'it shows up automatically the first time the group sends a message.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Register')),
        ],
      ),
    );

    if (result == true && jidCtrl.text.trim().isNotEmpty) {
      try {
        await widget.service.createSource(
          whatsappGroupJid: jidCtrl.text.trim(),
          sourceLabel: labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim(),
          wholesalerName: wholesalerCtrl.text.trim().isEmpty ? null : wholesalerCtrl.text.trim(),
        );
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Register group'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sources.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No WhatsApp groups registered yet. Tap "Register group" to '
                      'connect a wholesaler price-list group.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _sources.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final s = _sources[i];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: ListTile(
                          title: Text(s.sourceLabel ?? s.whatsappGroupJid),
                          subtitle: Text(
                            '${s.wholesalerName ?? ''}\n${s.whatsappGroupJid}',
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _Badge(
                                label: s.status,
                                color: s.status == 'active' ? Colors.green : Colors.grey,
                              ),
                              IconButton(
                                icon: Icon(
                                  s.status == 'active' ? Icons.pause : Icons.play_arrow,
                                  size: 20,
                                ),
                                onPressed: () => _toggleStatus(s),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
