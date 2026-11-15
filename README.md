# PuTTY Mobile

Android/iOS에서 동작하는 SSH 터미널 클라이언트입니다.
- 접속 정보 저장 (비밀번호 / 개인키 인증)
- 터미널 에뮬레이션 (xterm, 색상, 커서 이동, 화면 크기 동기화)
- 모바일 키보드에 없는 키 바 (Esc, Tab, Ctrl+C/D/Z/L, 방향키, `| ~ / -`)
- 접속 정보는 Android Keystore / iOS Keychain에 암호화 저장

## 1. 빌드 환경 준비

Flutter SDK를 설치하세요: https://docs.flutter.dev/get-started/install
그 다음 `flutter doctor`로 Android Studio(또는 Xcode)가 준비됐는지 확인합니다.

## 2. 프로젝트 생성

```bash
flutter create --org com.example --project-name putty_mobile putty_mobile
cd putty_mobile
```

생성된 `pubspec.yaml`과 `lib/` 폴더를 이 프로젝트의 파일로 교체합니다.
(`android/`, `ios/` 폴더는 그대로 두세요.)

```bash
flutter pub get
```

## 3. 플랫폼 설정

**Android** — `android/app/src/main/AndroidManifest.xml`에 인터넷 권한 추가 (release 빌드에 필요):

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

`android/app/build.gradle(.kts)`에서 `minSdk`를 23 이상으로 설정 (보안 저장소 요구사항):

```gradle
minSdk = 23
```

**iOS** — Xcode에서 Signing 설정 후 실행하면 됩니다. 로컬 네트워크 접근 허용 팝업이 뜨면 허용하세요.

## 4. 실행 / 빌드

```bash
flutter run                      # 연결된 기기/에뮬레이터에 실행
flutter build apk --release      # Android APK 생성 -> build/app/outputs/flutter-apk/
```

## 알려진 제한 사항

- **호스트 키 검증 미구현**: 현재 `onVerifyHostKey`가 모든 서버 키를 수락합니다. 공용 Wi-Fi에서 중간자 공격에 취약할 수 있으므로, 실사용 전에 첫 접속 지문 저장 및 불일치 경고를 추가하는 것을 권장합니다.
- PuTTY의 포트 포워딩, X11, SFTP 파일 전송, 시리얼 연결 기능은 포함되어 있지 않습니다.
- 개인키는 PEM 텍스트(`-----BEGIN ... PRIVATE KEY-----`)를 붙여넣는 방식입니다. PuTTY의 `.ppk` 파일은 OpenSSH 형식으로 변환해야 합니다 (`puttygen`에서 "Conversions → Export OpenSSH key").
- 이 코드는 빌드 환경 제약으로 실제 컴파일/실행 테스트를 하지 못했습니다. 패키지 버전 충돌이 나면 `flutter pub add dartssh2 xterm flutter_secure_storage`로 최신 버전을 받아 주세요. API가 바뀌었다면 `dartssh2`/`xterm` 문서를 기준으로 수정이 필요할 수 있습니다.
