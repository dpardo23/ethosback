package com.ethoshub.profile.dto;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "Payload for PATCH /v1/profile/bio")
public record BioUpdateRequest(
        @Schema(description = "Free-text biography") String bio
) {}
