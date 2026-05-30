package com.ethoshub.config;

import com.ethoshub.auth.model.UserRole;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.MediaType;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;

import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    /**
     * Supabase JWT secret (for HS256 projects).
     * Obtain from: Supabase Dashboard → Settings → API → JWT Settings → JWT Secret.
     * Leave empty ("") if your project uses RS256 — Spring will use jwk-set-uri instead.
     */
    @Value("${supabase.jwt-secret:}")
    private String supabaseJwtSecret;

    @Value("${spring.security.oauth2.resourceserver.jwt.jwk-set-uri:}")
    private String jwkSetUri;

    private static final String[] PUBLIC_PATHS = {
            "/auth/register",
            "/auth/login",
            "/api/ping",
            "/error",           // Spring forwards unmatched routes here — must be public to avoid 401 on 404s
            "/actuator/health",
            "/swagger-ui/**",
            "/swagger-ui.html",
            "/v3/api-docs/**"
    };

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .cors(Customizer.withDefaults())
                .csrf(csrf -> csrf.disable())
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(authz -> authz
                        // Public: credential auth + Spring infrastructure
                        .requestMatchers(PUBLIC_PATHS).permitAll()
                        // /auth/oauth/sync is intentionally authenticated:
                        // the caller must present a valid Supabase Bearer token.
                        .anyRequest().authenticated()
                )
                .oauth2ResourceServer(oauth2 -> oauth2
                        .jwt(jwt -> jwt.jwtAuthenticationConverter(supabaseJwtConverter()))
                        // 401 — token missing, expired, or invalid signature
                        .authenticationEntryPoint((request, response, ex) -> {
                            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                            response.getWriter().write(
                                    "{\"success\":false,\"status\":401,\"message\":\"Unauthorized: " +
                                    ex.getMessage().replace("\"", "'") + "\"}"
                            );
                        })
                )
                // 403 — authenticated but insufficient role
                .exceptionHandling(ex -> ex
                        .accessDeniedHandler((request, response, accessDeniedException) -> {
                            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
                            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                            response.getWriter().write(
                                    "{\"success\":false,\"status\":403,\"message\":\"Forbidden: insufficient role\"}"
                            );
                        })
                );

        return http.build();
    }

    /**
     * Provides the JwtDecoder that Spring Security's resource server uses.
     *
     * - If supabase.jwt-secret is set: HS256 (symmetric) — common for default Supabase projects.
     * - Otherwise: RS256 via JWKS — required when the Supabase project uses RS256 signing.
     *
     * To determine which algorithm your project uses:
     *   Supabase Dashboard → Settings → API → JWT Settings → JWT Algorithm
     */
    @Bean
    public JwtDecoder jwtDecoder() {
        if (supabaseJwtSecret != null && !supabaseJwtSecret.isBlank()) {
            SecretKeySpec key = new SecretKeySpec(
                    supabaseJwtSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            return NimbusJwtDecoder.withSecretKey(key)
                    .macAlgorithm(MacAlgorithm.HS256)
                    .build();
        }
        if (jwkSetUri != null && !jwkSetUri.isBlank()) {
            return NimbusJwtDecoder.withJwkSetUri(jwkSetUri).build();
        }
        throw new IllegalStateException(
                "JWT validation is not configured: set either supabase.jwt-secret (HS256) " +
                "or spring.security.oauth2.resourceserver.jwt.jwk-set-uri (RS256)");
    }

    @Bean
    public JwtAuthenticationConverter supabaseJwtConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();

        /*
         * Supabase JWT structure:
         *   app_metadata.role = "professional" | "recruiter" | "admin"
         * This block extracts that claim and maps it to Spring Security authorities.
         */
        converter.setJwtGrantedAuthoritiesConverter(jwt -> {
            Object appMetaRaw = jwt.getClaim("app_metadata");

            String roleValue = Optional.ofNullable(appMetaRaw)
                    .filter(o -> o instanceof Map<?, ?>)
                    .map(o -> ((Map<?, ?>) o).get("role"))
                    .map(Object::toString)
                    .orElse(null);

            if (roleValue == null) {
                return List.of(new SimpleGrantedAuthority(UserRole.PROFESSIONAL.toSpringAuthority()));
            }

            try {
                UserRole role = UserRole.fromValue(roleValue);
                return List.of(new SimpleGrantedAuthority(role.toSpringAuthority()));
            } catch (IllegalArgumentException ignored) {
                return List.of(new SimpleGrantedAuthority(UserRole.PROFESSIONAL.toSpringAuthority()));
            }
        });

        return converter;
    }
}
