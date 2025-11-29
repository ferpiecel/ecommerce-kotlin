package com.shopnow.infrastructure.config

import io.swagger.v3.oas.models.OpenAPI
import io.swagger.v3.oas.models.info.Contact
import io.swagger.v3.oas.models.info.Info
import io.swagger.v3.oas.models.info.License
import io.swagger.v3.oas.models.servers.Server
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration

/**
 * OpenAPI/Swagger Configuration
 *
 * Provides API documentation at /swagger-ui.html
 */
@Configuration
class OpenApiConfig {

    @Bean
    fun customOpenAPI(): OpenAPI {
        return OpenAPI()
            .info(
                Info()
                    .title("ShopNow E-Commerce API")
                    .version("1.0.0")
                    .description(
                        """
                        ShopNow E-Commerce Platform API

                        This API follows Domain-Driven Design (DDD) principles with bounded contexts:
                        - **Catalog**: Product catalog and inventory management
                        - **Identity**: User authentication and authorization
                        - **Shopping**: Shopping carts, wishlists, and reviews
                        - **Orders**: Order management and lifecycle
                        - **Payment**: Payment processing and transactions
                        - **Shipping**: Shipment tracking and delivery
                        - **Promotion**: Discounts, coupons, and campaigns
                        - **Partner**: Partner and affiliate management
                        - **Notification**: User notifications and alerts
                        - **Audit**: Audit logging and compliance

                        Built with:
                        - Spring Boot 3.4.0
                        - Kotlin 2.1.0
                        - Spring WebFlux (Reactive)
                        - R2DBC (Reactive Database)
                        - PostgreSQL 17
                        - Redis 7
                        """.trimIndent()
                    )
                    .contact(
                        Contact()
                            .name("ShopNow Team")
                            .email("api@shopnow.com")
                    )
                    .license(
                        License()
                            .name("Apache 2.0")
                            .url("https://www.apache.org/licenses/LICENSE-2.0")
                    )
            )
            .servers(
                listOf(
                    Server()
                        .url("http://localhost:8080")
                        .description("Local Development Server"),
                    Server()
                        .url("https://api.shopnow.com")
                        .description("Production Server")
                )
            )
    }
}
