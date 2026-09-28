# 2026-09-28 알림 권한 재허용 불가 & 항목 편집/삭제 발견성

실기기 스모크(권한 온보딩 슬라이스) 중 발견한 3건. 원인 규명 → 수정 → 테스트까지.

## ① 알림 권한을 껐다가 "허용"을 눌러도 다시 켜지지 않음

- **증상**: 온보딩에서 알림을 허용한 뒤 시스템 설정에서 알림을 끄고, 배너/온보딩으로 재진입해
  알림 카드의 **"허용"** 버튼을 눌러도 아무 일도 일어나지 않는다(권한이 다시 켜지지 않음).
- **원인**: Android는 사용자가 이미 결정한 알림 권한(허용 후 설정에서 해제 포함)에 대해
  `request()`를 호출해도 **시스템 다이얼로그를 다시 띄우지 않고 즉시 denied를 반환**한다.
  이때 `check()`는 이 상태를 `permanentlyDenied`가 아니라 `denied`로 돌려주는 경우가 많아,
  `PermissionStepTile`은 "설정 열기"가 아니라 **"허용"** 버튼을 렌더링한다 →
  버튼을 눌러 `request()`가 호출돼도 no-op(denied)이라 화면상 변화가 없다.
  (틀린 가정: `permanentlyDenied`로 잡혀 "설정 열기"가 뜰 것이다 → 알림 권한 해제 경로에선 안 잡힘.)
- **해결**: `OnboardingController.requestNotification`에서 `request()` 결과가 `granted`가 아니면
  `openAppSettings()`로 폴백하도록 수정. fake 권한 서비스로 실패 케이스(비허용 → 설정 열림) +
  허용 케이스(설정 미열림) 단위 테스트 추가.
- **관련 파일**: `lib/features/onboarding/presentation/onboarding_controller.dart`,
  `test/features/onboarding/presentation/onboarding_controller_test.dart`

## ② 항목 이름 탭 편집을 몰라서 "수정이 안 된다"고 느낌

- **증상**: 홈에서 항목을 수정할 방법이 없다고 느낌. (실제로는 이름 글자를 탭하면 편집됨.)
- **원인**: 편집 진입이 **이름 글자 탭**이라는 숨은 제스처뿐이고 눈에 보이는 단서가 없음(발견성 부재).
  더불어 `GestureDetector`가 `Text` 글자 폭만 감싸(`deferToChild`) 이름 옆 여백을 탭하면 죽은 영역.
- **해결**: 발견성 개선 — trailing에 오버플로 `⋮` 메뉴(이름 수정 / 삭제) 추가.
  탭 히트영역도 `HitTestBehavior.opaque`로 넓혀 이름 주변 탭도 편집 진입되게 함. 기존 탭 편집 유지.

## ③ 스와이프 삭제를 몰라서 "삭제가 안 된다"고 느낌

- **증상**: 삭제 방법이 없다고 느낌. (실제로는 오른쪽→왼쪽 스와이프로 삭제됨.)
- **원인**: 삭제가 `Dismissible` 스와이프뿐이라 발견성 부재.
- **해결**: ②와 동일한 `⋮` 메뉴의 "삭제" 항목으로 명시적 노출. 기존 스와이프 삭제는 단축키로 유지.
- **②③ 관련 파일**: `lib/features/shopping_list/presentation/widgets/shopping_item_tile.dart`,
  `test/features/shopping_list/presentation/widgets/shopping_item_tile_test.dart`

## 검증

- `fvm flutter test` 64/64 통과(+4 신규), `fvm flutter analyze` 무경고.
- **기기 재검증 필요(수동)**: 알림 해제 후 "허용" → 설정 이동 → 재허용 반영, `⋮` 메뉴 수정/삭제 동작.
