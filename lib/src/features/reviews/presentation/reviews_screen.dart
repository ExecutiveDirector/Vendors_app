import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/shared_widgets.dart';
import '../data/reviews_api.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<VendorReview> _reviews = [];
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
      final reviews = await ReviewsApi.list();
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load reviews. Pull down to retry.';
        _loading = false;
      });
    }
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0;
    final sum = _reviews.fold<double>(0, (s, r) => s + r.overallRating);
    return sum / _reviews.length;
  }

  Future<void> _openReplySheet(VendorReview review) async {
    final replied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReplySheet(review: review),
    );
    if (replied == true) _load();
  }

  Widget _stars(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating.round() ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: Colors.amber[600],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Reviews'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const AppLoading(message: 'Loading reviews…')
            : _error != null
                ? AppError(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      if (_reviews.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _averageRating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _stars(_averageRating, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                '${_reviews.length} review${_reviews.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: cs.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_reviews.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: AppEmpty(
                            icon: Icons.reviews_outlined,
                            message: 'No reviews yet.',
                          ),
                        )
                      else
                        ..._reviews.map((review) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _stars(review.overallRating),
                                      const Spacer(),
                                      Text(
                                        dateFmt.format(review.createdAt),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color:
                                              cs.onSurface.withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (review.title != null &&
                                      review.title!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      review.title!,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14),
                                    ),
                                  ],
                                  if (review.reviewText != null &&
                                      review.reviewText!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      review.reviewText!,
                                      style: const TextStyle(fontSize: 13.5),
                                    ),
                                  ],
                                  if (review.hasResponse) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.storefront,
                                                  size: 14, color: cs.primary),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Your response',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: cs.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(review.vendorResponse!,
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () =>
                                            _openReplySheet(review),
                                        icon: const Icon(Icons.reply, size: 16),
                                        label: const Text('Reply'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}

class _ReplySheet extends StatefulWidget {
  final VendorReview review;
  const _ReplySheet({required this.review});

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = 'Please write a response.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ReviewsApi.respond(widget.review.reviewId, _controller.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not submit your response. Please try again.';
          _submitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              const Text('Reply to Review',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              if (widget.review.reviewText != null) ...[
                const SizedBox(height: 8),
                Text(
                  '"${widget.review.reviewText}"',
                  style: const TextStyle(
                      fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Your response',
                  hintText: 'Thank you for your feedback…',
                ),
                maxLines: 4,
                autofocus: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
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
                      : const Text('Submit Response'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
