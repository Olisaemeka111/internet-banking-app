package com.javatodev.finance.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.web.server.SecurityWebFilterChain;

@Configuration
public class SecurityConfig {

    @Bean
    public SecurityWebFilterChain securityWebFilterChain(ServerHttpSecurity http) {
        return http
                .csrf().disable() // API Gateway uses token-based auth, so CSRF is not needed
                .httpBasic().disable()
                .formLogin().disable()
                .authorizeExchange()
                    // Allow actuator endpoints for monitoring
                    .pathMatchers("/actuator/**").permitAll()
                    // Allow authentication endpoints
                    .pathMatchers("/api/v1/auth/**").permitAll()
                    // Public documentation
                    .pathMatchers("/api/v1/docs/**").permitAll()
                    .pathMatchers("/swagger-ui/**").permitAll()
                    // Require authentication for all other requests
                    .anyExchange().authenticated()
                .and()
                // Add OAuth2 resource server support
                .oauth2ResourceServer()
                    .jwt()
                .and().and()
                // Add additional security headers
                .headers()
                    .frameOptions().deny()
                    .xssProtection().disable() // We'll handle this in our custom filter
                    .contentSecurityPolicy("default-src 'self'; script-src 'self'; object-src 'none'")
                .and()
                .build();
    }
}
