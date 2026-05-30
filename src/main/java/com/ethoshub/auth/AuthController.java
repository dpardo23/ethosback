package com.ethoshub.auth;

import com.ethoshub.auth.dto.AuthResponse;
import com.ethoshub.auth.dto.LoginRequest;
import com.ethoshub.auth.dto.OAuthSyncRequest;
import com.ethoshub.auth.dto.RegisterRequest;
import com.ethoshub.shared.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/auth")
@Tag(name = "Authentication", description = "Register, login and OAuth sync")
class AuthController {

    private final AuthService authService;

    AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    @Operation(summary = "Register a new user",
               description = "Creates a Supabase Auth user, provisions the profile, and returns a JWT for immediate login.")
    ResponseEntity<ApiResponse<AuthResponse>> register(
            @Valid @RequestBody RegisterRequest request
    ) {
        AuthResponse authResponse = authService.register(request);
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(ApiResponse.created(authResponse, "Account created successfully."));
    }

    @PostMapping("/login")
    @Operation(summary = "Authenticate with email and password",
               description = "Validates credentials via Supabase Auth and returns a JWT access token.")
    ResponseEntity<ApiResponse<AuthResponse>> login(
            @Valid @RequestBody LoginRequest request
    ) {
        AuthResponse authResponse = authService.login(request);
        return ResponseEntity.ok(ApiResponse.ok(authResponse, "Login successful"));
    }

    @PostMapping("/oauth/sync")
    @Operation(
        summary = "Sync OAuth user profile",
        description = "Called after Supabase OAuth flow. Ensures core.profiles exists with correct role and updates app_metadata.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    ResponseEntity<ApiResponse<AuthResponse>> syncOAuthUser(
            @AuthenticationPrincipal Jwt jwt,
            @RequestBody(required = false) OAuthSyncRequest request
    ) {
        UUID    authId            = UUID.fromString(jwt.getSubject());
        String  email             = jwt.getClaimAsString("email");
        String  fullName          = extractFullName(jwt);
        String  role              = request != null ? request.role()              : null;
        String  avatarUrl         = extractAvatarUrl(jwt);
        String  provider          = extractProvider(jwt);
        boolean isNewRegistration = request != null && request.isNewRegistration();

        AuthResponse authResponse = authService.oauthSync(
                authId, email, fullName, role, avatarUrl, provider, isNewRegistration);
        return ResponseEntity.ok(ApiResponse.ok(authResponse, "OAuth sync successful"));
    }

    private String extractFullName(Jwt jwt) {
        Object raw = jwt.getClaim("user_metadata");
        if (!(raw instanceof Map<?, ?> meta)) return "";
        Object fn = meta.get("full_name");
        if (fn == null) fn = meta.get("name");
        return fn != null ? fn.toString() : "";
    }

    private String extractAvatarUrl(Jwt jwt) {
        Object raw = jwt.getClaim("user_metadata");
        if (!(raw instanceof Map<?, ?> meta)) return null;
        Object pic = meta.get("avatar_url");
        if (pic == null) pic = meta.get("picture");
        return pic instanceof String s && !s.isBlank() ? s : null;
    }

    private String extractProvider(Jwt jwt) {
        Object raw = jwt.getClaim("app_metadata");
        if (!(raw instanceof Map<?, ?> meta)) return "email";
        Object prov = meta.get("provider");
        return prov instanceof String s && !s.isBlank() ? s : "email";
    }
}
