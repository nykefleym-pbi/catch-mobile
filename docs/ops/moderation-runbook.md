# Cat-ch — Moderation Runbook (interim, solo moderator)

> **Status:** interim. The operator is the **sole moderator** for now. This runbook
> makes the moderation substrate (migrations 0009 + 0011) *operational* — it is the
> "a human reads reports within an SLA" that ADR 0004 and the pre-launch review
> require before any social surface goes live. Before scaling social beyond a small
> friends-only test, add more moderators, a console UI, and a tighter SLA.

## Role & SLA

- **Who:** the operator, acting as moderator.
- **SLA (interim):** review the open queue **at least once every 48 hours**, and
  within **24 hours** of a report involving a user in the teen band. Acknowledge,
  triage, and act or dismiss.
- **Coverage rule:** while `kSocialLive` is on, if you cannot meet the SLA for a
  sustained period, turn `kSocialLive` back **off** rather than leave reports
  unread. Unread reports on a minor-facing surface are not acceptable.

## Access (service role only — never the client)

The `mod_*` RPCs are granted to `service_role` only and revoked from every player
role. Call them from a **trusted context that holds the service key**:

- the Supabase **SQL editor / dashboard** (runs privileged), or
- a small server-side script using the **service-role key** (kept server-side, never
  in the app, chat, or git).

Never expose the service-role key in the Flutter client.

## Workflow

1. **List the queue** (most-flagged, newest first):
   ```sql
   select * from public.mod_queue(100);
   ```
   `reports_total` / `reports_open` show how many times a target has been flagged.

2. **Claim** an item so it's marked under review:
   ```sql
   select public.mod_claim_report('<report_id>');
   ```

3. **Investigate.** Look at the target (`target_type` + `target_id`) and the reason.
   For content targets, check the item; for a profile, check its recent reports.

4. **Act** — one atomic call records the action, optionally restricts the account,
   and resolves the report:
   ```sql
   -- dismiss (no violation)
   select public.mod_resolve_report('<report_id>', 'dismiss', 'no violation found');

   -- warn only
   select public.mod_resolve_report('<report_id>', 'warn', '<reason>');

   -- remove content
   select public.mod_resolve_report('<report_id>', 'remove_content', '<reason>');

   -- restrict the reported profile (mute/suspend/ban); days null = indefinite
   select public.mod_resolve_report('<report_id>', 'restrict', '<reason>', '<note>', 'suspend', 7);
   select public.mod_resolve_report('<report_id>', 'ban', '<reason>', '<note>', 'ban', null);
   ```

5. **Direct restriction / lift** (not tied to a report):
   ```sql
   select public.mod_issue_restriction('<profile_id>', 'suspend', '<reason>', 14);
   select public.mod_lift_restriction('<restriction_id>', 'appeal upheld');
   ```

## Decision guide

| Situation | Action | Restriction |
|-----------|--------|-------------|
| No violation | `dismiss` | — |
| Minor/first-time issue | `warn` | — |
| Inappropriate content | `remove_content` | consider `mute` |
| Harassment / repeated abuse | `restrict` or `ban` | `suspend` (escalating) → `ban` |
| Targeting or endangering a child | `ban` | `ban`, and escalate (below) |

Bias toward protecting younger players; when in doubt on a minor-safety report, act
conservatively (restrict) and review.

## Escalation beyond the app

Some reports are not moderation matters but **legal/safety emergencies** — e.g.
suspected child sexual abuse material, credible threats, or illegal activity. These
go **outside** the app tooling: preserve the minimum necessary evidence, restrict the
account, and report to the appropriate authority (e.g. NCMEC in the US, local police)
per legal obligation. `[Confirm reporting obligations for the launch market.]`

## Audit

Every action writes an append-only row to `moderation_actions` (service-role only,
invisible to clients). `restrictions.action_id` links a restriction back to the
action that created it. Keep these per the retention schedule in
[`../legal/data-handling.md`](../legal/data-handling.md#retention-schedule).
