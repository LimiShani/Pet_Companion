import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/pet.dart';
import 'add_pet/add_pet_screen.dart';
import 'pets_routes.dart';
import 'widgets/pets_widgets.dart';

/// Opens the add-a-pet flow, full screen (no bottom bar). Returns the new
/// pet, which is already saved and selected, or `null` when the owner left
/// before step 1 was saved.
Future<Pet?> openAddPet(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) return router.push<Pet>(PetsRoutes.addPet);
  // A page shown on its own, outside the app's router.
  return pushPetsPage<Pet>(context, const AddPetScreen());
}
