package com.ethoshub.education;

import com.ethoshub.education.dto.AcademicRecordRequest;
import com.ethoshub.education.dto.AcademicRecordResponse;
import com.ethoshub.shared.AuthException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
class AcademicRecordService {

    private final AcademicRecordRepository repo;

    AcademicRecordService(AcademicRecordRepository repo) {
        this.repo = repo;
    }

    List<AcademicRecordResponse> getRecords(UUID profileId) {
        return repo.findByProfileId(profileId);
    }

    UUID create(UUID profileId, AcademicRecordRequest req) {
        return repo.create(profileId, req);
    }

    void update(UUID recordId, UUID profileId, AcademicRecordRequest req) {
        repo.update(recordId, profileId, req)
                .orElseThrow(() -> new AuthException("Academic record not found", HttpStatus.NOT_FOUND));
    }

    void delete(UUID recordId, UUID profileId) {
        if (!repo.delete(recordId, profileId)) {
            throw new AuthException("Academic record not found", HttpStatus.NOT_FOUND);
        }
    }
}
