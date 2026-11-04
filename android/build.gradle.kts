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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
subprojects {
    if (name == "flutter_dnd") {
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<com.android.build.api.dsl.LibraryExtension>("android") {
                namespace = "com.example.flutter_dnd"
            }
        }
    }
}

// Force all Kotlin compile tasks across all subprojects (including Flutter plugins)
// to use JVM 17, fixing the home_widget error:
// "Cannot inline bytecode built with JVM target 11 into bytecode being built with JVM target 1.8"
// The Java/Kotlin consistency check is handled via kotlin.jvm.target.validation.mode in gradle.properties.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}
