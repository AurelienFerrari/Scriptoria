import 'package:flutter/widgets.dart';

/// Hauteur sous laquelle Material 3 classe une fenêtre comme « compacte » en
/// hauteur.
const double _compactHeight = 480;

/// Vrai pour un téléphone couché : une fenêtre plus large que haute, et dont
/// la hauteur est « compacte » au sens des classes de taille de Material 3.
///
/// C'est la hauteur qui manque, pas l'orientation qui compte. Une tablette
/// couchée garde largement de quoi empiler ses blocs et n'a aucune raison de
/// changer de disposition ; un téléphone couché n'a plus que 411 dp. Les
/// écrans qui en souffrent — les outils, le dé, l'accueil de la room —
/// passent alors en deux colonnes.
bool isCompactLandscape(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width > size.height && size.height < _compactHeight;
}
