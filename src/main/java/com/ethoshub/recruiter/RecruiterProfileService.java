package com.ethoshub.recruiter;

import com.ethoshub.recruiter.dto.RecruiterProfileResponse;
import com.ethoshub.recruiter.dto.RecruiterProfileUpdateRequest;
import com.ethoshub.shared.AuthException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
class RecruiterProfileService {

    private final RecruiterProfileRepository repo;

    RecruiterProfileService(RecruiterProfileRepository repo) {
        this.repo = repo;
    }

    RecruiterProfileResponse getProfile(UUID profileId, UUID authId) {
        return repo.findByProfileId(profileId, authId)
                .orElseThrow(() -> new AuthException("Recruiter profile not found", HttpStatus.NOT_FOUND));
    }

    RecruiterProfileResponse updateProfile(UUID profileId, UUID authId, RecruiterProfileUpdateRequest req) {
        repo.update(profileId, authId, req);
        return getProfile(profileId, authId);
    }
}
