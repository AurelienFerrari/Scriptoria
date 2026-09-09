import 'dart:async';
import 'dart:io';

/// Fait répondre toute requête d'image par un PNG transparent de 1×1.
///
/// `TestWidgetsFlutterBinding` renvoie un code 400 à toute requête HTTP réelle,
/// si bien qu'un simple `Image.network` fait échouer le test qui l'affiche.
/// Plutôt que de bannir les images du réseau des tests — et donc de ne jamais
/// couvrir les écrans qui en montrent — on intercepte la couche HTTP.
///
/// À installer dans un `setUpAll` :
/// ```dart
/// setUpAll(() => HttpOverrides.global = StubImageHttpOverrides());
/// ```
class StubImageHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _StubHttpClient();
}

/// PNG valide de 1×1 pixel transparent : le décodeur d'images doit obtenir
/// des octets qu'il sait lire, un tableau vide le ferait échouer autrement.
const List<int> _transparentPixelPng = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

// Les trois classes qui suivent n'implémentent que ce que `NetworkImage`
// appelle réellement. `noSuchMethod` couvre le reste de l'interface : tout
// autre membre lève, ce qui signalerait franchement un usage non prévu au lieu
// de renvoyer un résultat silencieusement faux.

class _StubHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _StubHttpClientRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non simulé');
}

class _StubHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _StubHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _StubHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non simulé');
}

class _StubHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non simulé');
}

class _StubHttpClientResponse implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _transparentPixelPng.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_transparentPixelPng).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non simulé');
}
