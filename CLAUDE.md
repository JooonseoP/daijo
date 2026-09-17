# CLAUDE.md — daijo(다잊어) 작업 지침

이 파일은 매 세션 자동으로 로드된다. 아래 원칙을 항상 지킨다.

## 프로젝트

위치 기반 지오펜싱 쇼핑 리마인더 (Flutter, Android 우선). 다이소 매장 반경 진입 시
살 물건 목록을 알림으로 강제 노출한다. 상세: `README.md`, 설계는 `docs/superpowers/specs/`.

## 작업 방식 (반드시 준수)

1. **페이지 단위로 하나씩 개발한다.** 앱 전체를 한 번에 몰아 구현하지 않는다.
   한 페이지(화면)를 브레인스토밍 → 설계 → 구현 → 검증까지 끝내고 다음 페이지로 넘어간다.
2. **각 페이지는 브레인스토밍으로 시작한다.** 구현 전에 반드시 superpowers:brainstorming으로
   의도·요구사항·설계를 먼저 정리한다.
3. **브레인스토밍한 모든 내용은 md 파일로 남긴다.** 저장 위치: `docs/brainstorming/YYYY-MM-DD-<주제>.md`.
   결정 사항, 논의된 대안, 확정/미해결 항목을 기록한다. 대화로만 끝내지 않는다.
4. **Clean Architecture 구조로 만든다.** 계층을 명확히 분리한다:
   - `domain` — 엔티티, 유스케이스(interactor), repository "인터페이스". 프레임워크/플랫폼 의존 없음.
   - `data` — repository 구현, 데이터소스(Drift DB, 시드, 플랫폼 서비스 어댑터), DTO/매핑.
   - `presentation` — 화면·위젯, Riverpod provider/controller(상태).
   - 의존 방향은 항상 안쪽(domain)으로만 향한다. presentation·data → domain. domain은 아무것도 모른다.
   - 플랫폼 서비스(알림/지오펜스/위치)는 domain의 인터페이스 뒤에 두고 data에서 구현한다.

## 기록 규칙

- **작업 로그**: 매 작업일 `docs/worklog/YYYY-MM-DD.md` 추가하고 `docs/worklog/README.md` 목록 갱신.
- **브레인스토밍**: `docs/brainstorming/`.
- **스펙/설계**: `docs/superpowers/specs/`. **구현 계획**: `docs/superpowers/plans/`.

## 기술 스택 / 제약

- 상태관리 **Riverpod 2.x** (`flutter_riverpod ^2.6.1`). Dart SDK ^3.7.2 환경에서 riverpod 3.x는
  drift_dev와 해석 충돌하므로 3.x로 올리지 않는다.
- 로컬 DB **Drift(SQLite)** — 테스트는 in-memory. 생성 코드(`*.g.dart`)는 커밋한다.
- 알림 **flutter_local_notifications**, 지오펜싱 **native_geofence**, 위치 **geolocator/permission_handler**.
- 개발은 TDD. 플랫폼 의존 로직은 인터페이스 뒤로 격리해 기기 없이 단위 테스트한다.
- 저장소는 LF 줄바꿈(`.gitattributes`). `flutter analyze`는 항상 무경고 유지.

## 명령 실행 주의

- Flutter/dart/git 명령은 **프로젝트 루트** `E:/Joonseo/dev_works/daijo`에서 실행한다.
  쉘이 `android/` 하위로 기본 설정될 수 있으니 절대경로나 `cd`로 루트를 지정한다.
