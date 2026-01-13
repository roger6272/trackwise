import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyBWBOgzaw4y08V_33_SErjZuW7NOKXhqX8",
            authDomain: "trackwise-ibs6hd.firebaseapp.com",
            projectId: "trackwise-ibs6hd",
            storageBucket: "trackwise-ibs6hd.firebasestorage.app",
            messagingSenderId: "599586251579",
            appId: "1:599586251579:web:abdedf38abb692a4368d1e"));
  } else {
    await Firebase.initializeApp();
  }
}
