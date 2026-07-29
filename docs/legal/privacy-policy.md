# Cat-ch — Privacy Policy

> **Version 1.0 — adopted (pre-launch).** This is the operative privacy policy for
> Cat-ch, self-prepared by the operator. The app is **not yet publicly live**; this
> policy takes effect on public launch and must be live *before* the app collects
> any information from a user (COPPA §312.4; GDPR Art. 12–14). It is written to be
> honest and complete; a one-time professional privacy review is still recommended
> before wide public launch, and any `[PLACEHOLDER]` (legal entity, address,
> governing law) must be filled with real facts before store submission.
>
> **Effective date:** on public launch (`[DATE]`)
> **Version / last updated:** 1.0 · 2026-07-21

## 1. Who we are

Cat-ch ("**Cat-ch**", "**we**", "**us**") is a mobile game operated by
`[LEGAL ENTITY / OPERATOR NAME]`, `[REGISTERED ADDRESS]`. For any privacy question,
to exercise your rights, or for a parent/guardian to contact us about a child, email
nykefleym@gmail.com (a dedicated role address should replace this before store submission). Our data protection point of contact is
`[DPO / RESPONSIBLE PERSON, if applicable]`.

This policy explains what we collect, why, how we handle it, how long we keep it,
who we share it with, and your choices — with particular care for **camera and
location data** and for **children**.

## 2. A note on children

Cat-ch is designed to be safe for a general audience that may include children.
Some features and data uses are **restricted by age band** (see §7 and §8):

- **Under 13:** reduced-data experience; **no social features**; we do not knowingly
  collect personal information from a child under 13 for social use, and where the
  core game collects a child's information (see §3), we rely on the notice and
  parental-consent process in §8.
- **13–17 ("teen"):** conservative defaults; showcases forced private; friends-only
  social where enabled.
- **18+ ("adult"):** standard experience with opt-in social.

We ask for an **age band only — never a birth date.** You may *optionally* share
your **birthday month** (the month alone, e.g. "July") so the app can celebrate
your special month. It is not a birth date, it stays on your device, and you can
skip it or clear it at any time.

## 3. What we collect, why, and for how long

| Data | Why we collect it | How long we keep it |
|------|-------------------|---------------------|
| **Camera image** (a photo you take of a cat) | To detect a real cat on-device and to generate your companion sprite in the cloud | **Deleted immediately after the sprite is generated.** We do not keep the original photo. |
| **Coarse location** (fuzzed to a neighbourhood/region) | To frame exploration and show a rough "where you met" label | Stored with the companion record; **we never collect or store your precise GPS coordinates** — the photo/location is reduced to a coarse area on your device before it is sent to us |
| **Age band** (`under 13` / `13–17` / `18+`) | To apply the right protections and gate features | With your profile until account deletion |
| **Display name** (optional, you choose it) | Your in-game Guardian identity | With your profile until account deletion |
| **Account/sign-in** | Anonymous by default; an email only if an adult opts into cloud backup | Until account deletion |
| **Gameplay data** (companions, care state, cosmetics) | To run the game and save your progress | Until account deletion |
| **Social data** (friends, blocks, reports) — only if social is enabled for you | To provide friends-only features and keep them safe | Until you remove it or delete your account; safety/moderation records may be kept longer as described in §6 |
| **Analytics events** | To understand and improve the game | Stripped of personal information and location; **no analytics are collected for users in the under-13 reduced-data mode** |

We do **not** collect precise location, we do **not** build advertising profiles,
we do **not** run third-party ad targeting, and we do **not** sell your personal
information.

### 3a. Camera — how it works and what we do not do

- The camera is used **only when you choose to take a photo** to meet a cat, with a
  just-in-time permission prompt explaining why.
- The photo is analysed **on your device** to check it shows a real cat, then sent
  to our image-generation provider (see §5) solely to create your sprite, and then
  **deleted.** We do not keep it, display it to other users, or use it to train
  advertising or identify people.
- If you decline camera access, the app still works — you simply can't capture new
  companions.

### 3b. Location — how it works and what we do not do

- Location is used **only to frame exploration**. Before anything leaves your device,
  your position is **reduced to a coarse area** (roughly neighbourhood level).
- We **never store or share your precise coordinates**, and we never publish a map
  showing where a specific real cat lives.
- If you decline location access, the app still works with reduced map features.

## 4. Our legal bases (where GDPR/UK-GDPR applies)

Our lawful bases per purpose (recorded in the lawful-basis register in
[`data-handling.md`](data-handling.md#lawful-basis-register)):

- Providing the game you asked for (companions, care, saving progress): **contract**.
- Camera detection + sprite generation: **consent** (camera permission) + performance
  of the game **contract**.
- Coarse-location framing: **consent** (location permission) + **legitimate interests**
  in a working map.
- Product analytics: **legitimate interests**, minimised and off for minors.
- Children's data: additional **parental consent / authorisation** as in §8.

## 5. Who we share data with (processors)

We use a small number of service providers who process data on our behalf under
contract; we do not sell data. `[ATTORNEY/OPS TO CONFIRM DPAs, regions, transfer
mechanisms.]`

- **`[Backend provider — Supabase]`** — authentication, database, storage, and
  realtime, hosting your account and gameplay data. Region: `[HOSTING REGION]`.
- **`[Image-generation provider — Cloudflare Workers AI (default) / Google Gemini
  (alternate)]`** — receives your cat photo **transiently** to generate a sprite,
  under contractual terms that it is **not retained and not used for training**
  `[CONFIRM CONTRACTUAL TERMS]`.

Where data leaves your region (e.g. EU/UK → elsewhere), we rely on
`[TRANSFER MECHANISM — SCCs / UK IDTA + transfer-impact assessment]`.

## 6. How we protect and retain data

- **Security:** each player's data is isolated by database Row-Level Security;
  sharing is explicit and revocable. Secrets are held server-side.
- **Retention:** as stated in §3. Source photos are ephemeral. Safety and moderation
  records (reports, restrictions, moderation actions) may be retained for
  `[RETENTION PERIOD]` to protect the community and meet legal obligations.
- A full written retention schedule is maintained in
  [`data-handling.md`](data-handling.md#retention-schedule).

## 7. Your choices and rights

Depending on where you live, you may have rights to **access, correct, delete,
export, or object to** the processing of your personal information (GDPR/UK-GDPR
Arts. 15–21; US state laws; and, for children, the parental rights in §8).

- **In-app:** you can edit your display name, manage permissions, and delete your
  account (which removes your associated data via cascading deletion).
- **By email:** contact nykefleym@gmail.com (a dedicated role address should replace this before store submission) to make a request. We aim to
  respond within `[RESPONSE WINDOW, e.g. 30 days]`.
- You may also lodge a complaint with your local data protection authority
  (e.g. the ICO in the UK; your EU member-state authority; the FTC in the US).

## 8. Children's privacy (COPPA · GDPR-K · UK AADC)

We take extra care with children's data.

- **Notice + parental consent.** Where we collect personal information from a child
  under 13 (for example, the camera image and coarse location used by the core
  game), we provide notice to a parent/guardian and obtain **verifiable parental
  consent** before that collection, using the process in the
  **[Parental Consent Form](parental-consent-form.md)**.
- **No social for under-13.** Children under 13 are not permitted to use friends,
  trading, contests, visiting, albums, or clubs.
- **Parental rights.** A parent/guardian may review the personal information we hold
  about their child, ask us to delete it, and refuse further collection by
  contacting nykefleym@gmail.com (a dedicated role address should replace this before store submission). We will verify the request comes from the
  child's parent/guardian before acting.
- **Data minimisation & high-privacy defaults** apply to all minors, per the UK
  Age-Appropriate Design Code.

## 9. Changes to this policy

We will update this policy as the app changes and will post the new effective date.
For material changes affecting children's data, we will seek renewed parental
consent where required.

## 10. Contact

`[OPERATOR NAME]` · `[REGISTERED ADDRESS]` · nykefleym@gmail.com (a dedicated role address should replace this before store submission)

---

_Version 1.0, self-prepared by the operator and adopted pre-launch. A one-time
professional privacy review is recommended before wide public launch, and the
remaining `[PLACEHOLDER]` business/jurisdiction facts must be filled before store
submission._
