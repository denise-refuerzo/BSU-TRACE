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

// --- FIX FOR OUTDATED PLUGINS (AGP 8.0+ Namespace Issue) ---
subprojects {
    afterEvaluate {
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            try {
                val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(androidExt)
                
                if (currentNamespace == null) {
                    val manifestFile = project.file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val content = manifestFile.readText()
                        val match = Regex("""package="([^"]+)"""").find(content)
                        if (match != null) {
                            val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                            setNamespace.invoke(androidExt, match.groupValues[1])
                        }
                    }
                }
            } catch (e: Exception) {
                // Ignore errors
            }
        }
    }
}

// --- FIX FOR JVM TARGET INCONSISTENCY (BUMPED TO 17) ---
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

// Forced evaluation MUST come after the hooks are registered
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}