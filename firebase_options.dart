import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCysPfdcM2faaQkE0HwPrh9dE9heTh-y3Q',
    appId: '1:327878014583:web:YOUR_WEB_APP_ID',
    messagingSenderId: '327878014583',
    projectId: 'garzon-leavesofthephilippines',
    authDomain: 'garzon-leavesofthephilippines.firebaseapp.com',
    databaseURL:
        'https://garzon-leavesofthephilippines-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'garzon-leavesofthephilippines.firebasestorage.app',
    measurementId: 'G-YOUR_MEASUREMENT_ID',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCysPfdcM2faaQkE0HwPrh9dE9heTh-y3Q',
    appId: '1:327878014583:android:ecda6de7dc2ab1c01a7872',
    messagingSenderId: '327878014583',
    projectId: 'garzon-leavesofthephilippines',
    databaseURL:
        'https://garzon-leavesofthephilippines-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'garzon-leavesofthephilippines.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCysPfdcM2faaQkE0HwPrh9dE9heTh-y3Q',
    appId: '1:327878014583:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '327878014583',
    projectId: 'garzon-leavesofthephilippines',
    databaseURL:
        'https://garzon-leavesofthephilippines-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'garzon-leavesofthephilippines.firebasestorage.app',
    iosBundleId: 'leaves.of.the.philippine.tree',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCysPfdcM2faaQkE0HwPrh9dE9heTh-y3Q',
    appId: '1:327878014583:macos:YOUR_MACOS_APP_ID',
    messagingSenderId: '327878014583',
    projectId: 'garzon-leavesofthephilippines',
    databaseURL:
        'https://garzon-leavesofthephilippines-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'garzon-leavesofthephilippines.firebasestorage.app',
    iosBundleId: 'leaves.of.the.philippine.tree',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCysPfdcM2faaQkE0HwPrh9dE9heTh-y3Q',
    appId: '1:327878014583:windows:YOUR_WINDOWS_APP_ID',
    messagingSenderId: '327878014583',
    projectId: 'garzon-leavesofthephilippines',
    databaseURL:
        'https://garzon-leavesofthephilippines-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'garzon-leavesofthephilippines.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyCysPfdcM2faaQkE0HwPrh9dE9heTh-y3Q',
    appId: '1:327878014583:linux:YOUR_LINUX_APP_ID',
    messagingSenderId: '327878014583',
    projectId: 'garzon-leavesofthephilippines',
    databaseURL:
        'https://garzon-leavesofthephilippines-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'garzon-leavesofthephilippines.firebasestorage.app',
  );
}
