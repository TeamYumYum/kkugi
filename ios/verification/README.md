# iOS 화면 검증

이 도구는 실제 SwiftUI 캡처를 모으고 Android 캡처와 원본 픽셀을 비교한다.
빌드 통과와 화면 일치는 별개로 기록한다.

## 로컬 검사

Python 3.11 이상이면 외부 패키지 없이 실행할 수 있다.

```sh
python -m unittest discover -s ios/verification/tests -v
```

## 공개할 파일 준비

앱 기반은 S15P31E101-716, 검증 도구는 S15P31E101-717 작업 공간에 있다.
두 작업의 파일을 명시적인 허용 목록으로 묶는다. Git 이력이나 서버 코드는 복사하지 않는다.

```sh
python ios/verification/package.py --app-root <716-작업공간> \
  --verification-root <717-작업공간> --output <새로운-출력-디렉터리>
```

`public-files.json`은 게시 예정 경로, 크기와 SHA-256을 담는다.
환경 파일, 로컬 설정, 기존 결과와 예상 밖의 자산은 포함하지 않는다.
출력이 이미 있으면 덮어쓰지 않는다. 이 명령은 커밋·Push·게시를 수행하지 않는다.
실제 공개는 사용자가 파일 목록을 확인한 뒤 승인한 범위에서만 한다.

## macOS 실행

사용자는 기존 공개 GitHub 저장소를 선택했다. workflow 구현 플랜도 승인했다.
실제 게시 승인과 실행은 별개다.

첫 수동 실행에는 기본 브랜치에 workflow 등록이 필요하다. 기존 별도 브랜치 전용 게시 계획으로는 실행할 수 없으므로 기본 브랜치 등록은 별도 승인 전 수행하지 않는다.

workflow는 수동 실행만 지원한다. 표준 `macos-15`에서 최대 20분 동안 실행한다.
권한은 `contents: read`이며, checkout 인증 정보를 보존하지 않는다.
공식 checkout·upload-artifact Action은 커밋 해시로 고정한다.
결과 보존 기간은 3일이다. 기존 GitLab CI와 배포는 바꾸지 않는다.

실행 환경은 Xcode 16.4, iOS 18.5, iPhone 16이다.
해당 환경이 없으면 다른 버전으로 대체하지 않고 실패한다.
실제 환경 정보는 `ios/artifacts/environment.json`에 남긴다.

앱 소스와 도구가 모두 있는 작업 공간에서 다음을 실행한다.

```sh
DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer \
  python3 ios/verification/run_macos.py
```

Xcode 빌드·테스트, 원본 xcresult, PNG 첨부와 메타데이터를 보관한다.
콘텐츠 PNG 10개와 전체 화면 PNG 1개, 각각의 메타데이터 11개가 없으면 실패한다. 전체 화면 메타데이터는 콘텐츠 경계와 안전 영역 제외 좌표를 기록한다.
실패 로그도 보관한다. 캡처 성공은 `pixelParity: not-yet-compared`로 표시한다.

## 픽셀 비교

같은 콘텐츠 크기·상태·배율로 캡처한 Android PNG와 iOS PNG가 필요하다.
색 공간도 일치해야 한다. 도구는 ICC·감마·색도·sRGB·HDR 색 정보가 다르면 비교를 거부한다.
RGB·RGBA·회색조의 8비트 비인터레이스 PNG를 지원한다. 다른 형식은 명시적으로 거부한다.

```sh
python ios/verification/pixels.py --reference android.png \
  --candidate ios.png --output comparison-001
```

종료 코드 0은 완전 일치, 1은 차이 발견, 2는 입력·실행 오류다.
기본 허용 오차는 0이다. 다른 픽셀을 임의로 허용하지 않는다.
OS 고유 영역을 제외하려면 먼저 같은 콘텐츠 영역을 캡처하고 좌표를 기록해야 한다.
도구 자체는 리사이즈·흐림·자동 정렬·마스킹을 하지 않는다.

결과에는 원본 PNG, 나란히 보기, 50% 겹침, 절대 RGB 차이와 JSON·HTML 보고서가 들어간다.
차이 수치는 알파 채널도 포함한다. 차이 이미지는 불투명 RGB이므로 알파 차이는 수치를 함께 확인한다.
입력 크기 불일치, 누락된 파일과 같은 경로의 자기 비교는 실패한다.
기존 출력은 덮어쓰지 않는다.

Android 기준 이미지 확보와 실제 iOS 렌더링을 마치기 전에는 픽셀 검증을 완료로 기록하지 않는다.
전체 앱의 화면·상태 목록을 모두 비교해야 최종 이식 목표를 달성한다.
