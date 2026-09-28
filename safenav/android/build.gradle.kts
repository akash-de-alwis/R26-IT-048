buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Align every plugin module (tflite_flutter, audioplayers_android,
// camera_android, ...) on JVM 17 for both Java and Kotlin, matching :app.
// Some plugins pin Java 1.8 while Kotlin defaults to the build JDK, which
// fails with "Inconsistent JVM-target compatibility".
//
// Plugins load their own AGP / Kotlin Gradle plugin classes, so the
// extensions and tasks are configured dynamically instead of by type.
// This block must stay BEFORE evaluationDependsOn(":app") below, so the
// hooks are registered before any subproject is evaluated.
subprojects {
    val alignJava17: Project.() -> Unit = {
        if (plugins.hasPlugin("com.android.library")) {
            try {
                extensions.findByName("android")?.withGroovyBuilder {
                    "compileOptions" {
                        setProperty("sourceCompatibility", JavaVersion.VERSION_17)
                        setProperty("targetCompatibility", JavaVersion.VERSION_17)
                    }
                }
            } catch (e: Exception) {
                logger.warn("Could not set Java 17 on $path: $e")
            }
        }
    }
    // Registered here, before the subproject applies AGP, so this hook runs
    // after the plugin's own android { compileOptions { ... } } block but
    // before AGP's own afterEvaluate finalizes the DSL.
    if (state.executed) alignJava17() else afterEvaluate { alignJava17() }

    tasks.configureEach {
        if (!javaClass.name.startsWith("org.jetbrains.kotlin.gradle.tasks.KotlinCompile")) {
            return@configureEach
        }
        val task = this
        try {
            val jvmTargetClass = Class.forName(
                "org.jetbrains.kotlin.gradle.dsl.JvmTarget", true, task.javaClass.classLoader,
            )
            val jvm17 = jvmTargetClass.enumConstants.first { (it as Enum<*>).name == "JVM_17" }
            val compilerOptions = task.withGroovyBuilder { getProperty("compilerOptions") }
            @Suppress("UNCHECKED_CAST")
            val jvmTarget = compilerOptions.withGroovyBuilder { getProperty("jvmTarget") }
                as org.gradle.api.provider.Property<Any>
            jvmTarget.set(jvm17)
        } catch (e: Exception) {
            logger.warn("Could not set jvmTarget 17 on ${task.path}: $e")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
