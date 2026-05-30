package com.ethoshub.education;

import com.ethoshub.education.dto.AcademicRecordRequest;
import com.ethoshub.education.dto.AcademicRecordResponse;
import com.ethoshub.shared.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/v1/academic-records")
@Tag(name = "Academic Records", description = "CRUD for academic / education records")
@SecurityRequirement(name = "bearerAuth")
public class AcademicRecordController {

    private final AcademicRecordService service;

    AcademicRecordController(AcademicRecordService service) {
        this.service = service;
    }

    @GetMapping("/profile/{profileId}")
    @Operation(summary = "List academic records", description = "Returns all education records for the given profile.")
    ResponseEntity<ApiResponse<List<AcademicRecordResponse>>> getRecords(
            @PathVariable UUID profileId
    ) {
        return ResponseEntity.ok(ApiResponse.ok(service.getRecords(profileId), "Records retrieved"));
    }

    @PostMapping
    @Operation(summary = "Create academic record")
    ResponseEntity<ApiResponse<String>> create(
            @RequestBody AcademicRecordRequest request
    ) {
        UUID profileId = UUID.fromString(request.profileId());
        UUID id = service.create(profileId, request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(id.toString(), "Record created"));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update academic record")
    ResponseEntity<ApiResponse<Void>> update(
            @PathVariable UUID id,
            @RequestBody AcademicRecordRequest request
    ) {
        UUID profileId = UUID.fromString(request.profileId());
        service.update(id, profileId, request);
        return ResponseEntity.ok(ApiResponse.ok(null, "Record updated"));
    }

    @DeleteMapping("/{id}/profile/{profileId}")
    @Operation(summary = "Delete academic record")
    ResponseEntity<ApiResponse<Void>> delete(
            @PathVariable UUID id,
            @PathVariable UUID profileId
    ) {
        service.delete(id, profileId);
        return ResponseEntity.ok(ApiResponse.ok(null, "Record deleted"));
    }
}
