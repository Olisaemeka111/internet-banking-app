package com.javatodev.finance.configuration;
package com.javatodev.finance.configuration;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.gateway.filter.ratelimit.KeyResolver;
import org.springframework.cloud.gateway.filter.ratelimit.RedisRateLimiter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.http.server.reactive.ServerHttpResponse;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.reactive.CorsWebFilter;
import org.springframework.web.cors.reactive.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.reactive.HiddenHttpMethodFilter;
import org.springframework.web.server.ServerWebExchange;
import org.springframework.web.server.WebFilter;
import org.springframework.web.server.WebFilterChain;
import reactor.core.publisher.Mono;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

@Configuration
public class GatewayConfiguration {

    @Value("${rate.limit.requests.per.second:10}")
    private int requestsPerSecond;

    @Value("${rate.limit.burst.capacity:20}")
    private int burstCapacity;

    @Value("${cors.allowed.origins:*}")
    private String allowedOrigins;

    @Bean
    public RedisRateLimiter redisRateLimiter() {
        return new RedisRateLimiter(requestsPerSecond, burstCapacity);
    }

    @Bean
    public KeyResolver ipKeyResolver() {
        return exchange -> Mono.just(exchange.getRequest().getRemoteAddress().getHostString());
    }

    @Bean
    public CorsWebFilter corsWebFilter() {
        CorsConfiguration corsConfig = new CorsConfiguration();

        // Parse allowed origins from property
        List<String> allowedOriginsList = Arrays.asList(allowedOrigins.split(","));
        corsConfig.setAllowedOrigins(allowedOriginsList);

        corsConfig.setMaxAge(8000L);
        corsConfig.setAllowCredentials(true);
        corsConfig.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        corsConfig.setAllowedHeaders(Arrays.asList(
                HttpHeaders.AUTHORIZATION,
                HttpHeaders.CONTENT_TYPE,
                HttpHeaders.ACCEPT,
                "X-Requested-With",
                "X-XSRF-TOKEN"
        ));

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", corsConfig);

        return new CorsWebFilter(source);
    }

    @Bean
    public WebFilter responseHeadersFilter() {
        return (ServerWebExchange exchange, WebFilterChain chain) -> {
            ServerHttpResponse response = exchange.getResponse();
            HttpHeaders headers = response.getHeaders();

            // Security headers
            headers.add("X-Content-Type-Options", "nosniff");
            headers.add("X-Frame-Options", "DENY");
            headers.add("X-XSS-Protection", "1; mode=block");
            headers.add("Content-Security-Policy", "default-src 'self'; script-src 'self'; object-src 'none'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'");
            headers.add("Strict-Transport-Security", "max-age=31536000; includeSubDomains; preload");
            headers.add("Referrer-Policy", "strict-origin-when-cross-origin");
            headers.add("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
            headers.add("Pragma", "no-cache");

            return chain.filter(exchange);
        };
    }

    @Bean
    public WebFilter requestValidationFilter() {
        return (ServerWebExchange exchange, WebFilterChain chain) -> {
            ServerHttpRequest request = exchange.getRequest();

            // Simple request validation
            String contentType = request.getHeaders().getFirst(HttpHeaders.CONTENT_TYPE);
            if (request.getMethod() == HttpMethod.POST || request.getMethod() == HttpMethod.PUT) {
                if (contentType == null || (!contentType.contains("application/json") && 
                                          !contentType.contains("application/x-www-form-urlencoded"))) {
                    ServerHttpResponse response = exchange.getResponse();
                    response.setStatusCode(HttpStatus.UNSUPPORTED_MEDIA_TYPE);
                    return response.setComplete();
                }
            }

            return chain.filter(exchange);
        };
    }

    @Bean
    public HiddenHttpMethodFilter hiddenHttpMethodFilter() {
        return new HiddenHttpMethodFilter();
    }
}
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.security.Principal;

import reactor.core.publisher.Mono;

@Configuration
public class GatewayConfiguration {

    private static final String HTTP_HEADER_AUTH_USER_ID = "X-Auth-Id";
    private static final String UNAUTHORIZED_USER_NAME = "SYSTEM USER";

    @Bean
    public GlobalFilter customGlobalFilter() {
        return (exchange, chain) -> exchange.getPrincipal().map(Principal::getName).defaultIfEmpty(UNAUTHORIZED_USER_NAME).map(principal -> {
            // adds header to proxied request
            exchange.getRequest().mutate()
                .header(HTTP_HEADER_AUTH_USER_ID, principal)
                .build();
            return exchange;
        }).flatMap(chain::filter).then(Mono.fromRunnable(() -> {

        }));
    }

}
