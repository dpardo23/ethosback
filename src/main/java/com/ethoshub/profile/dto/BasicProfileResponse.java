package com.ethoshub.profile.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;

@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "Basic profile data shared by all roles")
public record BasicProfileResponse(
        @Schema(description = "Internal profile UUID") String profileId,
        @Schema(description = "Given name")            String firstName,
        @Schema(description = "Family name")           String lastName,
        @Schema(description = "Avatar / photo URL")    String photoUrl,
        @Schema(description = "Phone number")          String phoneNumber,
        @Schema(description = "Short biography")       String bio,
        @Schema(description = "City or country")       String location,
        @Schema(description = "Personal website URL")  String website,
        @Schema(description = "Business role")         String role
) {}
