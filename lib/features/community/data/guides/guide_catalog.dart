import 'package:flutter/material.dart';

import '../audience.dart';
import '../guides_repository.dart';

// The language-neutral part of the guides library: the categories, and one
// record per guide (its id, category and animal). The text of each guide
// lives per language in `guides_en.dart` and `guides_he.dart`, keyed by the
// same id.

const guideCategories = <GuideCategory>[
  GuideCategory(id: 'start', name: 'Getting started', icon: Icons.pets_rounded),
  GuideCategory(id: 'home', name: 'Home and cleaning', icon: Icons.cleaning_services_rounded),
  GuideCategory(id: 'behaviour', name: 'Training and behaviour', icon: Icons.school_rounded),
  GuideCategory(id: 'nutrition', name: 'Nutrition', icon: Icons.restaurant_rounded),
  GuideCategory(id: 'health', name: 'Health and grooming', icon: Icons.medical_services_rounded),
  GuideCategory(id: 'senior', name: 'Senior care', icon: Icons.favorite_rounded),
];

/// Every guide, in the order the library lists them: by category, dogs
/// before cats.
const guideRecords = <GuideRecord>[
  // Getting started
  GuideRecord(id: 'first-week', categoryId: 'start', audience: Audience.dogs),
  GuideRecord(id: 'house-training', categoryId: 'start', audience: Audience.dogs),
  GuideRecord(id: 'cat-first-week', categoryId: 'start', audience: Audience.cats),
  GuideRecord(id: 'second-cat', categoryId: 'start', audience: Audience.cats),

  // Home and cleaning
  GuideRecord(id: 'litter-setup', categoryId: 'home', audience: Audience.cats),
  GuideRecord(id: 'litter-count', categoryId: 'home', audience: Audience.cats),
  GuideRecord(id: 'litter-smell', categoryId: 'home', audience: Audience.cats),

  // Training and behaviour
  GuideRecord(id: 'sit-stay-come', categoryId: 'behaviour', audience: Audience.dogs),
  GuideRecord(id: 'loose-lead', categoryId: 'behaviour', audience: Audience.dogs),
  GuideRecord(id: 'indoor-play', categoryId: 'behaviour', audience: Audience.cats),
  GuideRecord(id: 'cat-nights', categoryId: 'behaviour', audience: Audience.cats),
  GuideRecord(id: 'scratch-bite', categoryId: 'behaviour', audience: Audience.cats),

  // Nutrition
  GuideRecord(id: 'feeding', categoryId: 'nutrition', audience: Audience.dogs),
  GuideRecord(id: 'unsafe-foods', categoryId: 'nutrition', audience: Audience.dogs),

  // Health and grooming
  GuideRecord(id: 'grooming', categoryId: 'health', audience: Audience.dogs),
  GuideRecord(id: 'call-the-vet', categoryId: 'health', audience: Audience.dogs),
  GuideRecord(id: 'cat-call-vet', categoryId: 'health', audience: Audience.cats),

  // Senior care
  GuideRecord(id: 'senior-comfort', categoryId: 'senior', audience: Audience.dogs),
];
