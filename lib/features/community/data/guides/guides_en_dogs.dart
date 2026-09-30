import '../guides_repository.dart';
import 'guide_credits.dart';

// The English text of the dog guides. Written for Pet Companion: original
// text, mainstream advice, plain and warm. The reader adds the closing note
// (`guideDisclaimer`) at the end of every guide.
//
// When you change a guide's text, set its `updatedAt` to that day. A review
// (if a guide ever has one) covers the text as it was read, so it stops
// showing once `updatedAt` is later than the review date.

const dogGuidesEn = <String, GuideText>{
  // -------------------------------------------------------------------
  // Getting started
  // -------------------------------------------------------------------
  'first-week': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: "Your puppy's first week at home",
    summary: 'A calm start: sleep, routine and first introductions.',
    intro: 'The first days in a new home are a lot for a young puppy: new smells, new people and no '
        'littermates. Your job this week is simple: keep things calm, predictable and kind.',
    sections: [
      GuideSection(
        heading: 'Set up a safe corner',
        paragraphs: [
          'Choose a quiet spot for a bed or crate, with water nearby. Let your puppy retreat there, and ask '
              'everyone, children especially, to leave them in peace when they do.',
          'Puppy-proof the rooms they will use:',
        ],
        bullets: [
          'Lift cables, shoes and small objects off the floor.',
          'Move houseplants and cleaning products out of reach.',
          'Block the stairs and any gaps behind furniture.',
        ],
      ),
      GuideSection(
        heading: 'Start a gentle routine',
        paragraphs: [
          'Puppies feel safe when the day repeats. Feed at the same times, take them outside after waking, '
              'eating and playing, and keep play sessions short.',
          'Young puppies sleep a great deal, often eighteen hours a day or more. Let them rest, and never '
              'wake a sleeping puppy to play.',
        ],
      ),
      GuideSection(
        heading: 'The first nights',
        paragraphs: [
          'Expect some crying: your puppy has never slept alone before. Keeping the bed or crate near your '
              'own bed for the first nights helps most puppies settle.',
          'If they wake, take them out for a quiet toilet break, then straight back to bed without play.',
        ],
      ),
      GuideSection(
        heading: 'Introductions and the vet',
        paragraphs: [
          'Introduce family members one or two at a time, and other pets slowly and under supervision. Hold '
              'off on visitors for a few days.',
          'Book a first check-up with your vet in the first week to plan vaccinations, worming and '
              'microchipping, and ask when it is safe for your puppy to walk in public places.',
        ],
      ),
    ],
  ),
  'house-training': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'House training without the stress',
    summary: 'A simple schedule and what to do about accidents.',
    intro: 'House training is mostly about timing. Take your puppy to the right place often enough and '
        'reward them there, and the habit builds itself. Most puppies are reliable within a few months, '
        'with the odd slip along the way.',
    sections: [
      GuideSection(
        heading: 'When to go out',
        bullets: [
          'First thing in the morning and last thing at night.',
          'After every meal, nap and play session.',
          'Every hour or two in between for a young puppy.',
        ],
        after: ['Watch for the signs as well: sniffing the floor, circling or heading for the door.'],
      ),
      GuideSection(
        heading: 'Make the right spot rewarding',
        paragraphs: [
          'Go out with your puppy, to the same spot each time, and wait quietly. The moment they finish, '
              'praise warmly and give a small treat right there, not back in the house.',
          'Saying a cue such as "be quick" while they go lets you ask for it later.',
        ],
      ),
      GuideSection(
        heading: 'When accidents happen',
        paragraphs: [
          'They will. Never scold or punish: a puppy does not connect the telling-off with the puddle, and '
              'may simply learn to hide from you when they need to go.',
          'If you catch them starting, calmly lead or carry them outside. Clean the spot with an enzymatic '
              'cleaner so the smell does not invite a repeat.',
        ],
      ),
      GuideSection(
        heading: 'Nights and time alone',
        paragraphs: [
          'Young puppies cannot hold on all night. As a rough guide, a puppy can wait about one hour for '
              'each month of age during the day, so plan a quiet night-time trip for the first weeks.',
          'If an adult dog who was clean suddenly starts having accidents, talk to your vet, as it can be a '
              'sign of a health problem.',
        ],
      ),
    ],
  ),

  // -------------------------------------------------------------------
  // Training and behaviour
  // -------------------------------------------------------------------
  'sit-stay-come': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'Sit, stay and come: the three basics',
    summary: 'Short, cheerful sessions that build on each other.',
    intro: 'These three cues make daily life easier and safer. Teach them with rewards: food, praise or a '
        'favourite toy. Keep sessions to about five minutes, a few times a day, and stop while your dog is '
        'still enjoying it.',
    sections: [
      GuideSection(
        heading: 'Sit',
        paragraphs: [
          'Hold a treat at your dog\'s nose and move it slowly up and back over their head. As the nose '
              'follows, the bottom goes down. The instant it touches the floor, say "yes" and give the treat.',
          'Once the movement is reliable, say "sit" just before you lure, then fade the treat out of your '
              'hand.',
        ],
      ),
      GuideSection(
        heading: 'Stay',
        paragraphs: [
          'Ask for a sit, show a flat palm, wait one second, then reward while your dog is still sitting. '
              'Build up slowly, changing only one thing at a time:',
        ],
        bullets: [
          'Duration: a few seconds more each time.',
          'Distance: one step away, then two.',
          'Distraction: a quiet room before the garden or the park.',
        ],
        after: [
          'Give a release word such as "okay" so your dog knows when the stay is over. If they get up early, '
              'simply make the next try easier.',
        ],
      ),
      GuideSection(
        heading: 'Come',
        paragraphs: [
          'Start indoors. Say your dog\'s name and "come" in a bright voice, and reward generously when they '
              'arrive. Practise outside on a long line before trusting it off the lead.',
          'Never call your dog to tell them off, or only to end the fun, or coming to you stops being a good '
              'thing.',
        ],
      ),
      GuideSection(
        heading: 'If it is not working',
        paragraphs: [
          'Go back a step, use better treats and reduce distractions. Avoid repeating the cue over and over: '
              'say it once, then help your dog get it right.',
        ],
      ),
    ],
  ),
  'loose-lead': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'Walking nicely on a loose lead',
    summary: 'Teach your dog that a slack lead is what moves you forward.',
    intro: 'Dogs pull because it works: pulling gets them to the next smell faster. The fix is to make a '
        'slack lead the only thing that moves the walk forward. It takes patience and consistency more '
        'than strength.',
    sections: [
      GuideSection(
        heading: 'Before you start',
        bullets: [
          'Use a comfortable flat collar or a well-fitted harness. Avoid choke, prong and shock collars, '
              'which work by causing pain.',
          'Carry small, soft treats your dog loves.',
          'Practise first somewhere quiet and boring.',
        ],
      ),
      GuideSection(
        heading: 'Stop and go',
        paragraphs: [
          'The moment the lead goes tight, stand still and wait. When your dog looks back or steps towards '
              'you and the lead slackens, praise and walk on.',
          'Your dog learns that pulling stops the walk and a loose lead starts it.',
        ],
      ),
      GuideSection(
        heading: 'Reward the right place',
        paragraphs: [
          'Feed treats by your leg, on the side you want your dog to walk. Reward often at first, every few '
              'steps, then gradually stretch the gaps.',
          'Changing direction now and then keeps your dog paying attention to where you are.',
        ],
      ),
      GuideSection(
        heading: 'Be realistic',
        paragraphs: [
          'Everyone who walks the dog needs to follow the same rules, or pulling will keep paying off. Let '
              'your dog have sniffing time too: a walk is their chance to read the news.',
          'On days when you have no time to train, a front-clip harness can make pulling less rewarding '
              'while you keep working on it.',
        ],
      ),
    ],
  ),

  // -------------------------------------------------------------------
  // Nutrition
  // -------------------------------------------------------------------
  'feeding': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'How much and how often to feed',
    summary: 'Portions, meal times and keeping a healthy weight.',
    intro: 'There is no single right amount of food for every dog. Age, size, activity and the food itself '
        'all matter. Start from the guide on the packet of a complete dog food, then adjust to the dog in '
        'front of you.',
    sections: [
      GuideSection(
        heading: 'How often',
        bullets: [
          'Young puppies: three to four small meals a day.',
          'From about six months: two meals a day.',
          'Adult dogs: usually two meals a day, at regular times.',
        ],
        after: [
          'Large, deep-chested breeds do better with two or more smaller meals than one big one, and with '
              'a rest before and after eating.',
        ],
      ),
      GuideSection(
        heading: 'How much',
        paragraphs: [
          'Weigh the food rather than guessing: a kitchen scale is more accurate than a scoop. Choose a '
              'food labelled "complete" for your dog\'s life stage, and use its feeding guide for their target '
              'weight as a starting point.',
          'Treats count. Keep them to about a tenth of the day\'s calories, and make meals a little smaller '
              'on heavy training days.',
        ],
      ),
      GuideSection(
        heading: 'Check the body, not just the bowl',
        paragraphs: [
          'You should be able to feel your dog\'s ribs easily under a thin layer of fat, and see a waist '
              'from above. If the ribs are hard to find, cut portions by about a tenth and check again in two '
              'weeks. If they are very prominent, feed a little more.',
        ],
      ),
      GuideSection(
        heading: 'Good habits',
        paragraphs: [
          'Change foods gradually over about a week to avoid an upset stomach, and keep fresh water '
              'available at all times.',
          'A sudden change in appetite or weight, in either direction, is worth a call to your vet, who '
              'can also help you set a target weight.',
        ],
      ),
    ],
  ),
  'unsafe-foods': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'Foods your dog should never eat',
    summary: 'Common kitchen foods that are dangerous for dogs.',
    intro: 'Some everyday human foods are harmful to dogs, even in small amounts. It helps to know the '
        'main ones, keep them out of reach and know what to do if something is eaten.',
    sections: [
      GuideSection(
        heading: 'Keep these away from your dog',
        bullets: [
          'Chocolate, and anything with cocoa or caffeine. Dark chocolate is the most dangerous.',
          'Grapes, raisins, sultanas and currants, which can cause kidney failure.',
          'Onions, garlic, leeks and chives, raw or cooked.',
          'Xylitol (also labelled birch sugar), a sweetener in some sugar-free gum, sweets and peanut '
              'butters.',
          'Macadamia nuts.',
          'Alcohol and raw bread dough.',
          'Cooked bones, which can splinter.',
        ],
      ),
      GuideSection(
        heading: 'Risky rather than poisonous',
        paragraphs: [
          'Very fatty scraps can trigger a painful stomach upset or pancreatitis, and many dogs do not '
              'digest milk well. Corn on the cob is a common cause of a blocked gut, and very salty snacks are '
              'best avoided.',
        ],
      ),
      GuideSection(
        heading: 'If your dog eats something harmful',
        paragraphs: [
          'Call your vet or an animal poison helpline straight away, even if your dog seems fine: some '
              'poisons take hours or days to show.',
          'Have the packet to hand and tell them what was eaten, how much and when. Do not try to make '
              'your dog sick unless a vet tells you to.',
        ],
      ),
      GuideSection(
        heading: 'Everyday prevention',
        paragraphs: [
          'Keep bins closed and bags off the floor, check the labels of sugar-free products, and let guests '
              'and children know not to share food from their plates.',
        ],
      ),
    ],
  ),

  // -------------------------------------------------------------------
  // Health and grooming
  // -------------------------------------------------------------------
  'grooming': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'A simple grooming routine',
    summary: 'Coat, teeth, nails and ears in a few minutes a week.',
    intro: 'Regular grooming keeps your dog comfortable and lets you spot small problems early. Keep it '
        'short and pleasant, with treats, so your dog learns to enjoy being handled.',
    sections: [
      GuideSection(
        heading: 'Coat',
        paragraphs: [
          'Brush short coats about once a week, and long or curly coats every day or two to prevent mats. '
              'Bathe only when your dog is dirty or smelly, with a shampoo made for dogs: human shampoo can '
              'irritate their skin.',
          'While you brush, run your hands over the body and check for lumps, sore patches, fleas and ticks.',
        ],
      ),
      GuideSection(
        heading: 'Teeth',
        paragraphs: [
          'Brushing is the most effective way to prevent dental disease. Aim for every day, or at least '
              'several times a week, with a toothpaste made for dogs. Never use human toothpaste, which is not '
              'safe for dogs to swallow.',
          'Start by letting your dog lick the paste, then brush a few teeth, and build up from there.',
        ],
      ),
      GuideSection(
        heading: 'Nails and paws',
        paragraphs: [
          'Nails that click on hard floors are usually too long. Trim a little at a time to avoid the '
              'quick, the sensitive part inside the nail, or ask your vet or a groomer to show you how.',
          'Check between the toes for cuts, grass seeds and matted fur.',
        ],
      ),
      GuideSection(
        heading: 'Ears and eyes',
        paragraphs: [
          'Look inside the ears once a week. A healthy ear is pale pink and does not smell. Redness, a '
              'strong smell, dark discharge or a lot of head shaking need a vet visit. Do not push cotton buds '
              'into the ear canal.',
          'Wipe around the eyes with damp cotton wool when needed.',
        ],
      ),
      GuideSection(
        heading: 'Make it easy',
        bullets: [
          'Pick a calm moment, such as after a walk.',
          'Do a little and often rather than one long session.',
          'Stop before your dog gets fed up, and reward generously.',
        ],
      ),
    ],
  ),
  'call-the-vet': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'Knowing when to call the vet',
    summary: 'Signs that need urgent help, and signs to book a visit for.',
    intro: 'You know your dog\'s normal better than anyone. When something changes, it can be hard to tell '
        'whether to wait or to call. When in doubt, phone your vet practice: they would rather hear from '
        'you early.',
    sections: [
      GuideSection(
        heading: 'Call straight away',
        bullets: [
          'Difficulty breathing, or gums that are pale, blue or grey.',
          'Collapse, a seizure, or suddenly being unable to stand.',
          'A swollen, tight belly, or retching without bringing anything up.',
          'Repeated vomiting or diarrhoea, or any with blood in it.',
          'Straining to pass urine, or passing none.',
          'Heavy bleeding, a road accident or a bad fall, even if your dog seems fine.',
          'You think your dog has eaten something poisonous.',
          'Signs of heatstroke: heavy panting, drooling and weakness after heat or exercise.',
        ],
      ),
      GuideSection(
        heading: 'Book a visit soon',
        bullets: [
          'Eating or drinking much more or less than usual for more than a day.',
          'Limping that lasts more than a day or two.',
          'Scratching, head shaking or a smelly ear.',
          'A new lump, or one that is growing.',
          'Weight change, bad breath or a change in behaviour you cannot explain.',
        ],
      ),
      GuideSection(
        heading: 'Be prepared',
        paragraphs: [
          'Save your vet\'s number and the nearest out-of-hours clinic in your phone. Keep a note of your '
              'dog\'s weight, medicines and vaccination dates so you can answer questions quickly.',
          'Never give human painkillers such as ibuprofen or paracetamol: they can be dangerous for dogs.',
        ],
      ),
    ],
  ),

  // -------------------------------------------------------------------
  // Senior care
  // -------------------------------------------------------------------
  'senior-comfort': GuideText(
    author: petCompanionTeam,
    updatedAt: firstWritten,
    title: 'Keeping an older dog comfortable',
    summary: 'Small changes that make the senior years easier.',
    intro: 'Dogs are generally thought of as senior from around seven or eight years old, earlier for '
        'giant breeds and later for small ones. Ageing is not an illness, but older dogs do need a few '
        'adjustments.',
    sections: [
      GuideSection(
        heading: 'Movement',
        paragraphs: [
          'Keep exercising, but swap long hikes for shorter, gentler walks more often, and let your dog '
              'set the pace.',
          'Stiffness after rest, reluctance on the stairs or trouble jumping into the car are often signs '
              'of arthritis, which your vet can treat. Do not write them off as just old age.',
        ],
      ),
      GuideSection(
        heading: 'Around the home',
        bullets: [
          'A thick, supportive bed away from draughts.',
          'Rugs or mats on slippery floors.',
          'A ramp or step for the car and the sofa.',
          'Food and water bowls that are easy to reach.',
        ],
      ),
      GuideSection(
        heading: 'Food and weight',
        paragraphs: [
          'Extra weight is hard on old joints, so keep your dog lean, and ask your vet whether a senior '
              'diet would suit them. Keep up dental care: sore teeth are a common reason older dogs eat less.',
        ],
      ),
      GuideSection(
        heading: 'Health checks',
        paragraphs: [
          'Many vets recommend a check-up every six months for senior dogs. Between visits, watch for '
              'changes in thirst, appetite, weight, sight, hearing or toilet habits, and for new lumps.',
          'Confusion, restlessness at night or getting lost in familiar rooms are worth mentioning too.',
        ],
      ),
      GuideSection(
        heading: 'Mind and mood',
        paragraphs: [
          'Older dogs still love to learn. Sniffing walks, food puzzles and gentle training keep the brain '
              'busy. Keep routines steady and be patient: your company is what they want most.',
        ],
      ),
    ],
  ),
};
