plugins {
    id("org.springframework.boot") version "3.1.0"
    id("io.spring.dependency-management") version "1.1.0"
    kotlin("jvm") version "1.9.0"
    kotlin("plugin.spring") version "1.9.0"
    id("org.jetbrains.kotlin.plugin.jpa") version "1.9.0"
}

group = "com.example"
version = "0.0.1-SNAPSHOT"
java.sourceCompatibility = JavaVersion.VERSION_17

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    kotlinOptions {
        jvmTarget = "17"
    }
}


repositories {
    mavenCentral()
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    
    // PostgreSQL driver
    implementation("org.postgresql:postgresql:42.7.2")
    
    // Flyway for database migrations
    implementation("org.flywaydb:flyway-core:9.22.3")
    
    // Actuator for health checks (Kubernetes probes)
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    
    // Spring Security
    implementation("org.springframework.boot:spring-boot-starter-security")
    
    // OAuth2 Client for OIDC support (production)
    implementation("org.springframework.security:spring-security-oauth2-client:6.1.0")
    
    // For testing with containers
    testImplementation("org.testcontainers:testcontainers:1.19.3")
    testImplementation("org.testcontainers:postgresql:1.19.3")
    
    // H2 for local development and testing
    runtimeOnly("com.h2database:h2")
    
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.security:spring-security-test")
}

tasks.withType<org.springframework.boot.gradle.tasks.bundling.BootJar> {
    mainClass.set("com.rest.api.DemoApplicationKt")
}

