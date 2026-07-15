import 'package:flutter/material.dart';

/// A small, reusable "coming soon" scaffold used by the Phase 0 feature stubs.
/// Replaced screen-by-screen as real features land — keeps the app navigable
/// and on-brand in the meantime.
class PlaceholderScaffold extends StatelessWidget {
  const PlaceholderScaffold({
    required this.title,
    required this.icon,
    required this.message,
    this.showAppBar = true,
    super.key,
  });

  final String title;
  final IconData icon;
  final String message;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(title)) : null,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
