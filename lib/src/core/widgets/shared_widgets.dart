import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

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

/// Turns any thrown error into a sentence a vendor can act on, instead of
/// showing raw exception text such as "DioException [connection error]".
String friendlyError(Object? error) {
  final raw = (error ?? '').toString();
  final t = raw.toLowerCase();
  if (t.contains('socketexception') ||
      t.contains('connection error') ||
      t.contains('connection refused') ||
      t.contains('failed host lookup') ||
      t.contains('network is unreachable')) {
    return 'No internet connection. Check your data or Wi-Fi and try again.';
  }
  if (t.contains('timeout') || t.contains('timed out')) {
    return 'The server is taking too long to respond. Please try again.';
  }
  if (t.contains('401') || t.contains('unauthorized')) {
    return 'Your session has expired. Please sign in again.';
  }
  if (t.contains('403') || t.contains('forbidden')) {
    return 'You do not have permission to do that.';
  }
  if (t.contains('404') || t.contains('not found')) {
    return 'We could not find what you were looking for.';
  }
  if (RegExp(r'\b5\d\d\b').hasMatch(t)) {
    return 'Something went wrong on our side. Please try again shortly.';
  }
  // Short messages written for people (e.g. "Out of stock") pass through.
  if (!t.contains('dioexception') && !t.contains('stack') && raw.length < 140) {
    final cleaned = raw.replaceFirst('Exception: ', '').trim();
    if (cleaned.isNotEmpty) return cleaned;
  }
  return 'Something went wrong. Please try again.';
}

/// True when [value] looks like a dialable phone number.
bool looksLikePhone(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length >= 9 && digits.length <= 15;
}

/// Opens the phone dialer for [number]; shows a snackbar if it cannot.
Future<void> callNumber(BuildContext context, String number) async {
  final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
  final ok = await launchUrl(Uri(scheme: 'tel', path: cleaned));
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the phone dialer.')),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: cs.primary),
          ),
          const SizedBox(height: 20),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.75),
                  fontSize: 15,
                  height: 1.4)),
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

/// Error state. Pass the raw error or message; it is shown in plain language.
class AppError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const AppError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppEmpty(
      icon: Icons.cloud_off_outlined,
      message: friendlyError(message),
      onAction: onRetry,
      actionLabel: 'Try again',
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

/// A softly pulsing placeholder block used while content loads.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
              const Color(0x1A808A9C), const Color(0x33808A9C), _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Placeholder list of card-shaped skeletons; use instead of a bare spinner.
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screen),
      itemCount: count,
      itemBuilder: (_, __) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                SkeletonBox(width: 120, height: 16),
                Spacer(),
                SkeletonBox(width: 64, height: 22, radius: 11),
              ]),
              SizedBox(height: 12),
              SkeletonBox(height: 12),
              SizedBox(height: 8),
              SkeletonBox(width: 180, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin banner shown when data on screen came from the offline cache.
class OfflineBanner extends StatelessWidget {
  final String message;
  const OfflineBanner(
      {super.key,
      this.message = 'You are offline. Showing your last saved orders.'});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppColors.warningSoft,
        child: Row(children: [
          const Icon(Icons.wifi_off_rounded,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  Color _color(BuildContext context) => AppTheme.statusColor(status);

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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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
  final Widget? trailing;
  const InfoTile(
      {super.key,
      required this.label,
      required this.value,
      this.icon,
      this.trailing});

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
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            Text(value,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Two buttons side by side, sharing the width equally (never stacked).
///
/// Use this wherever a screen, sheet or dialog offers a pair of actions, e.g.
/// Cancel / Confirm or Decline / Accept. [secondary] goes on the left and
/// [primary] on the right. Raise [primaryFlex] to give the main action more
/// room than the secondary one.
class ButtonPair extends StatelessWidget {
  final Widget secondary;
  final Widget primary;
  final int primaryFlex;
  final double gap;

  const ButtonPair({
    super.key,
    required this.secondary,
    required this.primary,
    this.primaryFlex = 1,
    this.gap = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: secondary),
        SizedBox(width: gap),
        Expanded(flex: primaryFlex, child: primary),
      ],
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
        ButtonPair(
          secondary: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          primary: ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  confirmColor ?? Theme.of(context).colorScheme.primary,
            ),
            child: Text(confirmLabel ?? 'Confirm'),
          ),
        ),
      ],
    ),
  );
}


/// Asks why an order is being cancelled. Returns the reason, or null if the
/// vendor backs out. The server requires it (and stores it for admin/refunds).
Future<String?> askCancelReason(BuildContext context,
    {required bool paid}) {
  const quick = [
    'Out of stock',
    'Cannot deliver to this area',
    'Outlet closed',
    'Customer asked to cancel',
  ];
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(paid
                  ? 'The customer has already paid. AquaGas will refund them.'
                  : 'The customer will be told the order was cancelled.'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final q in quick)
                    ChoiceChip(
                      label: Text(q, style: const TextStyle(fontSize: 12)),
                      selected: ctrl.text == q,
                      onSelected: (_) => setState(() => ctrl.text = q),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLength: 200,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Reason', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          ButtonPair(
            secondary: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Keep order')),
            primary: ElevatedButton(
              onPressed: ctrl.text.trim().length >= 3
                  ? () => Navigator.pop(ctx, ctrl.text.trim())
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Cancel order'),
            ),
          ),
        ],
      ),
    ),
  );
}
