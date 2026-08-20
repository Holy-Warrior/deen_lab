plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.holywarrior.silence_of_salah_engine"
    compileSdk = 36

    defaultConfig {
        minSdk = 24

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // The original plugin keeps its Kotlin sources under src/main/kotlin
    // rather than the Gradle-conventional src/main/java - preserved here.
    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
            assets.srcDirs("src/main/assets")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    testOptions {
        unitTests {
            // Robolectric (used by the Context-dependent tests, e.g.
            // EngineStateStoreTest / MlDecisionEngineTest) needs the merged
            // manifest/resources to build its simulated Android environment.
            isIncludeAndroidResources = true
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")

    // Used throughout the foreground-service task loop (TaskRunner,
    // ForegroundTaskController). Not pulled in transitively by tauri-android,
    // so it must be declared explicitly here.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    testImplementation("junit:junit:4.13.2")
    // Android's unit-test classpath ships only a stub org.json that throws
    // at runtime - this pulls in a real implementation so plain JUnit tests
    // (XGBoostInferenceTest, ScheduledAlarmTest) that touch JSONObject work
    // without needing Robolectric.
    testImplementation("org.json:json:20240303")
    // Robolectric + androidx.test give the Context-dependent tests
    // (EngineStateStoreTest, MlDecisionEngineTest) a real, in-memory Android
    // runtime (SharedPreferences-free file storage, AudioManager, etc.)
    // without needing an emulator or physical device.
    testImplementation("org.robolectric:robolectric:4.13")
    testImplementation("androidx.test:core:1.6.1")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")

    implementation(project(":tauri-android"))
}
