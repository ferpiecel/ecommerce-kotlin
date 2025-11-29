package com.shopnow.infrastructure.config

import org.flywaydb.core.Flyway
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.jdbc.datasource.DriverManagerDataSource
import javax.sql.DataSource

/**
 * Flyway Configuration
 *
 * Configures Flyway to run migrations on application startup.
 * Uses JDBC DataSource for synchronous migration execution.
 */
@Configuration
class FlywayConfig {

    @Value("\${spring.datasource.url}")
    private lateinit var datasourceUrl: String

    @Value("\${spring.datasource.username}")
    private lateinit var datasourceUsername: String

    @Value("\${spring.datasource.password}")
    private lateinit var datasourcePassword: String

    @Value("\${spring.datasource.driver-class-name}")
    private lateinit var datasourceDriver: String

    @Bean
    fun flywayDataSource(): DataSource {
        return DriverManagerDataSource().apply {
            setDriverClassName(datasourceDriver)
            url = datasourceUrl
            username = datasourceUsername
            password = datasourcePassword
        }
    }

    @Bean(initMethod = "migrate")
    fun flyway(): Flyway {
        return Flyway.configure()
            .dataSource(flywayDataSource())
            .locations("classpath:db/migration")
            .baselineOnMigrate(true)
            .baselineVersion("0")
            .schemas(
                "catalog",
                "identity",
                "shopping",
                "orders",
                "payment",
                "shipping",
                "promotion",
                "partner",
                "notification",
                "audit",
                "events"
            )
            .validateOnMigrate(true)
            .load()
    }
}
