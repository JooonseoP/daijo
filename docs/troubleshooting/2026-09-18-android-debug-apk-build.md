# 트러블슈팅 — Android 디버그 APK 빌드 실패 (2026-09-18)

`fvm flutter build apk --debug`가 연쇄적으로 4개의 서로 다른 원인으로 실패. 하나를 고치면 다음
레이어가 드러나는 형태였다. 각각 증상 → 원인 → 해결 순으로 기록. (관련 커밋: 본 문서와 함께 커밋)

프로젝트 툴체인 기준: Flutter 3.29.2(FVM), Gradle 8.10.2, AGP 8.7.0, (초기) Kotlin Gradle Plugin 1.8.22.

## 1. permission_handler_android 14.1.0 — `compilerOptions` 미해결

**증상**
```
permission_handler_android-14.1.0/android/build.gradle.kts:68  kotlin {
:69      compilerOptions {
:70          jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
Unresolved reference: compilerOptions / jvmTarget
```

**원인**
`pubspec.yaml`이 `permission_handler: ^13.0.2`로 되어 있어 umbrella가 최신 `permission_handler_android
14.1.0`을 끌어옴. 이 버전의 build.gradle.kts는 자체 buildscript에서 **AGP 9.0.1 + Kotlin 2.3.20 + Java 17**을
선언하고 Kotlin 2.0+ 전용 `kotlin { compilerOptions { } }` DSL을 사용 → Flutter 3.29 툴체인(Gradle 8.10.2 /
AGP 8.7.0 / Kotlin 1.8.22)보다 한참 앞서 스크립트 컴파일 자체가 실패.

**틀렸던 시도**
`settings.gradle.kts`의 Kotlin 플러그인을 `1.8.22 → 2.1.0`으로만 올려봄 → 동일 에러. permission_handler
14.1.0은 Kotlin 2.1이 아니라 **AGP 9 / Kotlin 2.3**을 요구하므로 부분 상향으론 해결 불가. 되돌림.

**해결**
permission_handler를 이 툴체인에 맞는 버전으로 **아래로 정렬**: `permission_handler: ^11.3.1`로 핀 고정
(→ `permission_handler 11.4.0`, `permission_handler_android 12.1.0` 해석). 12.1.0은 Groovy `build.gradle` +
AGP 8.0.0 + Java 8 구 DSL이라 현재 툴체인과 호환. 11.x는 계획된 권한 온보딩(배경 위치 "항상 허용"·알림
권한)을 모두 지원하므로 기능 손실 없음. (AGP 9/Kotlin 2.3으로 툴체인을 통째로 올리는 것은 Flutter 3.29
고정 정책과 배치되고 위험이 커서 배제.)

## 2. flutter_local_notifications — core library desugaring 필요

**증상**
```
Dependency ':flutter_local_notifications' requires core library desugaring to be enabled for :app.
```

**원인**
flutter_local_notifications 19.x가 `java.time` 등 Java 8+ API를 사용 → 구형 Android API 레벨 지원을 위해
core library desugaring이 필요.

**해결** `android/app/build.gradle.kts`:
- `compileOptions { isCoreLibraryDesugaringEnabled = true }`
- `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }`

## 3. native_geofence — minSdk 23 요구

**증상**
```
The plugin native_geofence requires a higher Android SDK version.  (minSdkVersion 23)
```

**원인** native_geofence가 minSdk 23을 요구하는데 앱은 Flutter 기본 minSdk(21)를 상속.

**해결** `android/app/build.gradle.kts` defaultConfig: `minSdk = maxOf(23, flutter.minSdkVersion)`.

## 4. native_geofence — kotlinx.serialization 컴파일러 플러그인 미해결

**증상**
```
Could not find org.jetbrains.kotlin:kotlin-serialization-compiler-plugin-embeddable:1.8.22
```

**원인**
native_geofence가 kotlinx.serialization을 사용. serialization 컴파일러 플러그인의 `-embeddable` 아티팩트는
**Kotlin 1.8.22에는 배포되지 않음**(1.9.20+/2.x부터 배포). 프로젝트 Kotlin 플러그인이 1.8.22라 해석 실패.

**해결**
`settings.gradle.kts`에서 Kotlin Gradle Plugin을 **1.8.22 → 2.1.0**으로 상향(2.1.0에는 해당 아티팩트 배포됨).
2.1.0은 Gradle 8.10.2 / AGP 8.7.0과 호환. (1번에서 permission_handler를 12.1.0으로 정렬해 두었기에 이제
Kotlin 2.1.0 상향이 다른 플러그인과 충돌 없이 적용됨.)

## 결과

`fvm flutter build apk --debug` 성공(`build/app/outputs/flutter-apk/app-debug.apk`). `fvm flutter analyze`
무경고, 전체 테스트 34/34 통과. 빌드 로그에 Kotlin incremental-compilation 캐시 관련 비치명적 스택
트레이스가 보이나 빌드 결과에는 영향 없음.

**변경 파일**: `pubspec.yaml`, `pubspec.lock`, `android/settings.gradle.kts`, `android/app/build.gradle.kts`.

## 남은 확인(기기 스모크)
빌드는 통과했으나 DoD의 실기기 동작(인트로→홈, 항목 추가/체크 하단 이동/수량 스테퍼/스와이프 삭제,
앱 재실행 후 목록 유지)은 에뮬레이터/기기에서 별도 확인 필요.
