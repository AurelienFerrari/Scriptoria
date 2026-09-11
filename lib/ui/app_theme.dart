import 'package:flutter/material.dart';

/// Couleur de fond des écrans de l'application.
const Color appBackground = Color(0xFF161622);

/// Thème de l'application.
///
/// Sorti de `main.dart` pour être partagé avec les harnais de test : un écran
/// monté sans lui y est rendu dans le thème clair par défaut de Flutter, que
/// l'application n'affiche jamais. Les captures de l'audit en paysage l'ont
/// montré — l'accueil y apparaissait blanc.
///
/// Le fond par défaut est aligné sur [appBackground], que peignent déjà
/// presque tous les écrans. Sans cela, ceux qui s'en remettent au thème
/// prenaient un gris voisin, et les bandes latérales de `appFrame` le
/// trahissaient téléphone couché.
final ThemeData appTheme = ThemeData.dark().copyWith(
  scaffoldBackgroundColor: appBackground,
);
