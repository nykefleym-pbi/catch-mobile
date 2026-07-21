/// Why a player is reporting something. The token matches the `reports.reason`
/// check constraint in migration 0008.
enum ReportReason {
  harassment('harassment', 'Harassment or bullying'),
  inappropriate('inappropriate', 'Inappropriate content'),
  spam('spam', 'Spam or scam'),
  other('other', 'Something else');

  const ReportReason(this.token, this.label);

  final String token;
  final String label;
}

/// What is being reported. Matches the `reports.target_type` check constraint.
enum ReportTargetType {
  profile('profile'),
  cat('cat'),
  trade('trade'),
  message('message'),
  club('club');

  const ReportTargetType(this.token);

  final String token;
}
