package com.ethoshub.auth.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

@Schema(description = "Credentials for local email/password login")
public record LoginRequest(

    @Schema(description = "User email address", example = "user@example.com")
    @NotBlank(message = "email is required")
    @Email(message = "email must be a valid address")
    String email,

    @Schema(description = "User password", example = "S3cur3P@ss!")
    @NotBlank(message = "password is required")
    String password
) {}
