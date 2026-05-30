package com.ethoshub.profile;

import com.ethoshub.profile.dto.BasicProfileResponse;
import com.ethoshub.profile.dto.BasicProfileUpdateRequest;
import com.ethoshub.profile.dto.BioUpdateRequest;
import com.ethoshub.shared.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/v1/profile")
@Tag(name = "Profile", description = "Read and update the authenticated user's profile")
@SecurityRequirement(name = "bearerAuth")
class ProfileController {

    private final ProfileService profileService;

    ProfileController(ProfileService profileService) {
        this.profileService = profileService;
    }

    @GetMapping("/basic")
    @Operation(summary = "Get basic profile", description = "Returns name, avatar, bio, location and website for the authenticated user.")
    ResponseEntity<ApiResponse<BasicProfileResponse>> getBasicProfile(
            @AuthenticationPrincipal Jwt jwt
    ) {
        UUID authId = UUID.fromString(jwt.getSubject());
        BasicProfileResponse profile = profileService.getBasicProfile(authId);
        return ResponseEntity.ok(ApiResponse.ok(profile, "Profile retrieved"));
    }

    @PatchMapping("/basic")
    @Operation(summary = "Update basic profile", description = "Updates name, avatar, phone, location and website.")
    ResponseEntity<ApiResponse<Void>> updateBasicProfile(
            @AuthenticationPrincipal Jwt jwt,
            @RequestBody BasicProfileUpdateRequest request
    ) {
        UUID authId = UUID.fromString(jwt.getSubject());
        profileService.updateBasicProfile(authId, request);
        return ResponseEntity.ok(ApiResponse.ok(null, "Profile updated"));
    }

    @PatchMapping("/bio")
    @Operation(summary = "Update biography", description = "Updates the free-text bio of the authenticated user.")
    ResponseEntity<ApiResponse<Void>> updateBio(
            @AuthenticationPrincipal Jwt jwt,
            @RequestBody BioUpdateRequest request
    ) {
        UUID authId = UUID.fromString(jwt.getSubject());
        profileService.updateBio(authId, request);
        return ResponseEntity.ok(ApiResponse.ok(null, "Bio updated"));
    }
}
