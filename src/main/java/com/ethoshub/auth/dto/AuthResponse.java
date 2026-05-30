package com.ethoshub.auth.dto;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "Authentication result returned after successful login")
public record AuthResponse(

    @Schema(description = "Supabase JWT access token (Bearer)", example = "eyJhbGciOiJIUzI1...")
    String token,

    @Schema(description = "Internal profile UUID (id_profile in public.profile)", example = "550e8400-e29b-41d4-a716-446655440000")
    String profileId,

    @Schema(description = "Authenticated user email", example = "user@example.com")
    String email,

    @Schema(description = "Business role in uppercase", example = "PROFESSIONAL")
    String role
) {}
