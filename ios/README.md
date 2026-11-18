# 꾸기 iOS

SwiftUI 앱을 추가하는 작업 공간이다. 현재는 로그인 화면과 캡처 기반을 구현하는 중이다.
인증 SDK와 서버 연결은 아직 없으며, 로그인 시 명시적인 실패를 표시한다.
이 상태는 배포 가능한 앱이나 전체 이식 완료가 아니다.

## 기준

- Android 기준은 GitLab 커밋 `218f3248`이다.
- 로그인 원본은 `android/feature/member/.../ui/login/GLoginScreen.kt`다.
- G 테마 배율 1.2와 Noto Sans KR 가변 글꼴을 사용한다.
- 정원·꾸기·Google 로고는 Android 자산을 변경 없이 복사한다.
- Kakao 아이콘은 기존 Android 벡터 경로를 SwiftUI Shape로 옮긴다.
- 전체 목표는 에픽 S15P31E101-714에 있다. 이 기반 업무는 S15P31E101-716이다.

## 프로젝트 생성

외부 Swift 패키지나 프로젝트 생성 라이브러리는 사용하지 않는다.
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
  -derivedDataPath ios/DerivedData build CODE_SIGNING_ALLOWED=NO
xcodebuild -project ios/Kkugi.xcodeproj -scheme Kkugi \
  -destination 'platform=iOS Simulator,id=<사용할 Simulator UUID>' \
  -derivedDataPath ios/DerivedData -resultBundlePath ios/artifacts/TestResults.xcresult \
  test CODE_SIGNING_ALLOWED=NO
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
