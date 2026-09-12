import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/scheduler.dart';

/// Mesure la fluidité d'un écran, et la publie sur Firebase Performance.
///
/// Firebase instrumente automatiquement les écrans natifs, mais pas ceux de
/// Flutter : c'est donc à l'application de compter ses images. [FrameWatch]
/// écoute le temps de chaque image tant que l'écran est ouvert, puis publie
/// sur une trace nommée le nombre d'images affichées, celles qui ont dépassé
/// le budget des 60 images par seconde, et celles qui ont gelé l'écran.
///
/// Les deux seuils sont ceux de Firebase : une image est lente au-delà de
/// 16 ms — le temps dont on dispose pour tenir 60 fps —, et gelée au-delà de
/// 700 ms.
///
/// Deux réserves sur la lecture des chiffres. La collecte est désactivée en
/// débogage (voir `main.dart`), donc rien ne remonte au tableau de bord
/// depuis un build de débogage. Et les mesures d'un tel build ne voudraient
/// de toute façon pas dire grand-chose : sans compilation anticipée ni
/// assertions désactivées, l'application est bien plus lente qu'en vrai. Pour
/// juger de la fluidité, il faut lancer en mode profil.
///
/// Une mesure ne doit jamais gêner ce qu'elle mesure : si Firebase n'est pas
/// configuré, le comptage continue en local et l'écran n'en sait rien.
class FrameWatch {
  /// Budget d'une image à 60 images par seconde.
  static const Duration smoothFrameBudget = Duration(milliseconds: 16);

  /// Au-delà, Firebase parle d'image gelée.
  static const Duration frozenFrameBudget = Duration(milliseconds: 700);

  /// Nom de la trace, tel qu'il apparaît sur le tableau de bord.
  final String name;

  Trace? _trace;
  TimingsCallback? _callback;
  int _total = 0;
  int _slow = 0;
  int _frozen = 0;

  FrameWatch(this.name);

  int get totalFrames => _total;
  int get slowFrames => _slow;
  int get frozenFrames => _frozen;

  /// Images tenues dans le budget, pour mille affichées.
  int get smoothPerMille =>
      _total == 0 ? 1000 : ((_total - _slow) * 1000 / _total).round();

  Future<void> start() async {
    if (_callback != null) return;

    _callback = _record;
    SchedulerBinding.instance.addTimingsCallback(_callback!);

    try {
      final trace = FirebasePerformance.instance.newTrace(name);
      await trace.start();
      _trace = trace;
    } catch (e) {
      // Projet Firebase non configuré : le comptage reste local.
      _trace = null;
    }
  }

  void _record(List<FrameTiming> timings) {
    for (final timing in timings) {
      _total++;
      // `totalSpan` couvre la construction et le rendu : c'est ce que
      // l'utilisateur attend réellement avant de voir l'image.
      final span = timing.totalSpan;
      if (span >= frozenFrameBudget) {
        _frozen++;
        _slow++;
      } else if (span > smoothFrameBudget) {
        _slow++;
      }
    }
  }

  Future<void> stop() async {
    final callback = _callback;
    if (callback != null) {
      SchedulerBinding.instance.removeTimingsCallback(callback);
      _callback = null;
    }

    final trace = _trace;
    _trace = null;
    if (trace == null) return;

    try {
      trace.setMetric('frames_total', _total);
      trace.setMetric('frames_slow', _slow);
      trace.setMetric('frames_frozen', _frozen);
      // Publiée telle quelle pour se lire sans calcul sur le tableau de bord.
      trace.setMetric('smooth_per_mille', smoothPerMille);
      await trace.stop();
    } catch (e) {
      // Une trace qui ne part pas ne doit pas gêner l'écran.
    }
  }
}
