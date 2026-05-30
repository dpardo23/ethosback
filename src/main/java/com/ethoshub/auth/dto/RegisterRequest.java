package com.ethoshub.auth.dto;

import com.ethoshub.auth.model.UserRole;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

@Schema(description = "Payload for local email/password registration")
public record RegisterRequest(

    @Schema(description = "User email address", example = "user@example.com")
    @NotBlank(message = "email is required")
    @Email(message = "email must be a valid address")
    String email,

    @Schema(description = "Password (minimum 8 characters)", example = "S3cur3P@ss!")
    @NotBlank(message = "password is required")
    @Size(min = 8, message = "password must be at least 8 characters")
    String password,

    @Schema(description = "Business role: PROFESSIONAL or RECRUITER", example = "PROFESSIONAL")
    @NotNull(message = "role is required")
    UserRole role,

    @Schema(description = "Given name", example = "Juan")
    String firstName,

    @Schema(description = "Family name", example = "Pérez")
    String lastName,

    @Schema(description = "Phone dial prefix (e.g. +591 for Bolivia)", example = "+591")
    String phoneCode,

    @Schema(description = "Phone number without dial prefix", example = "75001234")
    String phoneNumber,

    @Schema(description = "ISO 3166-1 alpha-2 country code", example = "BO")
    String countryCode
) {}
