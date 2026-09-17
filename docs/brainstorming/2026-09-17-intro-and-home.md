# 브레인스토밍 — 인트로 & 홈 화면 (다이저)

- **작성일**: 2026-09-17
- **대상**: 첫 페이지 슬라이스 = 인트로(스플래시) + 홈(쇼핑 목록)
- **청사진**: `docs/design/2026-09-17-intro-and-home.html` (독립 실행 HTML)
- **관계**: `docs/superpowers/specs/2026-09-16-daijo-mvp-core-loop-design.md`의 핵심 루프 중
  "목록 CRUD + 앱 진입" 부분을 페이지 단위로 구체화. 권한/지오펜싱/알림은 다음 페이지로 미룸.

## 확정 사항

### 브랜딩
- 앱 표시 이름: **다이저** (기존 "다잊어"에서 변경). 패키지명은 `daijo` 유지.

### 범위
- 이 슬라이스는 **목록 CRUD + 로컬 영구저장**과 **인트로 스플래시**까지만.
- 명시적 비범위(다음 페이지): 위치/알림 권한 요청, 지오펜싱 등록, 매장 시드 적재, 진입 알림.

### 인트로(스플래시) 페이지
- **매 실행 시** 표시, 약 1.5~2초 후 홈으로 **자동 전환**(`pushReplacement`).
- 구성: 앱/회사 로고(현재 자리표시자), 앱 이름 다이저, 슬로건, 하단 회사 표기.
- **백그라운드 위치 사용 목적을 문구로 고지만** 한다(구글 플레이 사전 고지 충족). 이 페이지에서
  권한을 요청하지 않는다 — 실제 요청·지오펜싱은 다음 페이지.
- 고지 문구(초안): "다이저는 다이소 매장 근처에 도착하면 살 물건을 알려주기 위해, 앱을 사용하지 않는
  동안에도 기기 위치를 백그라운드에서 확인합니다. 위치 정보는 기기에만 사용되며 외부로 전송되지 않습니다."

### 홈(쇼핑 목록) 페이지
- **추가**: 상단 인라인 입력줄 → 엔터/＋. 추가 후 입력줄 비워 연속 입력.
- **수정**: 항목 이름 탭 → 인라인 편집.
- **수량**: 각 행 스테퍼(－/＋), 기본 1, 최소 1(1에서 － 비활성).
- **완료**: 체크박스 탭 → 회색·취소선 후 "완료" 구분선 아래로 이동. 해제하면 위로.
- **삭제**: 왼쪽 스와이프, 즉시 삭제(v1은 Undo 없음 — 후보로 기록).
- **정렬**: 미완료(등록순) → 완료(등록순). DB 쿼리에서 처리.
- **버전 표시**: 화면 하단에 앱 버전만 작게(예: v1.0.0).

## 설계 결정 (Clean Architecture)

계층: `presentation / domain / data`, 의존은 항상 domain 안쪽으로.

- **domain** (프레임워크·패키지 미의존)
  - `ShoppingItem` 순수 Dart 엔티티(id, name, quantity, isDone, createdAt).
  - `ShoppingItemRepository` 추상 인터페이스: `watchAll()`(정렬 스트림), `add(name)`, `rename(id,name)`,
    `setQuantity(id,q)`, `setDone(id,bool)`, `delete(id)`.
- **data**
  - Drift `ShoppingItems` 테이블 + 생성 코드(`core/database/app_database.dart`).
  - local datasource(Drift 쿼리, `ORDER BY is_done ASC, created_at ASC`).
  - mapper(Drift 행 → 도메인 엔티티).
  - `ShoppingItemRepositoryImpl`(인터페이스 구현).
- **presentation**
  - Riverpod `shoppingItemsProvider`(StreamProvider) + 액션 컨트롤러.
  - `home_page.dart`(입력줄·목록·버전 푸터), 위젯 `shopping_item_tile`, `add_item_field`.
  - `intro_page.dart`(스플래시 + 타이머).
  - provider가 도메인 `ShoppingItemRepository`를 주입받고 main에서 impl로 override.

### 확정된 3가지 선택 (사용자 승인, 기본 권장 채택)
1. **버전 출처**: `package_info_plus`(pubspec 버전 자동 반영).
2. **유스케이스 클래스**: 이 슬라이스에서는 생략(YAGNI). repository + 컨트롤러 직접 호출.
3. **정렬 위치**: DB 쿼리에서 처리.

## 논의했으나 채택하지 않은 대안
- 입력: FAB→다이얼로그 / 하단 추가바 → **상단 인라인 입력줄** 채택.
- 수량: 숨김(항상 1) / 이름 파싱 → **행별 스테퍼** 채택.
- 완료 표시: 제자리 취소선 / 즉시 숨김 → **취소선 + 하단 이동** 채택.
- 인트로: 첫 실행만 온보딩 / 수동 진입 → **매 실행 스플래시 자동 전환** 채택.
- 삭제 Undo 스낵바: v1 보류(후보).

## 미해결 / 다음 페이지로 이월
- 위치("항상 허용")·알림 권한 요청 UX와 시점.
- 매장 시드 적재, 가까운 20개 지오펜스 등록, ENTER 알림.
- 실제 로고 에셋(현재 자리표시자).

## 테스트 전략 (TDD)
- 엔티티/매퍼 순수 단위 테스트, repository_impl in-memory Drift, 컨트롤러 ProviderContainer,
  위젯(홈: 추가/체크/삭제/정렬/버전, 인트로: 고지 렌더 + 타이머 전환).

## 예상 소요 시간 (개략)
| 단계 | 예상 |
| --- | --- |
| data+domain (DB·엔티티·매퍼·datasource·repository) | ~50분 |
| Riverpod provider + 컨트롤러 | ~25분 |
| 홈 UI | ~60분 |
| 인트로 스플래시 | ~25분 |
| 테스트·analyze | ~30분 |

## 다음 단계
1. 이 기획 결과 커밋·푸시.
2. writing-plans로 구현 계획 작성(단계별 예상 시간 포함).
3. 사용자 허가 후 TDD 구현.
