// Generated for project swipeat-4adfe - verify values
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
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
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDheGMENWh6kT1i7zif5LGa9aJ6o90YTzM',
    appId: '1:911457804393:web:5a96ee945a8fd2bf7802f8',
    messagingSenderId: '911457804393',
    projectId: 'swipeat-4adfe',
    authDomain: 'swipeat-4adfe.firebaseapp.com',
    storageBucket: 'swipeat-4adfe.firebasestorage.app',
    measurementId: 'G-MQ4JTNZM32',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDQmqfjQvr5Jagtw039quMvfKPI5h47aAI',
    appId: '1:911457804393:android:85a7ef2d4a49e0817802f8',
    messagingSenderId: '911457804393',
    projectId: 'swipeat-4adfe',
    storageBucket: 'swipeat-4adfe.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDq3nuaA2KQe-f--9cZ8rvzbkwSDx5qz30',
    appId: '1:911457804393:ios:d2946225da54b50b7802f8',
    messagingSenderId: '911457804393',
    projectId: 'swipeat-4adfe',
    storageBucket: 'swipeat-4adfe.firebasestorage.app',
    iosClientId: '911457804393-mggm0juaovem4gqus0cdnamumkt1sl84.apps.googleusercontent.com',
    iosBundleId: 'com.example.sparkupApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: 'swipeat-4adfe',
    storageBucket: 'swipeat-4adfe.firebasestorage.app',
    androidClientId: '',
    iosClientId: '',
    iosBundleId: 'com.example.sparkupApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: 'swipeat-4adfe',
    authDomain: 'swipeat-4adfe.firebaseapp.com',
    storageBucket: 'swipeat-4adfe.firebasestorage.app',
    measurementId: '',
  );

}