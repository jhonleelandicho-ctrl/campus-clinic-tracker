import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyDXQjvLHJUOmzBNau87N9ktpg3QmRbPSVI",
    appId: '1:130930072760:web:ae7b5a88bacef60e57284d',
    messagingSenderId: '130930072760',
    projectId: 'campus-clinic-tracker',
    authDomain: 'campus-clinic-tracker.firebaseapp.com',
    storageBucket: 'campus-clinic-tracker.firebasestorage.app',
  );
}