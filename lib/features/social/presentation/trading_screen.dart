import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/social_repository.dart';
import '../data/trade_repository.dart';
import '../domain/friend.dart';
import '../domain/safe_play.dart';
import '../domain/trade.dart';

/// Cosmetic trading (roadmap p3d) — swap cozy charms with friends to complete
/// your set. Cosmetic-only and never for real money: charms grant no power and
/// can't be bought, only earned as a starter set and traded (ADR 0004). Every
/// trade is friends-only and re-validated server-side (migration 0010). The
/// whole surface is held behind [kSocialLive]: while off it shows an honest
/// gated state and never a simulated feed.
class TradingScreen extends ConsumerWidget {
  const TradingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cosmetic trading')),
      body: const SafeArea(
        top: false,
        child: kSocialLive ? _TradingBody() : _TradingGatedState(),
      ),
    );
  }
}

class _TradingBody extends ConsumerWidget {
  const _TradingBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charms = ref.watch(myCharmsProvider);
    final trades = ref.watch(proposedTradesProvider);
    final uid = ref.read(tradeRepositoryProvider).uid;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _propose(context, ref),
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Propose a trade'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const _SectionLabel('YOUR CHARMS'),
          const SizedBox(height: 8),
          charms.when(
            loading: () => const _Loading(),
            error: (_, __) =>
                const _Muted("Couldn't load your charms just now."),
            data: (owned) => _CharmCollection(owned: owned),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('TRADES'),
          const SizedBox(height: 8),
          trades.when(
            loading: () => const _Loading(),
            error: (_, __) => const _Muted("Couldn't load trades just now."),
            data: (list) {
              if (uid == null) {
                return const _Muted('Sign in to trade with friends.');
              }
              if (list.isEmpty) {
                return const _Muted(
                  'No trades yet. Propose one to swap charms with a friend.',
                );
              }
              return Column(
                children: [
                  for (final t in list)
                    _TradeCard(trade: t, viewerId: uid),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _propose(BuildContext context, WidgetRef ref) async {
    final friends = await ref.read(friendsProvider.future);
    final accepted = friends.where((f) => f.isAccepted).toList();
    if (!context.mounted) return;
    if (accepted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Add a friend first to trade charms 🐾'),
      ));
      return;
    }
    final friend = await showModalBottomSheet<Friend>(
      context: context,
      builder: (_) => _FriendPickerSheet(friends: accepted),
    );
    if (friend == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProposeTradeScreen(
          friendId: friend.id,
          friendLabel: friend.label,
        ),
      ),
    );
  }
}

class _CharmCollection extends StatelessWidget {
  const _CharmCollection({required this.owned});

  final List<OwnedCosmetic> owned;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{for (final c in owned) c.itemId: c.quantity};
    final have = counts.keys.where((k) => (counts[k] ?? 0) > 0).length;
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$have / ${kCharmOrder.length} collected',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.8,
            children: [
              for (final id in kCharmOrder)
                _CharmSlot(itemId: id, quantity: counts[id] ?? 0),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharmSlot extends StatelessWidget {
  const _CharmSlot({required this.itemId, required this.quantity});

  final String itemId;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owned = quantity > 0;
    return Opacity(
      opacity: owned ? 1 : 0.35,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusChip),
                ),
                child: Text(charmEmoji(itemId),
                    style: const TextStyle(fontSize: 24)),
              ),
              if (quantity > 1)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('×$quantity',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_charmName(itemId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _TradeCard extends ConsumerWidget {
  const _TradeCard({required this.trade, required this.viewerId});

  final Trade trade;
  final String viewerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final incoming = trade.isIncoming(viewerId);
    final friends = ref.watch(friendsProvider).valueOrNull ?? const [];
    final other = trade.otherId(viewerId);
    final label = _labelFor(friends, other);
    // From the viewer's perspective, "you get" and "you give".
    final youGet = incoming ? trade.give : trade.request;
    final youGive = incoming ? trade.request : trade.give;
    return _Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            incoming ? '$label wants to trade' : 'Your offer to $label',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _OfferRow(label: 'You get', lines: youGet, tint: AppTheme.sage),
          const SizedBox(height: 6),
          _OfferRow(
              label: 'You give', lines: youGive, tint: theme.colorScheme.primary),
          const SizedBox(height: 12),
          if (incoming)
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _act(context, ref, _TradeAct.accept),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _act(context, ref, _TradeAct.decline),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _act(context, ref, _TradeAct.cancel),
                child: const Text('Cancel offer'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _act(
      BuildContext context, WidgetRef ref, _TradeAct act) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(tradeRepositoryProvider);
    final outcome = switch (act) {
      _TradeAct.accept => await repo.accept(trade.id),
      _TradeAct.decline => await repo.decline(trade.id),
      _TradeAct.cancel => await repo.cancel(trade.id),
    };
    ref.invalidate(proposedTradesProvider);
    if (outcome == TradeOutcome.ok) ref.invalidate(myCharmsProvider);
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
  }

  String _labelFor(List<Friend> friends, String id) {
    for (final f in friends) {
      if (f.id == id) return f.label;
    }
    return 'A friend';
  }
}

enum _TradeAct { accept, decline, cancel }

class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.label, required this.lines, required this.tint});

  final String label;
  final List<OfferLine> lines;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              )),
        ),
        Expanded(
          child: lines.isEmpty
              ? Text('nothing',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final l in lines)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.14),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusChip),
                        ),
                        child: Text(
                          '${l.emoji} ${l.label}'
                          '${l.quantity > 1 ? ' ×${l.quantity}' : ''}',
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Build a two-sided offer to a chosen friend: pick charms to give (from your
/// own) and charms to request (from the catalogue). The recipient's inventory is
/// never shown — the server checks they hold the requested charms at accept time.
class ProposeTradeScreen extends ConsumerStatefulWidget {
  const ProposeTradeScreen({
    super.key,
    required this.friendId,
    required this.friendLabel,
  });

  final String friendId;
  final String friendLabel;

  @override
  ConsumerState<ProposeTradeScreen> createState() =>
      _ProposeTradeScreenState();
}

class _ProposeTradeScreenState extends ConsumerState<ProposeTradeScreen> {
  final _give = <String, int>{};
  final _request = <String, int>{};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final charms = ref.watch(myCharmsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Trade with ${widget.friendLabel}')),
      body: SafeArea(
        top: false,
        child: charms.when(
          loading: () => const _Loading(),
          error: (_, __) => const _Muted("Couldn't load your charms."),
          data: (owned) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const _SectionLabel('YOU GIVE'),
              const SizedBox(height: 8),
              if (owned.isEmpty)
                const _Muted('You have no charms to give yet.')
              else
                for (final c in owned)
                  _StepperRow(
                    emoji: c.emoji,
                    label: c.label,
                    value: _give[c.itemId] ?? 0,
                    max: c.quantity,
                    onChanged: (v) => setState(() => _setQty(_give, c.itemId, v)),
                  ),
              const SizedBox(height: 20),
              const _SectionLabel('YOU ASK FOR'),
              const SizedBox(height: 8),
              for (final id in kCharmOrder)
                _StepperRow(
                  emoji: charmEmoji(id),
                  label: _charmName(id),
                  value: _request[id] ?? 0,
                  max: 3,
                  onChanged: (v) => setState(() => _setQty(_request, id, v)),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy || _isEmpty ? null : _send,
                icon: const Icon(Icons.send),
                label: const Text('Send offer'),
              ),
              const SizedBox(height: 8),
              Text(
                'Charms are cosmetic only — never anything you can win with, and '
                'never for real money.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isEmpty => _give.isEmpty && _request.isEmpty;

  void _setQty(Map<String, int> side, String id, int v) {
    if (v <= 0) {
      side.remove(id);
    } else {
      side[id] = v;
    }
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final offer = TradeOffer(
      give: [
        for (final e in _give.entries)
          OfferLine(itemId: e.key, quantity: e.value),
      ],
      request: [
        for (final e in _request.entries)
          OfferLine(itemId: e.key, quantity: e.value),
      ],
    );
    final outcome =
        await ref.read(tradeRepositoryProvider).propose(widget.friendId, offer);
    ref.invalidate(proposedTradesProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
    if (outcome == TradeOutcome.ok) navigator.pop();
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.emoji,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String emoji;
  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 20,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _FriendPickerSheet extends StatelessWidget {
  const _FriendPickerSheet({required this.friends});

  final List<Friend> friends;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text('Trade with…',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: friends.length,
              itemBuilder: (_, i) {
                final f = friends[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: const Icon(Icons.pets, size: 18),
                  ),
                  title: Text(f.label),
                  onTap: () => Navigator.of(context).pop(f),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// --- Small shared pieces -----------------------------------------------------

String _charmName(String id) {
  final owned = OfferLine(itemId: id, quantity: 1);
  return owned.label;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Text(text,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.margin});
  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: child,
    );
  }
}

/// Shown while [kSocialLive] is off — honest about what trading will be and the
/// safeguards, never a simulated feed.
class _TradingGatedState extends StatelessWidget {
  const _TradingGatedState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.sage.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: theme.colorScheme.outline),
            boxShadow: AppTheme.cardShadow(theme.brightness),
          ),
          child: Column(
            children: [
              const Text('🧶', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Trading is coming',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Swap cozy charms with friends to complete your set. Cosmetics '
                'only — never anything you can win with or buy your way through, '
                'and never for real money. Only between friends you\'ve accepted, '
                'with reporting built in. We\'ll switch it on once we can host it '
                'safely.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
