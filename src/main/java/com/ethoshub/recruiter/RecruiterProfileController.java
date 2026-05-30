package com.ethoshub.recruiter;

import com.ethoshub.recruiter.dto.RecruiterProfileResponse;
import com.ethoshub.recruiter.dto.RecruiterProfileUpdateRequest;
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
@RequestMapping("/v1/recruiter/profile")
@Tag(name = "Recruiter Profile", description = "Read and update the authenticated recruiter's profile")
@SecurityRequirement(name = "bearerAuth")
public class RecruiterProfileController {

    private final RecruiterProfileService service;

    RecruiterProfileController(RecruiterProfileService service) {
        this.service = service;
    }

    @GetMapping("/{profileId}")
    @Operation(summary = "Get recruiter profile", description = "Returns company info and photo for the recruiter.")
    ResponseEntity<ApiResponse<RecruiterProfileResponse>> getProfile(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID profileId
    ) {
        UUID authId = UUID.fromString(jwt.getSubject());
        return ResponseEntity.ok(ApiResponse.ok(service.getProfile(profileId, authId), "Profile retrieved"));
    }

    @PutMapping("/{profileId}")
    @Operation(summary = "Update recruiter profile", description = "Updates company name, photo, country, industry, website.")
    ResponseEntity<ApiResponse<RecruiterProfileResponse>> updateProfile(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID profileId,
            @RequestBody RecruiterProfileUpdateRequest request
    ) {
        UUID authId = UUID.fromString(jwt.getSubject());
        return ResponseEntity.ok(ApiResponse.ok(service.updateProfile(profileId, authId, request), "Profile updated"));
    }

    @GetMapping("/company/{profileId}")
    @Operation(summary = "Get company profile", description = "Returns company details for the recruiter.")
    ResponseEntity<ApiResponse<RecruiterProfileResponse>> getCompanyProfile(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID profileId
    ) {
        UUID authId = UUID.fromString(jwt.getSubject());
        return ResponseEntity.ok(ApiResponse.ok(service.getProfile(profileId, authId), "Company profile retrieved"));
    }

    @PutMapping("/company/{profileId}")
    @Operation(summary = "Update company profile", description = "Updates industry, website, headcount, founded year.")
    ResponseEntity<ApiResponse<RecruiterProfileResponse>> updateCompanyProfile(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID profileId,
            @RequestBody RecruiterProfileUpdateRequest request
    ) {
        UUID authId = UUID.fromString(jwt.getSubject());
        return ResponseEntity.ok(ApiResponse.ok(service.updateProfile(profileId, authId, request), "Company profile updated"));
    }
}
