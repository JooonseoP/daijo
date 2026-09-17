# CLAUDE.md — daijo(다잊어) 작업 지침

Flutter 앱 프로젝트. superpowers 워크플로를 테스트하며 개발한다.
이 파일은 매 세션 자동 로드된다. 아래 원칙을 항상 지킨다.

## 프로젝트

위치 기반 지오펜싱 쇼핑 리마인더 (Android 우선). 다이소 매장 반경 진입 시 살 물건 목록을
알림으로 강제 노출한다. 상세: `README.md`, 설계: `docs/superpowers/specs/`.

## 아키텍처 — Clean Architecture

- 모든 구조는 Clean Architecture로 설계한다. 계층 분리: `presentation` / `domain` / `data`.
  - `domain` — 엔티티, 유스케이스, repository "인터페이스". 프레임워크·외부 패키지에 의존하지 않는다.
  - `data` — repository 구현, 데이터소스(Drift DB, 시드, 플랫폼 서비스 어댑터), DTO/매핑.
  - `presentation` — 화면·위젯, Riverpod provider/controller(상태).
- 의존성 방향은 항상 안쪽(domain)을 향한다: presentation → domain ← data. domain은 아무것도 모른다.
- 플랫폼 서비스(알림/지오펜스/위치)는 domain의 인터페이스 뒤에 두고 data에서 구현한다.

## 개발 워크플로 — 기획 → 디자인 → 개발

작업은 **페이지(화면) 단위로 하나씩** 진행하며, 각 페이지를 기획 → 디자인 → 개발 단계로 나눈다.

### 기획 (Brainstorming & 계획)
- 모든 기능/작업은 brainstorming을 먼저 거친다(superpowers:brainstorming).
- brainstorming 중에는 **항상 화면 청사진(와이어프레임 목업)을 만들어** 보여준다.
  완성된 청사진은 `docs/design/`에 **독립 실행 가능한 HTML**로 저장한다.
- brainstorming한 모든 내용은 md로 남긴다: `docs/brainstorming/YYYY-MM-DD-<주제>.md`
  (결정·대안·확정/미해결). 대화로만 끝내지 않는다.
- 작업 계획(plan)에는 각 단계별 **예상 소요 시간**을 함께 기록한다.
- **단계 전환 시 사용자의 명시적 허가를 받는다.** 계획을 충분히 구체화한 뒤 다음 단계로 넘어간다.
- 기획이 끝나면 그 결과물을 git에 **커밋·푸시**한다.

### 개발
- TDD로 구현한다. 플랫폼 의존 로직은 인터페이스 뒤로 격리해 기기 없이 단위 테스트한다.
- 생성 코드(`*.g.dart`)는 커밋한다. `flutter analyze`는 항상 무경고 유지.

## 에러 처리 기록 (Troubleshooting)

- 개발·빌드·실기기 테스트 중 **에러(빌드 실패, 크래시, 이상 동작 등)가 발생하면 해결 후 반드시 기록**한다.
- 위치: `docs/troubleshooting/YYYY-MM-DD-<주제>.md`
- 형식: **증상 → 원인 → 해결 (→ 관련 커밋)**. 원인 규명 중 시도했다 틀린 방법도 함께 남겨 같은 우회를 반복하지 않는다.
- 같은 주제의 후속 에러는 해당 문서에 이어서 추가한다.

## 환경 / 명령 실행

- Flutter SDK는 FVM으로 **3.29.2**에 고정(`.fvmrc`). 모든 명령은 **`fvm flutter ...`, `fvm dart ...`**로 실행한다.
  일반 `flutter`/`dart`를 직접 쓰지 않는다.
- `fvm`은 이 환경에서 **PowerShell**에만 PATH가 있다(bash엔 없음). Flutter/dart 명령은 PowerShell로 실행.
- 모든 명령은 **프로젝트 루트** `E:/Joonseo/dev_works/daijo`에서 실행한다(쉘이 `android/` 하위로 기본 설정될 수 있음).

## 기술 스택 / 제약

- 상태관리 **Riverpod 2.x** (`flutter_riverpod ^2.6.1`). Dart SDK ^3.7.2에서 riverpod 3.x는
  drift_dev와 해석 충돌하므로 올리지 않는다.
- 로컬 DB **Drift(SQLite)** — 테스트는 in-memory.
- 알림 **flutter_local_notifications**, 지오펜싱 **native_geofence**, 위치 **geolocator/permission_handler**.
- 저장소는 LF 줄바꿈(`.gitattributes`).

## 기록 위치 요약

- 작업 로그: `docs/worklog/YYYY-MM-DD.md` (+ `docs/worklog/README.md` 목록 갱신)
- 브레인스토밍: `docs/brainstorming/` · 화면 청사진 HTML: `docs/design/`
- 스펙/설계: `docs/superpowers/specs/` · 구현 계획: `docs/superpowers/plans/`
- 트러블슈팅: `docs/troubleshooting/`
