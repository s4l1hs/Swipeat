import json
from pathlib import Path
import sys
import os

SRC = Path(__file__).resolve().parent
# Prefer environment variable GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_CREDENTIALS.
env_cred = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS') or os.environ.get('FIREBASE_CREDENTIALS')
if env_cred:
  INPUT = Path(env_cred)
else:
  # fallback: find any *-firebase-adminsdk-*.json in repo root
  candidates = list(SRC.glob('*-firebase-adminsdk-*.json'))
  INPUT = candidates[0] if candidates else (SRC / "swipeat-4adfe-firebase-adminsdk-fbsvc-c0027804f2.json")

OUT = SRC / "zinc_app" / "lib" / "firebase_options.dart"

if not INPUT.exists():
  print(f"Service account JSON not found. Looked for env var or files like '*-firebase-adminsdk-*.json'. Tried: {INPUT}")
  sys.exit(1)

# Read file content then parse JSON (json.load expects a file-like object, not a Path)
data = json.loads(INPUT.read_text(encoding="utf-8"))

def g(k): return data.get(k) or ""

content = f"""// Generated from zinc-fb606-firebase-adminsdk-fbsvc-23e3c37a6d.json - verify values
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {{
  static FirebaseOptions get currentPlatform {{
    if (kIsWeb) {{
      return web;
    }}
    switch (defaultTargetPlatform) {{
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }}
  }}

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '{g('web_apiKey')}',
    appId: '{g('web_appId')}',
    messagingSenderId: '{g('messagingSenderId')}',
    projectId: '{g('projectId')}',
    authDomain: '{g('authDomain')}',
    storageBucket: '{g('storageBucket')}',
    measurementId: '{g('measurementId')}',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '{g('android_apiKey')}',
    appId: '{g('android_appId')}',
    messagingSenderId: '{g('messagingSenderId')}',
    projectId: '{g('projectId')}',
    storageBucket: '{g('storageBucket')}',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '{g('ios_apiKey')}',
    appId: '{g('ios_appId')}',
    messagingSenderId: '{g('messagingSenderId')}',
    projectId: '{g('projectId')}',
    storageBucket: '{g('storageBucket')}',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: '{g('macos_apiKey')}',
    appId: '{g('macos_appId')}',
    messagingSenderId: '{g('messagingSenderId')}',
    projectId: '{g('projectId')}',
    storageBucket: '{g('storageBucket')}',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: '{g('windows_apiKey')}',
    appId: '{g('windows_appId')}',
    messagingSenderId: '{g('messagingSenderId')}',
    projectId: '{g('projectId')}',
    storageBucket: '{g('storageBucket')}',
  );
}}
"""

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(content, encoding="utf-8")

print("Yazıldı:", OUT)