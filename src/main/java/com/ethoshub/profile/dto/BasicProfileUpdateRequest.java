package com.ethoshub.profile.dto;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "Fields that can be updated via PATCH /v1/profile/basic")
public record BasicProfileUpdateRequest(
        @Schema(description = "Given name")           String firstName,
        @Schema(description = "Family name")          String lastName,
        @Schema(description = "Avatar / photo URL")   String photoUrl,
        @Schema(description = "Phone number")         String phoneNumber,
        @Schema(description = "City or country")      String location,
        @Schema(description = "Personal website URL") String website
) {}
