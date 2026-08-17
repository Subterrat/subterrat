import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const String _placeholderApiKey = 'YOUR_MAPS_API_KEY';
const String _scriptElementId = 'subterrat-google-maps-script';

/// Injects the Google Maps JavaScript SDK `<script>` tag at runtime instead
/// of hardcoding the API key in web/index.html — the key comes from
/// GOOGLE_MAPS_API_KEY in .env (see .env.example) via flutter_dotenv. Must
/// complete before any GoogleMap widget builds.
Future<void> loadGoogleMapsScript(String apiKey) {
  if (apiKey.isEmpty || apiKey == _placeholderApiKey) {
    return Future<void>.value();
  }
  if (web.document.getElementById(_scriptElementId) != null) {
    return Future<void>.value();
  }

  final completer = Completer<void>();
  final script = web.HTMLScriptElement()
    ..id = _scriptElementId
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey'
    ..type = 'application/javascript'
    ..async = true;
  script.addEventListener(
    'load',
    ((web.Event event) => completer.complete()).toJS,
  );
  script.addEventListener(
    'error',
    ((web.Event event) => completer.completeError(
          StateError('Failed to load the Google Maps JavaScript SDK'),
        )).toJS,
  );
  web.document.head!.append(script);
  return completer.future;
}
