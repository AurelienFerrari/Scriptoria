/// Nature d'un changement reçu en temps réel.
enum RowChangeKind {
  /// Une ligne vient d'être insérée ; [RowChange.record] la contient.
  inserted,

  /// Une ligne vient d'être modifiée ; [RowChange.record] contient sa nouvelle
  /// version, telle que la RLS permet à l'abonné de la lire.
  updated,

  /// Une ligne vient d'être supprimée. [RowChange.record] ne contient que son
  /// `id` : Realtime n'en diffuse pas davantage, et c'est voulu — voir la
  /// migration `room_messages_realtime`.
  deleted,

  /// L'abonnement vient de s'établir, ou de se rétablir après une coupure.
  ///
  /// Realtime ne rejoue pas ce qui s'est passé entretemps : un écran qui
  /// reçoit ce signal doit se recharger depuis la base, sans quoi les
  /// messages envoyés pendant la coupure n'apparaîtraient jamais.
  resubscribed,
}

/// Un changement sur une table d'une room, tel que l'écran en a besoin.
///
/// Tient les écrans à l'écart des types de `realtime_client` : ils ne
/// connaissent que ce flux, que les tests peuvent simuler sans réseau.
class RowChange {
  final RowChangeKind kind;
  final Map<String, dynamic> record;

  const RowChange(this.kind, [this.record = const {}]);
}
