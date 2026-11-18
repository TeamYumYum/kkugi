# 꾸기 iOS

꾸기 Android 앱을 SwiftUI로 이식하고 있다. 심사용 계정 로그인, 온보딩, 식사, 운동, 코칭, 성장 화면을 구현 중이다. 전체 기능과 화면 비교는 에픽 S15P31E101-714에서 추적한다.

## 인증 설정

로컬 Xcode 빌드 설정 또는 비공개 빌드 환경에서 다음 값을 지정한다. 공개 저장소와 테스트 첨부물에는 실제 계정이나 설정값을 저장하지 않는다.

| 빌드 설정 | 용도 |
| --- | --- |
| `KKUGI_API_BASE_URL` | 꾸기 Spring API의 HTTPS 기본 주소 |
| `KKUGI_GOOGLE_IOS_CLIENT_ID` | 이 번들 ID에 등록한 iOS OAuth 클라이언트 |
| `KKUGI_GOOGLE_REVERSED_CLIENT_ID` | 해당 클라이언트의 iOS 반환 URL 스킴 |
| `KKUGI_GOOGLE_SERVER_CLIENT_ID` | Spring이 Google ID 토큰에서 검사하는 서버 클라이언트 ID |
| `KKUGI_KAKAO_NATIVE_APP_KEY` | 카카오 개발자 콘솔에서 같은 iOS 번들 ID로 등록한 앱의 네이티브 앱 키 |

푸시를 사용하는 빌드에는 Firebase iOS 앱의 `KKUGI_FIREBASE_APP_ID`, `KKUGI_FIREBASE_SENDER_ID`, `KKUGI_FIREBASE_PROJECT_ID`, `KKUGI_FIREBASE_API_KEY`를 지정한다. 실제 기기 프로비저닝에는 앱의 Push Notifications 권한과 앱·위젯 양쪽의 동일한 App Group이 필요하다. 그룹 식별자는 `KKUGI_APP_GROUP_ID`로 지정할 수 있다. APNs 인증 키는 Firebase 콘솔에 등록한다.

심사용 계정은 로그인 창에서 입력한다. Google과 카카오 SDK가 받은 토큰은 Spring의 로그인 응답을 받은 뒤 꾸기 세션으로 교환한다. 세션은 Keychain에 저장한다.

## 기준

- Android 기준은 GitLab 커밋 `218f3248`이다.
- 로그인 원본은 `android/feature/member/.../ui/login/GLoginScreen.kt`다.
- G 테마 배율 1.2와 Noto Sans KR 가변 글꼴을 사용한다.
- 정원·꾸기·Google 로고는 Android 자산을 변경 없이 복사한다.
- Kakao 아이콘은 기존 Android 벡터 경로를 SwiftUI Shape로 옮긴다.
- 전체 목표는 에픽 S15P31E101-714에 있다. 이 기반 업무는 S15P31E101-716이다.

## 프로젝트 생성

Xcode가 Swift Package Manager로 Google Sign-In과 KakaoSDKUser를 가져온다.
Python 3의 표준 라이브러리로 Xcode 프로젝트를 생성한다.

```sh
python3 ios/scripts/project.py
python3 ios/scripts/project.py --check
```

`project.py`는 `Kkugi/`, `KkugiTests/`, `KkugiUITests/`의 파일을 등록한다.
소스를 추가하면 프로젝트를 다시 생성한다. 생성한 pbxproj는 손으로 고치지 않는다.

## Mac에서 빌드·검증

Xcode 16 이상과 iOS Simulator 런타임이 필요하다. 최소 지원 버전은 iOS 17이다.
앱과 테스트 대상에는 배포용 인증서나 운영 Secret이 필요하지 않다.

```sh
xcodebuild -version
xcrun simctl list devices available
xcodebuild -project ios/Kkugi.xcodeproj -scheme Kkugi \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/DerivedData build CODE_SIGN_IDENTITY=-
xcodebuild -project ios/Kkugi.xcodeproj -scheme Kkugi \
  -destination 'platform=iOS Simulator,id=<사용할 Simulator UUID>' \
  -derivedDataPath ios/DerivedData -resultBundlePath ios/artifacts/TestResults.xcresult \
  test CODE_SIGN_IDENTITY=-
```

같은 결과 경로가 이미 있으면 다른 경로를 지정한다. 기존 결과를 덮어쓰지 않는다.
원격 실행은 S15P31E101-717에서 구성한다. Windows 정적 검사는 Xcode 검증을 대신하지 않는다.

## 캡처

`LoginSnapshotTests`는 다섯 상태를 각각 배율 1과 3으로 렌더링한다.
콘텐츠 크기는 360×720pt다. PNG 크기는 각각 360×720, 1080×2160이다.
PNG와 메타데이터는 XCTest 결과에 첨부된다. 테스트 데이터에는 실제 계정 정보가 없다.
`KKUGI_SOURCE_COMMIT`을 테스트 환경에 지정하면 메타데이터에 기준 커밋을 남긴다.

캡처 성공은 Android와의 일치를 뜻하지 않는다.
두 플랫폼의 같은 상태를 비교한 차이 보고서가 있어야 시각적 검증을 판단한다.
실기기 로그인, 카메라, 알림 수신과 다른 기능은 아직 미검증이다.

## 자산 출처

`Resources/asset-manifest.json`에 원본 경로와 SHA-256을 기록한다.
Noto Sans KR의 OFL 사용권은 `Resources/ThirdParty/NotoSansKR-OFL.txt`에 있다.
Kakao 심볼과 Google 로고는 기존 Android 로그인 자산의 출처·사용 조건을 따른다.
자산을 공개할 때는 원격 게시 목록에 자산과 사용권을 함께 포함한다.
