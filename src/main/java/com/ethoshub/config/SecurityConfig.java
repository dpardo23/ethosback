package com.ethoshub.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .cors(Customizer.withDefaults()) // Le dice a Security que respete tu CorsConfig.java
            .csrf(csrf -> csrf.disable())    // Desactiva CSRF (necesario para APIs REST modernas)
            .authorizeHttpRequests(authz -> authz
                // Hacemos públicos el ping y la documentación de Swagger:
                .requestMatchers("/api/ping", "/swagger-ui/**", "/v3/api-docs/**", "/swagger-ui.html").permitAll()
                // Cualquier otra ruta en el futuro exigirá un token válido:
                .anyRequest().authenticated()
            )
            // Habilita la validación de tokens JWT usando tu SUPABASE_JWKS_URI del application.yml
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()));

        return http.build();
    }
}