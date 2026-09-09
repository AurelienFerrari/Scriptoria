import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/room_provider.dart';

/// Pousse [page] en lui conservant le [RoomProvider] de la room courante.
///
/// Les providers sont portés par l'arbre de widgets, et `RoomShell` fournit le
/// sien **sous** le Navigator. Une route poussée devient donc un frère du
/// shell et non son descendant : elle sort du provider, et tout écran qui le
/// lit échoue sur un `ProviderNotFoundException`. Le réinjecter explicitement
/// est la façon prévue de franchir cette frontière.
///
/// `AuthProvider`, lui, est monté au-dessus du `MaterialApp` dans `main.dart` :
/// il traverse les routes sans rien faire de particulier.
Future<T?> pushRoomRoute<T>(BuildContext context, Widget page) {
  final room = context.read<RoomProvider>();

  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(
      builder: (_) => ChangeNotifierProvider<RoomProvider>.value(
        value: room,
        child: page,
      ),
    ),
  );
}
