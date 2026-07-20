import 'package:flutter/foundation.dart';

/// A gentle, no-fail reflection at the end of a lesson. It is *not* a test:
/// there is no score and no penalty, every option leads forward, and the
/// [insight] is always shown afterwards. [kindChoice] simply marks the answer
/// that best reflects welfare-first care, so the app can offer a warm "yes,
/// exactly" — never a red X.
@immutable
class Reflection {
  const Reflection({
    required this.question,
    required this.options,
    required this.kindChoice,
    required this.insight,
  });

  final String question;
  final List<String> options;
  final int kindChoice;
  final String insight;
}

/// A single responsible-care lesson (roadmap Phase 4: Guardian Missions —
/// "learning responsible care"). This is the *educational* mission subset only:
/// pure in-app knowledge with no real-world action prompt, no partner, and no
/// money — so it needs none of the legal/partner scaffolding the rest of Phase 4
/// is gated on. Content is welfare-first throughout ("when gameplay and animal
/// welfare conflict, welfare wins").
@immutable
class CareLesson {
  const CareLesson({
    required this.id,
    required this.emoji,
    required this.title,
    required this.summary,
    required this.tips,
    required this.reflection,
  });

  final String id;
  final String emoji;
  final String title;
  final String summary;
  final List<String> tips;
  final Reflection reflection;
}

/// The fixed curriculum. Every lesson teaches real, widely-recommended
/// responsible cat care, framed kindly and for a young audience.
const List<CareLesson> kCareLessons = [
  CareLesson(
    id: 'water',
    emoji: '💧',
    title: 'Fresh water, always',
    summary: 'Cats need clean water within easy reach, topped up every day.',
    tips: [
      'Refill the water bowl daily and rinse it out — cats dislike stale water.',
      'Keep water away from the food bowl; many cats prefer them apart.',
      'A wide, shallow bowl is comfier than a deep, narrow one.',
    ],
    reflection: Reflection(
      question: 'Kismet keeps walking away from a full water bowl. What helps?',
      options: [
        'Move the bowl away from the food and refresh the water',
        'Leave it — they will drink when thirsty enough',
        'Only offer water at mealtimes',
      ],
      kindChoice: 0,
      insight: 'Fresh water in a calm spot, always available, keeps a cat '
          'hydrated and healthy — never ration it.',
    ),
  ),
  CareLesson(
    id: 'safe_home',
    emoji: '🪴',
    title: 'A safe home',
    summary: 'Some everyday plants and foods are harmful to cats.',
    tips: [
      'Lilies are highly toxic to cats — keep them out of the home entirely.',
      'Chocolate, onions, and grapes are not safe cat foods.',
      'Store cleaning products and medicines well out of paw-reach.',
    ],
    reflection: Reflection(
      question: 'A friend gives you a bouquet of lilies. Where do they go?',
      options: [
        'On the windowsill where the cat naps',
        'Somewhere with no cats at all, or politely rehomed',
        'On a high shelf in the same room',
      ],
      kindChoice: 1,
      insight: 'Lilies are dangerous even in tiny amounts, and a high shelf '
          'is not enough. A cat-safe home keeps them right away.',
    ),
  ),
  CareLesson(
    id: 'body_language',
    emoji: '🐈',
    title: 'Listening to body language',
    summary: 'Cats tell us how they feel — a good guardian learns to read it.',
    tips: [
      'A slow blink is a friendly “I feel safe with you.”',
      'Flattened ears, a flicking tail, or a crouch mean “give me space.”',
      'A cat that walks away is saying no — let them.',
    ],
    reflection: Reflection(
      question: 'Your cat’s tail is flicking fast and their ears go back. Do you…',
      options: [
        'Pick them up for a cuddle to cheer them up',
        'Give them quiet space and let them come back on their own',
        'Keep petting so they get used to it',
      ],
      kindChoice: 1,
      insight: 'Those are “I need space” signals. Respecting a cat’s no is how '
          'trust — and real affection — grows.',
    ),
  ),
  CareLesson(
    id: 'vet',
    emoji: '🩺',
    title: 'Regular vet care',
    summary: 'Check-ups catch problems early, long before a cat seems unwell.',
    tips: [
      'Cats hide illness well — a yearly vet check-up is worth it even when '
          'they seem fine.',
      'Keep vaccinations and parasite prevention up to date.',
      'A sudden change in eating, drinking, or litter habits is worth a call.',
    ],
    reflection: Reflection(
      question: 'Your cat seems perfectly healthy. Is a vet visit still useful?',
      options: [
        'Yes — a routine check-up catches hidden problems early',
        'No — only take a cat to the vet when it looks sick',
        'Only if they stop eating for several days',
      ],
      kindChoice: 0,
      insight: 'Because cats mask illness, routine check-ups are one of the '
          'kindest, most responsible habits a guardian can keep.',
    ),
  ),
  CareLesson(
    id: 'enrichment',
    emoji: '🧶',
    title: 'Play and enrichment',
    summary: 'Daily play and things to climb and scratch keep a cat happy.',
    tips: [
      'A few short play sessions a day let a cat “hunt”, pounce, and unwind.',
      'Offer a scratching post so claws have a healthy outlet.',
      'Perches and hiding spots let a cat feel secure and in control.',
    ],
    reflection: Reflection(
      question: 'Your cat is scratching the sofa. The kind fix is to…',
      options: [
        'Scold them each time until they stop',
        'Offer a scratching post nearby and praise them for using it',
        'Trim the sofa area off-limits and hope they forget',
      ],
      kindChoice: 1,
      insight: 'Scratching is a natural need, not naughtiness. Redirecting it '
          'to a post meets the need kindly — punishment only causes fear.',
    ),
  ),
  CareLesson(
    id: 'gentle_handling',
    emoji: '🤲',
    title: 'Gentle handling',
    summary: 'Let a cat set the pace — trust is built, never forced.',
    tips: [
      'Let a cat sniff your hand and choose to approach first.',
      'Support the body fully when lifting, and put them down when they wriggle.',
      'Never wake or corner a cat for a cuddle — invite, don’t insist.',
    ],
    reflection: Reflection(
      question: 'A new cat is hiding under the bed. The kindest first step is…',
      options: [
        'Reach under and gently pull them out to say hello',
        'Sit nearby, speak softly, and let them come out in their own time',
        'Block the hiding spot so they have to socialise',
      ],
      kindChoice: 1,
      insight: 'Letting a nervous cat set the pace is how they learn you are '
          'safe. Forcing contact teaches the opposite.',
    ),
  ),
];

/// Pure completion helper: has the guardian finished the whole curriculum?
/// Kept here (not in the repository) so it is trivially unit-testable.
bool academyIsComplete(Set<String> completedIds) =>
    kCareLessons.every((lesson) => completedIds.contains(lesson.id));

/// How many lessons in the fixed curriculum have been completed.
int academyCompletedCount(Set<String> completedIds) =>
    kCareLessons.where((lesson) => completedIds.contains(lesson.id)).length;
