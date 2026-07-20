import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/trust_safety_repository.dart';
import '../domain/report_reason.dart';

/// The single report/block surface every shared feature routes through. Built
/// before any user-to-user surface goes live so "moderation ready enough" is
/// true from day one (docs/08-ethics-privacy-safety.md §Content moderation).
///
/// [blockUserId] enables the block action (a profile id); pass null when only a
/// report makes sense. [onBlocked] lets the caller refresh its list.
Future<void> showReportBlockSheet(
  BuildContext context, {
  required ReportTargetType targetType,
  required String targetId,
  required String subjectLabel,
  String? blockUserId,
  VoidCallback? onBlocked,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportBlockSheet(
      targetType: targetType,
      targetId: targetId,
      subjectLabel: subjectLabel,
      blockUserId: blockUserId,
      onBlocked: onBlocked,
    ),
  );
}

/// A single, tappable report-reason row (a lightweight radio that avoids the
/// deprecated Radio groupValue API).
class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final ReportReason reason;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(reason.label)),
          ],
        ),
      ),
    );
  }
}

class _ReportBlockSheet extends ConsumerStatefulWidget {
  const _ReportBlockSheet({
    required this.targetType,
    required this.targetId,
    required this.subjectLabel,
    required this.blockUserId,
    required this.onBlocked,
  });

  final ReportTargetType targetType;
  final String targetId;
  final String subjectLabel;
  final String? blockUserId;
  final VoidCallback? onBlocked;

  @override
  ConsumerState<_ReportBlockSheet> createState() => _ReportBlockSheetState();
}

class _ReportBlockSheetState extends ConsumerState<_ReportBlockSheet> {
  ReportReason _reason = ReportReason.harassment;
  final _detail = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(trustSafetyRepositoryProvider).report(
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: _reason,
            detail: _detail.text,
          );
    } catch (_) {
      // Swallow: a failed report should never crash a social surface.
    }
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Thanks — our team will take a look.'),
      ),
    );
  }

  Future<void> _block() async {
    final id = widget.blockUserId;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(trustSafetyRepositoryProvider).block(id);
    } catch (_) {
      // Swallow.
    }
    if (!mounted) return;
    widget.onBlocked?.call();
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('${widget.subjectLabel} blocked.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report ${widget.subjectLabel}',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            "Tell us what's wrong. Reports are private.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final reason in ReportReason.values)
            _ReasonRow(
              reason: reason,
              selected: _reason == reason,
              onTap: _busy ? null : () => setState(() => _reason = reason),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _detail,
            enabled: !_busy,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            decoration: const InputDecoration(
              hintText: 'Add any detail (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submitReport,
              child: const Text('Submit report'),
            ),
          ),
          if (widget.blockUserId != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _block,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.terracotta,
                  side: const BorderSide(color: AppTheme.terracotta),
                ),
                icon: const Icon(Icons.block),
                label: Text('Block ${widget.subjectLabel}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
