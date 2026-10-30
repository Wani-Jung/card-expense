import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 서명 키: 로컬은 android/key.properties, CI 는 환경변수(GitHub Secrets)에서 읽는다.
// 둘 다 없으면 debug 키로 서명한다. 업데이트 설치가 되려면 항상 같은 키여야 한다.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun signingValue(prop: String, env: String): String? =
    keyProps.getProperty(prop) ?: System.getenv(env)
val releaseStoreFile = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")

android {
    namespace = "com.wani.card_expense"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.wani.card_expense"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 두 판: public(일반판, 문자 권한 없음) / full(전용판, 문자 권한 + 지난 문자 불러오기).
    // 같은 applicationId·서명키라 서로 덮어 설치해도 데이터가 유지된다.
    // 문자 권한·리시버는 src/full/ 에만 둔다. public 에는 절대 넣지 말 것.
    flavorDimensions += "edition"
    productFlavors {
        create("public") { dimension = "edition" }
        create("full") { dimension = "edition" }
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = if (releaseStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// release APK 는 휴대폰용 ABI 2개(arm64-v8a, armeabi-v7a)만. CI 의 flutter --target-platform 은 Flutter 라이브러리만
// 거르므로 ML Kit 같은 플러그인 네이티브 라이브러리의 x86_64 도 여기서 뺀다. debug(에뮬레이터)는 그대로.
androidComponents {
    onVariants(selector().withBuildType("release")) { variant ->
        variant.packaging.jniLibs.excludes.add("lib/x86_64/**")
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 문자 캡처 OCR: google_mlkit_text_recognition 플러그인은 한국어 모델을 compileOnly 로만 둔다. 기기 안에서 인식.
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
}
