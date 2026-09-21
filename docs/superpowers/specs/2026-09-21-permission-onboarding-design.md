# 다이저 — 권한 온보딩 설계 (Android)

- **작성일**: 2026-09-21
- **상태**: 스펙 리뷰 대기
- **서브프로젝트**: 핵심 루프(1/5)의 두 번째 페이지 슬라이스 — "권한 온보딩"
- **선행 문서**: `docs/superpowers/specs/2026-09-16-daijo-mvp-core-loop-design.md` (핵심 루프 설계)
- **화면 청사진**: `docs/design/2026-09-21-permission-onboarding.html`

## 배경

핵심 루프의 첫 페이지(인트로 스플래시 + 홈 목록)는 완료·병합되었다. 다음 페이지는
**권한 온보딩** — 지오펜싱 알림에 필요한 위치("항상 허용")·알림 권한을 안내하고 요청하는 화면이다.
이후 페이지(매장 시드 적재 → 가까운 20개 지오펜스 등록 → ENTER 알림)가 이 권한 위에서 동작한다.

핵심 UX 제약: **Android 10+에서 백그라운드 위치("항상 허용")는 한 번에 못 받는다.**
먼저 "앱 사용 중" 위치(foreground)를 받고, 그다음 **별도로** "항상 허용"을 요청해야 한다.
Android 11+에서는 이 백그라운드 요청이 다이얼로그가 아니라 **시스템 설정 화면으로 딥링크**된다.
따라서 온보딩은 한 화면에서 권한 카드를 **위에서부터 순차로** 안내하는 구조로 설계한다.

## 이번 사이클의 범위

- **첫 실행 게이트**: 인트로 → (`onboardingCompleted == false`면) 온보딩 → 홈. 완료 플래그를 영구 저장하고
  이후 실행은 홈으로 직행.
- **단일 화면 · 순차 권한 카드**: 위치(앱 사용 중) → 위치 항상 허용 → 알림, 3개 카드.
- **논블로킹**: 언제든 "건너뛰기" 가능. 권한을 거부/일부만 허용해도 홈으로 진입하며,
  앱은 순수 목록 앱으로 계속 사용 가능.
- **Google Play prominent disclosure**: "위치 항상 허용" 요청 직전에 백그라운드 위치 사용 고지 문구 노출.
- **홈 배너(기본)**: 위치 항상 허용 또는 알림 권한 미허용 시 홈 상단에 "알림이 꺼져 있어요 → 권한 켜기" 배너.
- **권한 서비스 추상화**: 플랫폼 권한(permission_handler/geolocator)을 `core/permissions/` 인터페이스 뒤로 격리.

### 명시적 비범위 (YAGNI · 다음 사이클)

- 실제 지오펜스 등록/알림 발생 (다음 페이지)
- 매장 시드 적재 (다음 페이지)
- GPS(위치 서비스) 꺼짐 감지·유도 배너 (후속 — 이번엔 크래시 없이 무시)
- 앱 lifecycle(resume) 시 권한 상태 자동 재확인 (이번엔 화면 build 시 조회로 충분; 후속 고도화)
- iOS 권한 흐름

## 결정 사항 (브레인스토밍 확정)

| 항목 | 결정 |
| --- | --- |
| 노출 시점 | 첫 실행에만 게이트. `onboardingCompleted` 플래그로 이후 스킵 |
| 건너뛰기 정책 | 언제든 건너뛰기 허용 (논블로킹). "시작하기"·"건너뛰기" 모두 완료 처리 |
| 화면 구조 | 단일 화면, 순차 권한 카드 (버튼으로 순차 요청) |
| 홈 배너 | 이번 사이클 포함 (기본 배너까지) |
| 권한 서비스 위치 | `core/permissions/` (인터페이스 + 구현). onboarding·home이 공유 |
| 완료 플래그 저장 | **Drift `app_settings` 키-값 테이블** (shared_preferences 신규 의존성 회피, in-memory 테스트 가능) |

## 아키텍처 (Clean Architecture · feature-first)

```
lib/
  core/
    permissions/
      permission_service.dart        인터페이스 + PermissionKind/PermissionStatus (순수 Dart)
      permission_service_impl.dart   permission_handler + geolocator 구현 (data 계층 역할)
    database/
      app_database.dart              AppSettings(KV) 테이블 + DAO 추가, MigrationStrategy
  features/
    onboarding/
      domain/
        repositories/onboarding_preferences.dart   인터페이스 (isCompleted / setCompleted)
      data/
        repositories/onboarding_preferences_impl.dart  Drift KV 기반 구현
      presentation/
        onboarding_page.dart
        onboarding_controller.dart   Riverpod Notifier (순서 강제 · 상태 전이)
        onboarding_providers.dart    provider 배선
        widgets/permission_step_tile.dart
    shopping_list/
      presentation/
        widgets/permission_banner.dart
        permission_status_provider.dart
```

**설계 원칙**: 플랫폼 서비스(권한)는 `core/permissions/`의 순수 Dart 인터페이스 뒤에 격리한다.
`permission_service_impl.dart`만 permission_handler/geolocator에 의존하며, 컨트롤러·배너·프리퍼런스는
fake 주입으로 기기 없이 단위 테스트한다. 의존성 방향은 안쪽(순수 인터페이스)을 향한다.

## 권한 서비스 인터페이스 (초안)

```dart
enum PermissionKind { locationWhenInUse, locationAlways, notification }
enum PermissionStatus { granted, denied, permanentlyDenied, notApplicable }

abstract interface class PermissionService {
  Future<PermissionStatus> check(PermissionKind kind);
  Future<PermissionStatus> request(PermissionKind kind);
  Future<void> openAppSettings();
}
```

- **순서 강제**(컨트롤러 책임): `locationAlways` 요청은 `locationWhenInUse == granted`일 때만 활성.
  그 전에는 카드가 잠김(🔒) 상태.
- **Android 11+ `locationAlways`**: 시스템 설정 딥링크로 처리 → 버튼 문구 "설정에서 허용".
  구현은 `permission_handler`의 background-location 요청 경로를 사용.
- **알림**: Android 13+(POST_NOTIFICATIONS) 대상. 그 이하 OS 버전에서는 `notApplicable` 반환.
- **영구 거부**: `permanentlyDenied` → 버튼이 "설정 열기"로 바뀌고 `openAppSettings()` 호출.

## 완료 플래그 (Drift KV)

- `app_settings` 테이블: `key TEXT PRIMARY KEY`, `value TEXT`. 범용 문자열 KV.
- `OnboardingPreferences.isCompleted()` → `app_settings['onboarding_completed'] == 'true'`.
- `setCompleted()` → 해당 키 upsert.
- 스키마 변경이므로 Drift **`MigrationStrategy`** 를 이 PR에서 함께 추가한다(기존 상태 이전 대비).

## 화면 상태 (단일 화면, 순차 카드)

- **헤더**: 아이콘 + 제목 "문 앞에서 알려드릴게요" + 한 줄 설명.
- **권한 카드 3개** (위→아래 순서):
  1. **위치 (앱 사용 중)** — 가까운 매장 탐색용. `허용` 버튼.
  2. **위치 항상 허용** — 백그라운드 감지용. **prominent disclosure 문구** + `설정에서 허용` 버튼.
     `locationWhenInUse` 미허용 시 잠김.
  3. **알림** — 목록 알림용. `허용` 버튼. Android 13 미만이면 이미 허용/`notApplicable`로 표시.
- **카드 상태 표현**: `허용` 버튼 / `허용됨 ✓`(pill) / `🔒 잠김` / `설정 열기`(영구 거부).
- **하단**: 항상 활성인 `시작하기` CTA + `권한 없이 목록만 사용할게요`(건너뛰기) + "나중에 홈에서 다시 켤 수 있어요" 안내.

## 홈 배너

- 조건: `locationAlways != granted` **또는** `notification != granted`.
- 위치: `HomePage` 목록 상단. 내용: "매장 근처 알림이 꺼져 있어요 · 권한 켜기 ›".
- 탭 동작: 권한 재요청 흐름 실행(또는 영구 거부면 설정 이동). 온보딩 재진입 경로를 완결.
- 상태 조회: `permissionStatusProvider`가 화면 build 시 `PermissionService.check`로 조회
  (lifecycle 재확인은 비범위).

## 데이터 흐름

1. 인트로 스플래시 종료 → `OnboardingPreferences.isCompleted()` 조회.
2. `false` → `OnboardingPage`. `true` → `HomePage`.
3. 온보딩: 카드별 `허용` → `PermissionService.request(kind)` → 상태 갱신. 순서 강제.
4. `시작하기`/`건너뛰기` → `setCompleted(true)` → `HomePage`로 교체 이동.
5. 홈: `permissionStatusProvider` 조회 → 미허용이면 배너 표시. 배너 탭 → 재요청/설정.

## 오류 처리

- **권한 거부/일부 허용** → 진행 막지 않음. 홈 배너로 재유도.
- **영구 거부** → "설정 열기"로 유도.
- **권한 요청 예외/플랫폼 오류** → 로깅 + `denied`로 취급, 크래시 없이 저하 동작.
- **GPS(위치 서비스) 꺼짐** → 이번 사이클 비범위(무시). 후속에서 감지·유도.

## 테스트 전략 (TDD)

기기 없이 검증 가능한 로직을 인터페이스 뒤로 분리한다.

- `OnboardingController`: fake `PermissionService`로 순서 강제(`locationAlways` 잠금),
  상태 전이(허용/거부/영구 거부), `시작하기`·`건너뛰기` 시 `setCompleted` 호출 검증.
- `OnboardingPreferences` Drift 구현: in-memory DB read/write, upsert 멱등성.
- `PermissionStepTile` 위젯: 상태별 렌더(버튼/체크/잠금/설정 열기).
- `permission_banner` / provider: 권한 상태에 따른 표시·비표시.
- `AppSettings` DAO: KV get/set, MigrationStrategy 동작.
- 실제 권한 다이얼로그·딥링크·백그라운드 위치는 **기기 수동 스모크**.

## DoD (완료 정의)

- [ ] 첫 실행: 인트로 → 온보딩 → 홈, 재실행 시 홈 직행 (플래그 영구 저장 확인).
- [ ] 순차 카드: 위치(사용중) 허용 전 "항상 허용" 잠김, 허용 후 활성.
- [ ] "항상 허용" 요청이 설정으로 딥링크되고, 허용 시 상태 반영.
- [ ] 알림 권한 요청/반영 (Android 13+).
- [ ] 건너뛰기/거부해도 홈 진입, 홈 배너 표시 및 배너 탭 재유도.
- [ ] 테스트 전부 통과, `fvm flutter analyze` 무경고.
- [ ] 기기 스모크 완료.

## 다음 단계

1. 사용자 스펙 리뷰
2. writing-plans 스킬로 구현 계획 작성
3. 구현 (SDD · TDD · Clean Architecture)
