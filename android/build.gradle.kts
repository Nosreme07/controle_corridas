import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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

// --- BLOCO DE CORREÇÕES (NAMESPACE + JVM TARGET + COMPILE SDK) ---
subprojects {
    // Ação unificada que será executada após a avaliação
    val applyFixesAction = {
        // 1. Correção do Namespace (para o plugin flutter_notification_listener)
        if (project.name == "flutter_notification_listener") {
            try {
                val android = project.extensions.findByName("android")
                if (android != null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(android, "im.zoe.labs.flutter_notification_listener")
                    println("DOMEX FIX: Namespace aplicado com sucesso!")
                }
            } catch (e: Exception) {
                println("DOMEX FIX: Erro ao aplicar namespace: $e")
            }
        }

        // 2. Correção de compileSdkVersion e JVM
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    // Configura compileSdkVersion para 34
                    val setCompileSdkVersion = android.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                    setCompileSdkVersion.invoke(android, 34)
                    
                    // Configura Java para versão 17
                    val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                    compileOptions.javaClass.getMethod("setSourceCompatibility", org.gradle.api.JavaVersion::class.java)
                        .invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
                    compileOptions.javaClass.getMethod("setTargetCompatibility", org.gradle.api.JavaVersion::class.java)
                        .invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
                    
                    println("DOMEX FIX: compileSdk 34 e Java 17 configurados para ${project.name}")
                } catch (e: Exception) {
                    println("DOMEX FIX: Erro ao configurar Android: ${e.message}")
                }
            }
        }
    }

    // Executa a ação apenas se o projeto ainda não foi avaliado
    if (project.state.executed) {
        applyFixesAction()
    } else {
        project.afterEvaluate {
            applyFixesAction()
        }
    }

    // 3. Força o Kotlin a usar JVM 17
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}