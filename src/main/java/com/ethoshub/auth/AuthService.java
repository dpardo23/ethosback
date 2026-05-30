package com.ethoshub.auth;

import com.ethoshub.auth.ProfileRepository.ProfileRecord;
import com.ethoshub.auth.dto.AuthResponse;
import com.ethoshub.auth.dto.LoginRequest;
import com.ethoshub.auth.dto.RegisterRequest;
import com.ethoshub.auth.model.UserRole;
import com.ethoshub.shared.AuthException;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.DeserializationFeature;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;

import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Service
class AuthService {

    private static final ObjectMapper JWT_MAPPER = new ObjectMapper()
            .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

    private final RestClient        restClient;
    private final ProfileRepository profileRepository;
    private final EmailService      emailService;
    private final String            supabaseUrl;
    private final String            anonKey;
    private final String            serviceRoleKey;

    AuthService(
            RestClient restClient,
            ProfileRepository profileRepository,
            EmailService emailService,
            @Value("${supabase.url}")              String supabaseUrl,
            @Value("${supabase.anon-key}")         String anonKey,
            @Value("${supabase.service-role-key}") String serviceRoleKey
    ) {
        this.restClient        = restClient;
        this.profileRepository = profileRepository;
        this.emailService      = emailService;
        this.supabaseUrl       = supabaseUrl;
        this.anonKey           = anonKey;
        this.serviceRoleKey    = serviceRoleKey;
    }

    // ─── Email/Password Register ──────────────────────────────────────────────

    AuthResponse register(RegisterRequest request) {
        SupabaseAdminUserResponse created = callSupabaseAdminCreateUser(request);
        String normalizedEmail = request.email().toLowerCase().trim();
        String firstName = Optional.ofNullable(request.firstName()).filter(s -> !s.isBlank()).orElse("");
        String lastName  = Optional.ofNullable(request.lastName()).filter(s -> !s.isBlank()).orElse("");

        profileRepository.provision(
                created.id(),
                normalizedEmail,
                firstName,
                lastName,
                request.role().toDbValue(),
                request.phoneCode(),
                request.phoneNumber(),
                request.countryCode(),
                "email"
        );

        emailService.sendWelcomeEmail(normalizedEmail, firstName.isBlank() ? "Usuario" : firstName);

        // Auto-login: obtain a Supabase JWT immediately so the client doesn't need
        // a separate POST /auth/login round-trip after registration.
        try {
            SupabaseTokenResponse tokenResponse = callSupabasePasswordAuth(
                    new LoginRequest(normalizedEmail, request.password()));
            SupabaseUser user = tokenResponse.user();
            String roleStr = extractRoleFromJwtClaim(tokenResponse.accessToken());
            if (roleStr == null && user.appMetadata() != null) {
                Object roleObj = user.appMetadata().get("role");
                roleStr = roleObj instanceof String s ? s : null;
            }
            UserRole role = UserRole.fromValue(roleStr != null ? roleStr : request.role().toDbValue());
            String profileId = profileRepository.findByAuthId(user.id())
                    .map(p -> p.idProfile().toString())
                    .orElse(created.id().toString());
            return new AuthResponse(tokenResponse.accessToken(), profileId, user.email(), role.name());
        } catch (Exception ignored) {
            // Registration succeeded; auto-login failed. Client falls back to POST /auth/login.
            return new AuthResponse(null, created.id().toString(), normalizedEmail, request.role().name());
        }
    }

    // ─── Email/Password Login ─────────────────────────────────────────────────

    AuthResponse login(LoginRequest request) {
        SupabaseTokenResponse tokenResponse = callSupabasePasswordAuth(request);
        SupabaseUser user = tokenResponse.user();

        // Primary: decode the JWT — app_metadata.role is always present in the claim.
        String roleStr = extractRoleFromJwtClaim(tokenResponse.accessToken());

        // Fallback: user object app_metadata (populated on Supabase Pro / self-hosted).
        if (roleStr == null && user.appMetadata() != null) {
            Object roleObj = user.appMetadata().get("role");
            roleStr = roleObj instanceof String s ? s : null;
        }

        UserRole role = UserRole.fromValue(roleStr != null ? roleStr : "professional");

        // Return the internal id_profile, not the Supabase auth_id.
        String profileId = profileRepository.findByAuthId(user.id())
                .map(p -> p.idProfile().toString())
                .orElse(user.id().toString()); // fallback: profile not yet provisioned

        return new AuthResponse(tokenResponse.accessToken(), profileId, user.email(), role.name());
    }

    /**
     * Decodes the JWT payload (Base64URL, middle segment) and extracts app_metadata.role.
     * No signature verification needed here — Spring Security already validated the token.
     */
    @SuppressWarnings("unchecked")
    private String extractRoleFromJwtClaim(String accessToken) {
        try {
            String[] parts = accessToken.split("\\.");
            if (parts.length < 2) return null;

            // Pad to a multiple of 4 for standard Base64 decoding
            String segment = parts[1];
            int pad = (4 - segment.length() % 4) % 4;
            segment = segment + "=".repeat(pad);

            byte[] decoded = Base64.getUrlDecoder().decode(segment);
            Map<String, Object> payload = JWT_MAPPER.readValue(decoded, Map.class);

            Object appMeta = payload.get("app_metadata");
            if (!(appMeta instanceof Map<?, ?> meta)) return null;

            Object role = meta.get("role");
            return role instanceof String s ? s : null;
        } catch (Exception ignored) {
            return null;
        }
    }

    // ─── OAuth Sync ───────────────────────────────────────────────────────────

    AuthResponse oauthSync(UUID authId, String email, String fullName,
                           String requestedRoleStr, String avatarUrl,
                           String provider, boolean isNewRegistration) {
        Optional<ProfileRecord> existing = profileRepository.findByAuthId(authId);
        UserRole role;
        String   profileId;

        if (existing.isPresent()) {
            ProfileRecord profile = existing.get();
            role      = profile.role();
            profileId = profile.idProfile().toString();
        } else {
            // Reject login attempts for accounts that don't exist yet.
            if (!isNewRegistration) {
                throw new AuthException(
                        "No account found for this OAuth identity. Please register first.",
                        HttpStatus.NOT_FOUND);
            }

            role = requestedRoleStr != null
                    ? UserRole.fromValue(requestedRoleStr)
                    : UserRole.PROFESSIONAL;

            String[] parts = (fullName != null && !fullName.isBlank())
                    ? fullName.split(" ", 2)
                    : new String[]{"", ""};
            String firstName = parts[0].isBlank() ? email.split("@")[0] : parts[0];
            String lastName  = parts.length > 1 ? parts[1] : "";

            String resolvedProvider = (provider != null && !provider.isBlank()) ? provider : "email";
            profileRepository.provision(authId, email, firstName, lastName,
                    role.toDbValue(), null, null, null, resolvedProvider);

            profileId = profileRepository.findByAuthId(authId)
                    .map(p -> p.idProfile().toString())
                    .orElse(authId.toString());

            emailService.sendWelcomeEmail(email, firstName.isBlank() ? "Usuario" : firstName);
        }

        if (avatarUrl != null && !avatarUrl.isBlank()) {
            profileRepository.updatePhoto(authId, avatarUrl);
        }

        updateSupabaseAppMetadata(authId, role);

        return new AuthResponse(null, profileId, email, role.name());
    }

    private void updateSupabaseAppMetadata(UUID authId, UserRole role) {
        try {
            restClient.put()
                    .uri(supabaseUrl + "/auth/v1/admin/users/" + authId)
                    .header("apikey",        serviceRoleKey)
                    .header("Authorization", "Bearer " + serviceRoleKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of("app_metadata", Map.of("role", role.toDbValue())))
                    .retrieve()
                    .toBodilessEntity();
        } catch (Exception ignored) {
        }
    }

    // ─── Supabase Admin API ──────────────────────────────────────────────────

    private SupabaseAdminUserResponse callSupabaseAdminCreateUser(RegisterRequest request) {
        try {
            SupabaseAdminUserResponse response = restClient.post()
                    .uri(supabaseUrl + "/auth/v1/admin/users")
                    .header("apikey",        serviceRoleKey)
                    .header("Authorization", "Bearer " + serviceRoleKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(buildAdminCreateUserBody(request))
                    .retrieve()
                    .body(SupabaseAdminUserResponse.class);

            if (response == null || response.id() == null) {
                throw new AuthException("Supabase Auth user creation returned empty response",
                        HttpStatus.INTERNAL_SERVER_ERROR);
            }
            return response;

        } catch (HttpClientErrorException ex) {
            translateSupabaseRegisterError(ex);
            throw ex;
        }
    }

    private Map<String, Object> buildAdminCreateUserBody(RegisterRequest req) {
        Map<String, Object> userMeta = new HashMap<>();
        userMeta.put("role", req.role().toDbValue());
        Optional.ofNullable(req.firstName()).filter(v -> !v.isBlank())
                .ifPresent(v -> userMeta.put("first_name", v));
        Optional.ofNullable(req.lastName()).filter(v -> !v.isBlank())
                .ifPresent(v -> userMeta.put("last_name", v));
        Optional.ofNullable(req.phoneNumber()).filter(v -> !v.isBlank())
                .ifPresent(v -> userMeta.put("phone_number", v));
        Optional.ofNullable(req.countryCode()).filter(v -> !v.isBlank())
                .ifPresent(v -> userMeta.put("country_code", v));

        Map<String, Object> appMeta = new HashMap<>();
        appMeta.put("role", req.role().toDbValue());

        Map<String, Object> body = new HashMap<>();
        body.put("email",         req.email().toLowerCase().trim());
        body.put("password",      req.password());
        body.put("email_confirm", true);
        body.put("user_metadata", userMeta);
        body.put("app_metadata",  appMeta);
        return body;
    }

    private void translateSupabaseRegisterError(HttpClientErrorException ex) {
        int    status = ex.getStatusCode().value();
        String body   = ex.getResponseBodyAsString();
        if (status == 422 && (body.contains("already registered") || body.contains("email_exists"))) {
            throw new AuthException("An account with this email already exists", HttpStatus.CONFLICT);
        }
        if (status == 422) {
            throw new AuthException("Registration data is invalid", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        if (status == 400) {
            throw new AuthException("Bad registration request", HttpStatus.BAD_REQUEST);
        }
    }

    // ─── Supabase Password Auth ──────────────────────────────────────────────

    private SupabaseTokenResponse callSupabasePasswordAuth(LoginRequest request) {
        try {
            SupabaseTokenResponse response = restClient.post()
                    .uri(supabaseUrl + "/auth/v1/token?grant_type=password")
                    .header("apikey", anonKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of(
                            "email",    request.email().toLowerCase().trim(),
                            "password", request.password()
                    ))
                    .retrieve()
                    .body(SupabaseTokenResponse.class);

            if (response == null || response.accessToken() == null) {
                throw new AuthException("Authentication response is missing the access token",
                        HttpStatus.INTERNAL_SERVER_ERROR);
            }
            return response;

        } catch (HttpClientErrorException ex) {
            translateSupabaseLoginError(ex);
            throw ex;
        }
    }

    private void translateSupabaseLoginError(HttpClientErrorException ex) {
        int status = ex.getStatusCode().value();
        if (status == 400 || status == 422) {
            throw new AuthException("Invalid email or password", HttpStatus.UNAUTHORIZED);
        }
        if (status == 429) {
            throw new AuthException("Too many login attempts. Please wait before retrying.",
                    HttpStatus.TOO_MANY_REQUESTS);
        }
    }

    // ─── Supabase API response shapes ────────────────────────────────────────

    @JsonIgnoreProperties(ignoreUnknown = true)
    record SupabaseAdminUserResponse(
            UUID   id,
            String email
    ) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    record SupabaseTokenResponse(
            @com.fasterxml.jackson.annotation.JsonProperty("access_token") String accessToken,
            @com.fasterxml.jackson.annotation.JsonProperty("token_type")   String tokenType,
            @com.fasterxml.jackson.annotation.JsonProperty("expires_in")   int    expiresIn,
            SupabaseUser user
    ) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    record SupabaseUser(
            UUID   id,
            String email,
            @com.fasterxml.jackson.annotation.JsonProperty("app_metadata") Map<String, Object> appMetadata
    ) {}
}
