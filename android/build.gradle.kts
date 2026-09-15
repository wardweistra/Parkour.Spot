allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Reproducible Android builds + SCA (Aikido). After Flutter/plugin Android
// dependency changes, regenerate from android/ with Java 17 or 21:
//   ./gradlew :app:assembleDebug :app:assembleRelease --write-locks
dependencyLocking {
    lockAllConfigurations()
    lockMode.set(LockMode.LENIENT)
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
