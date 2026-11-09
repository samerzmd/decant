// CI stand-in for lib/firebase_options.dart, which is git-ignored because it
// holds a real Firebase project's config. CI copies this file into place so
// the app compiles for `flutter analyze`; it is never used to run the app.
// To build Decant yourself, generate the real file with `flutterfire configure`
// (see the Firebase section of the README).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Placeholder Firebase config. Run `flutterfire configure` to generate '
        'lib/firebase_options.dart.',
      );
}
