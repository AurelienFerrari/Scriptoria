import 'package:flutter/material.dart';

const Color _primaryColor = Color(0xFF6FE3E1);

/// Texte long replié à une ligne, dépliable par « Voir plus ».
///
/// Sans repli, un texte de trente lignes fait une carte haute de trois écrans
/// et rend la liste qui le contient impossible à parcourir. Le repli laisse
/// voir de quoi il s'agit ; qui veut lire déplie.
///
/// Partagé par le fil de la room et la frise : les deux affichent des textes
/// écrits par le MJ, dont rien ne borne la longueur.
class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle style;

  /// Style du fil de la room, repris par défaut pour que les deux surfaces se
  /// ressemblent.
  static const TextStyle defaultStyle = TextStyle(
    color: Colors.white,
    fontSize: 15,
    height: 1.45,
  );

  const ExpandableText({
    Key? key,
    required this.text,
    this.style = defaultStyle,
  }) : super(key: key);

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Le bouton n'apparaît que si le texte déborde réellement : un texte
        // d'une ligne n'a pas à proposer « Voir plus ».
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: widget.style,
              maxLines: _expanded ? null : 1,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
            if (overflows)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _expanded ? 'Voir moins' : 'Voir plus',
                    style: const TextStyle(
                      color: _primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
