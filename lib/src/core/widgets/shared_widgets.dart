import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Standard back button for every feature-screen AppBar.
///
/// Pops the current route if there's something to pop back to. If this
/// screen was opened directly (e.g. a fresh deep link, or the route stack
/// was otherwise empty), it falls back to going to the dashboard instead of
/// doing nothing — so the back arrow always takes the vendor somewhere
/// sensible instead of being a dead button.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallback = '/dashboard'});

  /// Where to go if there's nothing left to pop.
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallback);
        }
      },
    );
  }
}

class AppEmpty extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;
  const AppEmpty({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: cs.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cs.onSurface.withOpacity(0.6), fontSize: 15)),
          if (onAction != null) ...[
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: onAction, child: Text(actionLabel ?? 'Retry')),
          ]
        ]),
      ),
    );
  }
}

class AppError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const AppError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppEmpty(
      icon: Icons.error_outline,
      message: message,
      onAction: onRetry,
      actionLabel: 'Retry',
    );
  }
}

class AppLoading extends StatelessWidget {
  final String? message;
  const AppLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(message!, style: const TextStyle(fontSize: 14)),
        ]
      ]),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  Color _color(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
      case 'processing':
        return Colors.purple;
      case 'ready':
        return Colors.teal;
      case 'dispatched':
      case 'in_transit':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'canceled':
      case 'cancelled':
        return Colors.red;
      case 'active':
      case 'available':
        return Colors.green;
      case 'inactive':
      case 'offline':
        return Colors.grey;
      default:
        return cs.primary;
    }
  }

  String _label() {
    switch (status.toLowerCase()) {
      case 'in_transit':
        return 'In Transit';
      default:
        return status[0].toUpperCase() + status.substring(1).toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        _label(),
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(children: [
        Expanded(
          child: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const InfoTile(
      {super.key, required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
        ],
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }
}

Future<bool?> showConfirmDialog(BuildContext context,
    {required String title,
    required String content,
    String? confirmLabel,
    Color? confirmColor}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                confirmColor ?? Theme.of(context).colorScheme.primary,
          ),
          child: Text(confirmLabel ?? 'Confirm'),
        ),
      ],
    ),
  );
}
