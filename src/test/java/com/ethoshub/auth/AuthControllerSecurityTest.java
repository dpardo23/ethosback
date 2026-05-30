package com.ethoshub.auth;

// [RED] Tests that pin the SecurityFilterChain contract for /auth/* endpoints:
//   - /auth/oauth/sync requires Bearer token → 401 with ApiResponse envelope
//   - /auth/register and /auth/login are public → no 401
//   - Anti-cache headers present on all auth responses
//
// NOTE: Spring Boot 4.x relocated @WebMvcTest to:
//   org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest

import com.ethoshub.auth.dto.AuthResponse;
import com.ethoshub.auth.dto.LoginRequest;
import com.ethoshub.auth.dto.RegisterRequest;
import com.ethoshub.auth.model.UserRole;
import com.ethoshub.config.CorsConfig;
import com.ethoshub.config.NoCacheFilter;
import com.ethoshub.config.SecurityConfig;
import com.ethoshub.shared.GlobalExceptionHandler;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Map;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(AuthController.class)
@Import({SecurityConfig.class, CorsConfig.class, NoCacheFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = {
    "cors.allowed-origins=http://localhost",
    "supabase.url=https://test.supabase.co",
    "supabase.anon-key=test-anon",
    "supabase.service-role-key=test-service"
})
class AuthControllerSecurityTest {

    @Autowired MockMvc mockMvc;

    // ObjectMapper created locally — @WebMvcTest slice in SB 4.x does not expose it as a bean.
    private final ObjectMapper objectMapper = new ObjectMapper()
            .disable(SerializationFeature.FAIL_ON_EMPTY_BEANS);

    @MockitoBean AuthService authService;
    @MockitoBean JwtDecoder  jwtDecoder;  // prevents Spring from hitting Supabase JWKS in tests

    // ── 401 contract ─────────────────────────────────────────────────────────

    @Test
    void oauthSync_noToken_returns401WithApiResponseEnvelope() throws Exception {
        mockMvc.perform(post("/auth/oauth/sync")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.status").value(401));
    }

    @Test
    void oauthSync_withValidProfessionalJwt_returns200() throws Exception {
        UUID authId = UUID.randomUUID();
        when(authService.oauthSync(any(), any(), any(), any()))
                .thenReturn(new AuthResponse(null, UUID.randomUUID().toString(),
                        "u@test.com", UserRole.PROFESSIONAL.name()));

        mockMvc.perform(post("/auth/oauth/sync")
                        .with(jwt().jwt(j -> j
                                .subject(authId.toString())
                                .claim("email", "u@test.com")
                                .claim("app_metadata", Map.of("role", "professional"))))
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.role").value("PROFESSIONAL"));
    }

    @Test
    void oauthSync_withRecruiterJwt_returns200WithRecruiterRole() throws Exception {
        UUID authId = UUID.randomUUID();
        when(authService.oauthSync(any(), any(), any(), any()))
                .thenReturn(new AuthResponse(null, UUID.randomUUID().toString(),
                        "r@test.com", UserRole.RECRUITER.name()));

        mockMvc.perform(post("/auth/oauth/sync")
                        .with(jwt().jwt(j -> j
                                .subject(authId.toString())
                                .claim("email", "r@test.com")
                                .claim("app_metadata", Map.of("role", "recruiter"))))
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.role").value("RECRUITER"));
    }

    // ── Public endpoints accept requests without a Bearer token ──────────────

    @Test
    void register_publicEndpoint_noAuth_returns201() throws Exception {
        RegisterRequest req = new RegisterRequest(
                "user@test.com", "password123!", UserRole.PROFESSIONAL,
                "Juan", "Pérez", null, null);

        mockMvc.perform(post("/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isCreated());
    }

    @Test
    void login_publicEndpoint_noAuth_returns200() throws Exception {
        when(authService.login(any()))
                .thenReturn(new AuthResponse("tok", UUID.randomUUID().toString(),
                        "user@test.com", UserRole.PROFESSIONAL.name()));

        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new LoginRequest("user@test.com", "password123!"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.token").value("tok"));
    }

    // ── Anti-cache headers ────────────────────────────────────────────────────

    @Test
    void authEndpoints_alwaysReturnNoCacheHeaders() throws Exception {
        RegisterRequest req = new RegisterRequest(
                "cache@test.com", "password123!", UserRole.RECRUITER,
                "Ana", "López", null, null);

        mockMvc.perform(post("/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(header().string("Cache-Control",
                        "no-cache, no-store, max-age=0, must-revalidate"))
                .andExpect(header().string("Pragma", "no-cache"))
                .andExpect(header().string("Expires", "0"));
    }

    // ── Conflict → 409 ──────────────────────────────────────────────────────

    @Test
    void register_duplicateEmail_returns409WithApiResponseEnvelope() throws Exception {
        RegisterRequest req = new RegisterRequest(
                "existing@test.com", "password123!", UserRole.PROFESSIONAL,
                "Juan", "Pérez", null, null);

        org.mockito.Mockito.doThrow(new com.ethoshub.shared.AuthException(
                "An account with this email already exists",
                org.springframework.http.HttpStatus.CONFLICT))
                .when(authService).register(any());

        mockMvc.perform(post("/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.message").value("An account with this email already exists"));
    }

    // ── Bean validation → 400, not 500 ───────────────────────────────────────

    @Test
    void register_invalidEmail_returns400WithErrors() throws Exception {
        String body = """
                {"email":"not-an-email","password":"password123!","role":"PROFESSIONAL",
                 "firstName":"X","lastName":"Y"}""";

        mockMvc.perform(post("/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.errors").isArray());
    }

    @Test
    void login_missingFields_returns400() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }
}
