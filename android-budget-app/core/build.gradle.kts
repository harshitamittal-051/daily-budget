plugins { id("org.jetbrains.kotlin.jvm") version "2.0.20" }
dependencies {
    testImplementation(kotlin("test"))
}
tasks.test { useJUnitPlatform() }
