import 'package:flutter/material.dart';

/// Observateur de navigation partagé, enregistré sur le MaterialApp
/// (voir main.dart). Permet à une page (via le mixin RouteAware) de
/// recharger ses données quand on revient dessus après avoir dépilé une
/// route poussée par-dessus (ex: HomePage après avoir créé/rejoint/quitté
/// une room).
final routeObserver = RouteObserver<PageRoute<dynamic>>();
