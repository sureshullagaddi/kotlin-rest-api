package com.rest.api.config

import org.flywaydb.core.Flyway
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.flyway.FlywayProperties
import org.springframework.boot.context.properties.EnableConfigurationProperties
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import javax.sql.DataSource

/**
 * Flyway Configuration for database migrations.
 * 
 * This configuration enables automatic database schema migration
 * using Flyway migrations located in src/main/resources/db/migration/
 * 
 * Migrations are applied automatically on application startup in this order:
 * 1. V1.0__initial_schema.sql - Creates tables for products, users, audit_log
 * 2. V1.1__add_audit_triggers.sql - Adds PostgreSQL triggers for audit logging
 */
@Configuration
@EnableConfigurationProperties(FlywayProperties::class)
class FlywayConfig(
    @Value("\${spring.flyway.enabled:true}")
    private val flywayEnabled: Boolean,
    
    @Value("\${spring.flyway.baseline-on-migrate:true}")
    private val baselineOnMigrate: Boolean
) {

    /**
     * Configure and initialize Flyway bean.
     * 
     * This bean is automatically invoked during Spring Boot startup
     * to run pending migrations.
     */
    @Bean
    fun flyway(dataSource: DataSource): Flyway {
        return Flyway.configure()
            .dataSource(dataSource)
            .locations("classpath:db/migration")
            .baselineOnMigrate(baselineOnMigrate)
            .validateOnMigrate(true)
            .outOfOrder(false)
            .load()
            .also { flyway ->
                if (flywayEnabled) {
                    flyway.migrate()
                }
            }
    }
}

