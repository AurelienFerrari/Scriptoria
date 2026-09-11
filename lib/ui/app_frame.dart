import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Cadre commun à tous les écrans, branché sur `MaterialApp.builder`.
///
/// Téléphone couché, Android place l'encoche de la caméra d'un côté et les
/// boutons de navigation de l'autre, par-dessus l'app. Ce cadre écarte tout le
/// contenu de ces deux zones, **une fois pour toutes** : sans lui, chaque écran
/// devait penser à sa propre `SafeArea`, et l'audit en paysage en a trouvé
/// plusieurs qui l'avaient oubliée — barre de navigation de la room comprise.
/// Un écran ajouté demain en profite sans rien faire.
///
/// Seuls les côtés sont traités. Le haut et le bas restent à la charge de
/// chaque écran, comme avant : l'AppBar gère la barre d'état, et les écrans
/// qui ont des boutons en bas ont déjà leur `SafeArea`. En portrait, les
/// marges latérales valent zéro et ce cadre ne change rien.
///
/// Les bandes ainsi libérées prennent la couleur de fond des écrans, pour que
/// l'app paraisse toujours aller jusqu'au bord.
Widget appFrame(BuildContext context, Widget? child) {
  return ColoredBox(
    color: appBackground,
    child: SafeArea(
      top: false,
      bottom: false,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}
