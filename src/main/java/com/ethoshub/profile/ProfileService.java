package com.ethoshub.profile;

import com.ethoshub.profile.dto.BasicProfileResponse;
import com.ethoshub.profile.dto.BasicProfileUpdateRequest;
import com.ethoshub.profile.dto.BioUpdateRequest;
import com.ethoshub.shared.AuthException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
class ProfileService {

    private final BasicProfileRepository repo;

    ProfileService(BasicProfileRepository repo) {
        this.repo = repo;
    }

    BasicProfileResponse getBasicProfile(UUID authId) {
        return repo.findByAuthId(authId)
                .orElseThrow(() -> new AuthException("Profile not found", HttpStatus.NOT_FOUND));
    }

    void updateBasicProfile(UUID authId, BasicProfileUpdateRequest req) {
        repo.updateBasicFields(authId,
                req.firstName(), req.lastName(),
                req.photoUrl(), req.phoneNumber(),
                req.location(), req.website());
    }

    void updateBio(UUID authId, BioUpdateRequest req) {
        repo.updateBio(authId, req.bio());
    }
}
