# 다이저 — 매장 시드 적재 & 가까운 매장 선별 설계 (Android)

- **작성일**: 2026-09-28
- **상태**: 스펙 리뷰 대기
- **서브프로젝트**: 핵심 루프(1/5)의 세 번째 페이지 슬라이스 — "지오펜싱 엔진"의 **슬라이스 A**
- **선행 문서**: `docs/superpowers/specs/2026-09-16-daijo-mvp-core-loop-design.md` (핵심 루프 설계)
- **이전 슬라이스**: 인트로+홈 목록(완료), 권한 온보딩(완료·병합)

## 배경

핵심 루프의 첫 두 슬라이스(목록 CRUD, 권한 온보딩)가 완료·`main` 병합되었다. 남은 것은
앱의 실제 목적인 **"매장 근처에서 알림"** = 지오펜싱 엔진이다. 이 엔진은 서비스·백그라운드
중심이라 화면 한 개가 아니므로 세 하위 슬라이스로 분해한다:

- **슬라이스 A (본 문서)** — 매장 데이터 적재 + "주어진 위치에서 가까운 20개 매장" 선별(순수 로직).
- **슬라이스 B** — 지오펜스 등록(native_geofence) + ENTER 알림(flutter_local_notifications).
- **슬라이스 C** — 실제 위치 취득(geolocator) 배선 + 경계 지오펜스 재무장 + 기기 스모크.

### 지오펜싱 동작 방식 (전제)

앱이 백그라운드에서 GPS를 상시 폴링하지 않는다(배터리·강제종료 문제). 대신 **OS 지오펜싱
API에 원(圓)들을 등록**하고, OS가 저전력 센서 융합·움직임 인지로 감시하다가 진입(ENTER)
시 앱 콜백을 깨운다. OS 지오펜스는 앱당 ~100개 한도이나 다이소는 전국 1,710개이므로,
**현재 위치 기준 가까운 20개만 선별해 등록**한다. 이 선별이 본 슬라이스의 핵심 가치다.

### 갱신 전략 (경계 지오펜스 재무장)

"앱 실행 시에만 재등록"은 앱을 안 켜고 멀리 이동하면 지오펜스가 낡는 한계가 있다. 이를
**시간 주기 폴링이 아니라 이벤트 기반**으로 해결한다: 가까운 20개와 함께 **현재 위치 중심의
큰 경계 원 1개**(반경 = 20번째 매장까지 거리)를 등록하고, 그 원을 EXIT하면 OS가 앱을 깨워
새 위치 기준으로 재선별·재등록한다. 가만히 있으면 아무 일도 안 하고(배터리 0에 근접),
생활권을 벗어나는 순간에만 자동 재무장한다. 저빈도 재등록(부팅/주기적 재확인)은 등록이
날아가는 예외 상황용 **안전망**으로 보조한다.

> 본 슬라이스 A는 선별 결과에 **경계 반경을 포함해 반환**하는 데까지 책임진다. 실제 경계
> 지오펜스 등록·EXIT 재무장 배선은 슬라이스 B/C의 몫이다.

## 이번 사이클(슬라이스 A)의 범위

- `assets/data/daiso_stores.json`(전국 1,710개) → **버전 플래그 기반 1회 DB 적재**.
- `Store` 도메인 모델 + Drift `Stores` 테이블(+ schemaVersion 3 마이그레이션).
- **가까운 20개 선별 + 경계 반경 계산**(Haversine, 순수 로직).
- 위치 취득은 `LocationService` **인터페이스만 정의**(실구현은 슬라이스 C).
- 기기 없이 in-memory Drift + 고정 좌표로 100% 단위 테스트.

### 명시적 비범위 (다음 슬라이스 / YAGNI)

- 실제 지오펜스 등록·ENTER 알림 (슬라이스 B)
- geolocator 실구현·경계 지오펜스 재무장 배선·기기 스모크 (슬라이스 C)
- 경계 반경 마진/히스테리시스 (플래핑 관찰 시 도입)
- 최대 거리 컷오프 (외곽에서도 무조건 가까운 20개)
- address/phone 필드 활용, 매장 상세 화면
- 움직임 감지(significant-motion) 기반 동적 재등록 고도화

## 결정 사항 (브레인스토밍 확정)

| 항목 | 결정 |
| --- | --- |
| 슬라이스 A 경계 | 순수 선별만. 위치 취득은 `LocationService` 인터페이스만(실구현 C) |
| 시드 적재 전략 | `app_settings`의 `stores_seed_version` 플래그 기반 1회 적재. 버전 상이 시 clear→insert |
| 선별 규칙 | Haversine 거리, `(거리 오름차순, id 오름차순)` 정렬, 가까운 20개. 컷오프 없음 |
| 경계 반경 | 20번째(가장 먼 선택) 매장까지 거리. 마진 없음(YAGNI) |
| 갱신 방식 | (주) 경계 지오펜스 EXIT 재무장(이벤트) + (보조) 저빈도 재등록 안전망 — 배선은 B/C |
| `Store` 필드 | `id`(String)·`name`·`latitude`·`longitude`·`radius`(적재 시 150m). address/phone 버림 |
| 매장 데이터 | 크롤링한 전국 실데이터 `daiso_stores.json` 채택. 테스트는 소수 고정 픽스처 |
| 상수 | `N=20`, 기본 반경 `150m`, 지구 반경 `6371000m` |

## 아키텍처 (Clean Architecture · feature-first)

```
lib/
  core/
    location/
      location_service.dart        인터페이스 + LatLng 값 객체. currentPosition() → Future<LatLng?>
                                   (실구현 geolocator는 슬라이스 C)
    database/
      app_database.dart            Stores 테이블 추가 + schemaVersion 3 + 마이그레이션
  features/
    stores/
      domain/
        entities/store.dart              Store (순수 Dart)
        entities/geofence_selection.dart 선별 결과 값 객체
        repositories/store_repository.dart 인터페이스
      data/
        datasources/store_seed_loader.dart   asset JSON 파싱 (AssetBundle 주입)
        datasources/store_local_datasource.dart Drift DAO
        mappers/store_mapper.dart
        repositories/store_repository_impl.dart
      application/
        store_seeder.dart          버전 플래그 기반 1회 적재
        nearby_selector.dart       가까운 20개 + 경계 반경 (순수 로직)
      presentation/
        stores_providers.dart      Riverpod providers
assets/
  data/daiso_stores.json           pubspec 에셋 등록
```

의존성 방향은 항상 domain을 향한다. `nearby_selector`는 외부 의존 0의 순수 로직,
`store_seeder`는 repository·설정 KV 인터페이스에만 의존한다. 위치 취득은 `LocationService`
인터페이스로만 참조하며 실구현은 두지 않는다.

## 데이터 모델

**Drift `Stores` 테이블 / `Store` 엔티티**

| 컬럼 | 타입 | 비고 |
| --- | --- | --- |
| `id` | TEXT (PK) | JSON 매장 id 그대로. native_geofence 지오펜스 ID로 재사용 |
| `name` | TEXT | 매장명 |
| `latitude` | REAL | |
| `longitude` | REAL | |
| `radius` | REAL | 적재 시 기본 150m 주입 |

- `AppDatabase` schemaVersion **2 → 3**. `MigrationStrategy`에 `Stores` 생성 단계 추가
  (기존 `shopping_items`·`app_settings` 보존). 생성 코드(`*.g.dart`) 재생성·커밋.

**`GeofenceSelection` 값 객체**

```
GeofenceSelection {
  LatLng center;                // 선별 기준 위치
  List<Store> stores;           // 가까운 N개 (거리 오름차순)
  double boundaryRadiusMeters;  // 경계 지오펜스 반경 = N번째 매장까지 거리
}
```

## 데이터 흐름

1. 앱 부팅 → Drift DB 초기화(기존).
2. `StoreSeeder.ensureSeeded()` 1회 await: `stores_seed_version` 조회 → 코드 상수와 비교.
   - 같으면 skip. 다르면 트랜잭션으로 `Stores` clear → JSON batch insert(radius 150m 주입)
     → 버전 기록.
3. `LocationService.currentPosition()`로 현재 좌표 취득(슬라이스 A에선 인터페이스; 테스트는 fake).
4. `repo.getAll()` + `NearbySelector`로 가까운 20개 + 경계 반경 계산 → `GeofenceSelection`.
5. (슬라이스 B) 선별 결과로 지오펜스 등록 + 경계 원 등록. (슬라이스 C) EXIT 재무장 배선.

## 선별 로직 (`NearbySelector`, 순수)

1. 각 매장까지 **Haversine 거리**(미터) 계산. 지구 반경 6,371,000m.
2. `(거리 오름차순, id 오름차순)` 정렬 → 상위 `N=20`개 선택.
3. `boundaryRadiusMeters` = 가장 먼 선택 매장까지 거리(마진 없음).

**엣지 케이스**
- 매장 수 ≤ N: 전부 선택, 경계 반경 = 가장 먼 매장 거리.
- 매장 0개: 빈 선별 + 반경 0 → 등록 대상 없음, 크래시 없이 no-op.
- 동일 거리 tie: `id` 문자열 오름차순으로 결정적 처리(테스트 재현성).
- 현재 위치 `null`(권한/취득 실패): 빈 선별 반환.

## 오류 처리

- **위치 취득 실패/권한 없음** → `currentPosition()` null → 빈 선별. 앱은 순수 목록 앱으로 계속 동작.
- **에셋 파싱 실패** → 로깅 + 적재 skip(기존 데이터 유지), 크래시 없음.
- **적재 트랜잭션 실패** → 롤백, 버전 미기록(다음 실행 재시도), 로깅.
- **GPS 서비스 꺼짐** → 슬라이스 A 비범위(위치 null로 취급).

## 테스트 전략 (TDD, 기기 불필요)

1. `NearbySelector` — 고정 좌표 픽스처: 정렬·상한, 경계 반경=N번째 거리, tie-break(id),
   매장 ≤N, 매장 0개, 위치 null.
2. Haversine 거리 — 알려진 두 지점 거리로 정확도 검증(허용 오차 내).
3. `StoreSeeder` — in-memory Drift + 가짜 AssetBundle: 최초 적재 / 버전 동일 skip /
   버전 변경 시 clear→재적재 멱등성 / 파싱 실패 저하.
4. `StoreRepository` 구현 — getAll/replaceAll/clear in-memory.
5. `store_mapper` — JSON→Store, radius 150m 주입, id String 보존.
6. `nearbySelectionProvider` — fake `LocationService` + in-memory repo 통합 흐름(위치 null 포함).

**데이터 품질 스팟체크(비차단)**: 구현 착수 시 강남역점 등 아는 매장 2~3개 좌표를 지도와
대조해 크롤링 오차 확인. 이상 없으면 그대로 사용.

## DoD (완료 정의)

- [ ] `Stores` 테이블 + schemaVersion 3 마이그레이션, 기존 데이터 보존.
- [ ] `daiso_stores.json` 부팅 시 1회 적재(로그 확인), 재실행 시 skip.
- [ ] `NearbySelector`가 가까운 20개 + 경계 반경을 정확히 산출(엣지 포함).
- [ ] `LocationService` 인터페이스 정의(실구현 없음), fake로 통합 테스트.
- [ ] 위 테스트 전부 통과, `fvm flutter analyze` 무경고, 생성 코드 커밋.

## 다음 단계

1. 사용자 스펙 리뷰
2. writing-plans 스킬로 구현 계획 작성
3. 구현 (SDD · TDD · Clean Architecture)
4. 이후 슬라이스 B(지오펜스 등록 + 알림), C(위치 배선 + 재무장 + 기기 스모크)
