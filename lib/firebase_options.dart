// Firebase 프로젝트 "finance-note-f37c8" 연결 정보 (android/app/google-services.json과 같은 값).
// 안드로이드에서만 실제 모드로 켜지고, 웹 미리보기는 체험 모드로 켜져요.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      _ => null,
    };
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyDBuJ3bbFZqOcbxDQ89-vVsnaXWBqK2VAw',
    appId: '1:339726110077:android:7902082928e42f43385014',
    messagingSenderId: '339726110077',
    projectId: 'finance-note-f37c8',
    storageBucket: 'finance-note-f37c8.firebasestorage.app',
  );

  /// 구글 로그인에 쓰는 웹 클라이언트 ID (google-services.json의 client_type 3).
  static const googleServerClientId =
      '339726110077-nlu2h4dreqrvroilbhbvk0ffff3k1tif.apps.googleusercontent.com';
}
