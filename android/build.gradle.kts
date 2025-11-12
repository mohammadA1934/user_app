buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // 🔴 هذا السطر يجب إضافته لتمكين Firebase
        classpath("com.google.gms:google-services:4.4.1") // يمكنك استخدام أحدث إصدار
    }
}

// ----------------------------------------------------
// ✅ الكود الأصلي الذي أرسلته (يجب وضعه هنا تحت buildscript)
// ----------------------------------------------------

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