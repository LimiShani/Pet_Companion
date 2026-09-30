import '../guides_repository.dart';
import 'guide_credits.dart';

// The English text of the cat guides. Written for Pet Companion: original
// text, mainstream advice, plain and warm. The reader adds the closing note
// (the `guideDisclaimer` string) at the end of every guide.
//
// When you change a guide's text, set its `updatedAt` to that day. A review
// (if a guide ever has one) covers the text as it was read, so it stops
// showing once `updatedAt` is later than the review date.

const catGuidesEn = <String, GuideText>{
  // -------------------------------------------------------------------
  // Getting started
  // -------------------------------------------------------------------
  'cat-first-week': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: "Your cat's first week at home",
    summary: 'A quiet room, a routine and slow introductions.',
    intro: 'A new home is a big change for a cat. Some walk in as if they own the place; many need days, '
        'and some need weeks, before they feel safe. Your job this week is to keep things quiet and let '
        'the cat set the pace.',
    sections: [
      GuideSection(
        heading: 'Start with one quiet room',
        paragraphs: [
          'Set up a single room before your cat arrives, with everything in it:',
        ],
        bullets: [
          'A litter box, in a corner away from the food.',
          'Food and fresh water.',
          'A bed, and a place to hide: a cardboard box on its side is fine.',
          'A scratching post and a toy or two.',
        ],
        after: [
          'Put the carrier down in that room, open its door and let your cat come out when ready.',
        ],
      ),
      GuideSection(
        heading: 'Let your cat come to you',
        paragraphs: [
          'Sit on the floor, speak softly and wait. Hiding is normal in the first days: never pull a cat '
              'out of a hiding place. A wand toy or a treat is a gentle way to make friends.',
          'Once your cat is eating, using the litter box and moving around the room with confidence, '
              'open the door and let them explore the rest of the home a little at a time.',
        ],
      ),
      GuideSection(
        heading: 'Make the home safe',
        bullets: [
          'Keep windows closed or fit secure screens, and block off balconies.',
          'Put away string, thread, hair ties and other small things a cat could swallow.',
          'Check your plants and flowers: lilies are very poisonous to cats.',
          'Keep the washing machine and dryer doors shut, and look inside before you start them.',
        ],
      ),
      GuideSection(
        heading: 'Food, litter and the vet',
        paragraphs: [
          'Keep to the food your cat was eating before, and make any change gradually over about a week.',
          'Book a first check-up with your vet in the first week or two to plan vaccinations, parasite '
              'treatment, microchipping and neutering.',
          'If your new cat has not eaten anything for a day, or is not using the litter box, call your '
              'vet rather than waiting.',
        ],
      ),
    ],
  ),
  'second-cat': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'Bringing home a second cat',
    summary: 'Separate rooms first, then scent, then sight.',
    intro: 'Cats are territorial, and most do not welcome a stranger overnight. A slow introduction, over '
        'days or even weeks, gives the two the best chance of living together peacefully. Rushing it is '
        'the most common mistake.',
    sections: [
      GuideSection(
        heading: 'Before the new cat arrives',
        paragraphs: [
          'Prepare a room of their own with a litter box, food, water, a bed and a scratching post, so '
              'the two cats do not meet on the first day.',
          'Ask your vet about a check-up for the newcomer before the cats share a space.',
        ],
      ),
      GuideSection(
        heading: 'Swap scents first',
        bullets: [
          'Swap their bedding between the two rooms.',
          'Rub a soft cloth on one cat\'s cheeks and leave it near the other.',
          'Let each cat explore the other\'s area while the other is out of it.',
        ],
        after: [
          'Move on when both cats sniff the new smell and carry on calmly.',
        ],
      ),
      GuideSection(
        heading: 'Then sight, then short meetings',
        paragraphs: [
          'Let them see each other through a door held slightly open, a baby gate or a screen. Feed them '
              'on either side, far apart at first, and move the bowls closer over several days.',
          'When both stay relaxed, try short meetings in the same room, with play and treats, and end '
              'each one while things are still calm.',
          'Some hissing at first is normal. If there is growling, staring or a fight, separate them '
              'quietly and go back a step. Do not punish either cat.',
        ],
      ),
      GuideSection(
        heading: 'Enough of everything',
        paragraphs: [
          'Cats share more easily when nobody has to compete. Give them a litter box each plus one '
              'extra, food and water in more than one place, and several beds, scratching posts and high '
              'perches.',
        ],
      ),
      GuideSection(
        heading: 'If it is not settling',
        paragraphs: [
          'Some pairs need months, and some only ever tolerate each other. If the fighting continues, or '
              'one cat stops eating, hides all the time or stops using the litter box, talk to your vet, '
              'who can check for a health problem and suggest a behaviour specialist.',
        ],
      ),
    ],
  ),

  // -------------------------------------------------------------------
  // Home and cleaning
  // -------------------------------------------------------------------
  'litter-setup': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'Setting up the litter box',
    summary: 'The right box, the right litter and the right spot.',
    intro: 'Most cats take to a litter box with no teaching at all, as long as the box suits them. '
        'Getting the box, the litter and the place right from the first day prevents most problems.',
    sections: [
      GuideSection(
        heading: 'Choosing the box',
        paragraphs: [
          'Bigger is better: your cat should be able to turn around and dig comfortably. A common guide '
              'is a box about one and a half times as long as the cat.',
          'Kittens and older cats need a low side to step over. Covered or open is a matter of taste: '
              'many cats prefer an open box. If you are not sure, offer both and see which one is used.',
        ],
      ),
      GuideSection(
        heading: 'Choosing the litter',
        paragraphs: [
          'Most cats prefer a fine, unscented litter that clumps. Fill the box about five centimetres '
              'deep: enough to dig in and cover.',
          'If you change the type of litter, mix the new one into the old one over about a week.',
        ],
      ),
      GuideSection(
        heading: 'Where to put it',
        bullets: [
          'Somewhere quiet that is always easy to reach.',
          'Away from the food and water bowls.',
          'Not next to a noisy machine that might start up and frighten your cat.',
          'In the same place every day: a box that keeps moving is hard to trust.',
        ],
      ),
      GuideSection(
        heading: 'Helping a kitten learn',
        paragraphs: [
          'Put your kitten in the box after meals and naps and let them dig. Praise quietly when they '
              'use it.',
          'Never punish an accident: it only teaches fear. Clean the spot with an enzymatic cleaner so '
              'the smell does not invite a repeat.',
          'An adult cat that stops using the box may be unwell, so check with your vet.',
        ],
      ),
    ],
  ),
  'litter-count': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'How many litter boxes do you need?',
    summary: 'One for each cat, plus one, and where to put them.',
    intro: 'The usual guideline is simple: one litter box for each cat, plus one extra. One cat, two '
        'boxes. Two cats, three.',
    sections: [
      GuideSection(
        heading: 'Why the extra box',
        paragraphs: [
          'Many cats prefer not to use a box that has just been used, and some will not share at all. '
              'A spare box means there is always a clean choice, and it stops one cat from guarding the '
              'only box against another.',
        ],
      ),
      GuideSection(
        heading: 'Where to put them',
        bullets: [
          'Spread the boxes around the home. Two boxes side by side count as one to a cat.',
          'Choose quiet spots, away from food and water.',
          'In a larger home, keep a box on every floor.',
          'Make sure a cat using a box cannot be cornered there by another cat.',
        ],
      ),
      GuideSection(
        heading: 'In a small home',
        paragraphs: [
          'If there is no room for the full number, come as close as you can, choose larger boxes and '
              'scoop more often. A clean box matters more to most cats than anything else about it.',
        ],
      ),
      GuideSection(
        heading: 'When a cat stops using the box',
        paragraphs: [
          'A cat that suddenly goes outside the box, strains, or visits it far more often than usual may '
              'be unwell. Call your vet rather than waiting.',
          'A cat that strains and passes little or no urine, a male cat especially, needs a vet '
              'urgently.',
        ],
      ),
    ],
  ),
  'litter-smell': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'Keeping litter smell and mess under control',
    summary: 'A daily routine that keeps the home fresh.',
    intro: 'A clean litter box hardly smells. When a home smells of cat, the cause is almost always '
        'scooping too rarely, too few boxes or litter that has been left too long.',
    sections: [
      GuideSection(
        heading: 'A simple routine',
        bullets: [
          'Scoop at least once a day. Twice is better, and needed with more than one cat.',
          'Top up the litter so it stays about five centimetres deep.',
          'Empty the box completely, wash it and refill it regularly: about every one to two weeks '
              'with clumping litter, more often with litter that does not clump.',
          'Wash the box with hot water and a mild, unscented washing-up liquid, then rinse and dry it.',
        ],
      ),
      GuideSection(
        heading: 'Less litter around the home',
        bullets: [
          'Put a litter mat in front of the box to catch what sticks to the paws.',
          'Try a box with higher sides if your cat kicks litter out, as long as they can still step '
              'in easily.',
          'A larger grain of litter usually travels less than a very fine one.',
          'Sweep or vacuum around the box every day or two.',
        ],
      ),
      GuideSection(
        heading: 'What to avoid',
        paragraphs: [
          'Strongly scented litter, air fresheners next to the box and strong-smelling cleaners can put '
              'a cat off using it. Fresh air and a clean box work better than covering the smell.',
          'Wash your hands after cleaning the box. If you are pregnant, ask someone else to do it if you '
              'can, or wear gloves, and ask your doctor for advice.',
        ],
      ),
      GuideSection(
        heading: 'When smell is a sign',
        paragraphs: [
          'Urine that smells much stronger than usual, far more or far larger clumps, diarrhoea, or a '
              'cat going outside the box can all point to a health problem. Tell your vet what you have '
              'noticed.',
        ],
      ),
    ],
  ),

  // -------------------------------------------------------------------
  // Training and behaviour
  // -------------------------------------------------------------------
  'indoor-play': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'Play and enrichment for indoor cats',
    summary: 'Short daily play, places to climb and things to scratch.',
    intro: 'An indoor cat is safe from traffic, but relies on you for everything a cat likes to do: '
        'hunting, climbing, scratching and watching the world. A bored cat may wake you at night, scratch '
        'the furniture or eat too much.',
    sections: [
      GuideSection(
        heading: 'Play like a hunt',
        paragraphs: [
          'Two or three short sessions a day, five to ten minutes each, do more than one long one. Move '
              'a wand toy like prey: away from the cat, behind furniture, stopping and starting.',
          'Let your cat catch it often, and finish with a small treat or a meal so the hunt ends in a '
              'catch. Put toys with string away afterwards.',
        ],
      ),
      GuideSection(
        heading: 'Places to climb, hide and watch',
        bullets: [
          'A cat tree or sturdy shelves to climb.',
          'A perch at a window with a secure screen.',
          'Cardboard boxes and paper bags with the handles removed.',
          'A quiet hideaway where nobody disturbs them.',
        ],
      ),
      GuideSection(
        heading: 'Something good to scratch',
        paragraphs: [
          'Scratching is a need, not a bad habit. Offer a post that is sturdy and tall enough for a full '
              'stretch, near where your cat sleeps and near anything they already scratch. Some cats '
              'prefer a flat cardboard scratcher.',
        ],
      ),
      GuideSection(
        heading: 'Make meals more interesting',
        paragraphs: [
          'Puzzle feeders, or a few small portions hidden around the home, turn eating into an activity. '
              'Swapping the toys that are out every week keeps them interesting.',
        ],
      ),
    ],
  ),
  'cat-nights': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'When your cat keeps you up at night',
    summary: 'Why it happens and how to shift the routine.',
    intro: 'Cats are naturally most active around dusk and dawn. Racing around at night, meowing at the '
        'bedroom door and waking you at five are common, especially in young cats, and the routine can '
        'usually be shifted.',
    sections: [
      GuideSection(
        heading: 'Tire them out in the evening',
        paragraphs: [
          'Play actively an hour or so before your bedtime, then give the main meal. Hunt, eat, groom, '
              'sleep is the order a cat follows naturally.',
        ],
      ),
      GuideSection(
        heading: 'Do not reward the wake-up call',
        paragraphs: [
          'If you get up and feed your cat when they meow at five in the morning, they learn that it '
              'works. Ignoring it has to be consistent, and it often gets louder for a few days before it '
              'stops.',
          'A feeder on a timer can serve an early breakfast, so the food no longer comes from you.',
        ],
      ),
      GuideSection(
        heading: 'Busy days, quiet nights',
        bullets: [
          'More play and food puzzles during the day.',
          'A window perch and places to climb.',
          'A comfortable bed of their own, with everything they need within reach if your bedroom door '
              'is closed.',
        ],
      ),
      GuideSection(
        heading: 'When to check with the vet',
        paragraphs: [
          'An adult or older cat that suddenly starts crying at night, seems restless or confused, or is '
              'eating or drinking much more than before should see the vet: a change like this can have a '
              'medical cause.',
          'A cat that is not neutered may call loudly at night. Your vet can advise you about neutering.',
        ],
      ),
    ],
  ),
  'scratch-bite': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'Scratching and play biting',
    summary: 'Give the claws and teeth a better target.',
    intro: 'Scratching is how a cat looks after its claws, stretches and leaves its mark. Play biting is '
        'usually a young cat practising the hunt on the nearest moving thing. Neither can be switched '
        'off, but both can be pointed somewhere better.',
    sections: [
      GuideSection(
        heading: 'Saving the furniture',
        bullets: [
          'Put a sturdy, tall scratching post right next to the thing being scratched.',
          'Cover the scratched spot for a while with a blanket or double-sided tape.',
          'Reward your cat for using the post with a treat, praise or a game.',
          'Ask your vet or a groomer to show you how to trim the claw tips.',
        ],
        after: [
          'Removing the claws is not an answer: it is an amputation, and it is banned in many countries.',
        ],
      ),
      GuideSection(
        heading: 'Play biting',
        paragraphs: [
          'Never use your hands or feet as toys. Play with a wand toy or something your cat can grab and '
              'kick instead.',
          'If teeth or claws touch your skin, stop moving, end the game and walk away for a minute. Do '
              'not shout, hit or spray water: it frightens the cat and can make the biting worse.',
        ],
      ),
      GuideSection(
        heading: 'Stroking that ends in a bite',
        paragraphs: [
          'Many cats enjoy being stroked only for a short time. Watch for a twitching tail, rippling '
              'skin, ears turning back or sudden stillness, and stop before the bite. Short strokes on the '
              'head and cheeks are usually welcome.',
        ],
      ),
      GuideSection(
        heading: 'When to get help',
        paragraphs: [
          'Wash any bite or scratch with soap and water. Cat bites become infected easily, so see a '
              'doctor about a bite that breaks the skin.',
          'A gentle cat that suddenly starts biting or scratching may be in pain. Check with your vet.',
        ],
      ),
    ],
  ),

  // -------------------------------------------------------------------
  // Health and grooming
  // -------------------------------------------------------------------
  'cat-call-vet': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'Knowing when to call the vet about your cat',
    summary: 'Signs that need urgent help, and signs to book a visit for.',
    intro: 'Cats are good at hiding that they feel unwell, so small changes matter. This guide cannot '
        'tell you what is wrong with your cat: only a vet who examines them can. When in doubt, phone '
        'your vet practice. They would rather hear from you early.',
    sections: [
      GuideSection(
        heading: 'Call straight away',
        bullets: [
          'Straining in the litter box, or passing little or no urine, a male cat especially.',
          'Difficulty breathing, breathing with the mouth open, or gums that are pale, blue or grey.',
          'Collapse, a seizure, or suddenly being unable to use the back legs.',
          'Repeated vomiting, or blood in the vomit or the stool.',
          'A fall from a height, a road accident or a bite wound, even if your cat seems fine.',
          'You think your cat has eaten or licked something poisonous, such as lilies, a human medicine '
              'or a flea product made for dogs.',
        ],
      ),
      GuideSection(
        heading: 'Call the same day',
        bullets: [
          'Not eating at all for a day. Do not wait longer than that.',
          'Hiding much more than usual, or a change in behaviour you cannot explain.',
          'Going outside the litter box, or visiting it much more often.',
        ],
      ),
      GuideSection(
        heading: 'Book a visit soon',
        bullets: [
          'Eating or drinking noticeably more or less than usual.',
          'Weight loss, or a coat that looks unkempt.',
          'Limping, sneezing or runny eyes that last more than a day or two.',
          'A new lump, or bad breath.',
        ],
      ),
      GuideSection(
        heading: 'Be prepared',
        paragraphs: [
          'Save your vet\'s number and the nearest out-of-hours clinic in your phone. Keep the carrier '
              'out at home so your cat is used to it, and keep a note of your cat\'s weight, medicines and '
              'vaccination dates.',
          'Never give a cat a human medicine or a medicine meant for another animal. Give only what your '
              'vet has prescribed for this cat.',
        ],
      ),
    ],
  ),
};
