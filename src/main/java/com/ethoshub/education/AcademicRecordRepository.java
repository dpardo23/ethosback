package com.ethoshub.education;

import com.ethoshub.education.dto.AcademicRecordRequest;
import com.ethoshub.education.dto.AcademicRecordResponse;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
class AcademicRecordRepository {

    private final DSLContext dsl;

    AcademicRecordRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    List<AcademicRecordResponse> findByProfileId(UUID profileId) {
        return dsl.resultQuery(
                        """
                        SELECT  ar.academic_record_id,
                                ar.profile_id,
                                ar.institution    AS institution_name,
                                ar.degree,
                                ar.field_of_study,
                                ar.education_type::text,
                                ar.start_date::text,
                                ar.end_date::text,
                                ar.gpa,
                                ar.description
                        FROM    core.academic_records ar
                        JOIN    core.profiles p ON p.profile_id = ar.profile_id
                        WHERE   ar.profile_id = ?
                          AND   ar.deleted_at IS NULL
                        ORDER BY ar.start_date DESC
                        """,
                        profileId
                )
                .fetch(r -> new AcademicRecordResponse(
                        r.get("academic_record_id", UUID.class).toString(),
                        r.get("profile_id",         UUID.class).toString(),
                        r.get("institution_name",   String.class),
                        r.get("degree",             String.class),
                        r.get("field_of_study",     String.class),
                        r.get("education_type",     String.class),
                        r.get("start_date",         String.class),
                        r.get("end_date",           String.class),
                        r.get("end_date",           String.class) == null,
                        r.get("gpa",                BigDecimal.class),
                        r.get("description",        String.class)
                ));
    }

    UUID create(UUID profileId, AcademicRecordRequest req) {
        return dsl.resultQuery(
                        """
                        INSERT INTO core.academic_records
                            (profile_id, institution, degree, field_of_study,
                             education_type, start_date, end_date, gpa, description)
                        VALUES (?, ?, ?, ?,
                                ?::core_types.education_type, ?::date,
                                CASE WHEN ? THEN NULL ELSE ?::date END,
                                ?, ?)
                        RETURNING academic_record_id
                        """,
                        profileId,
                        req.institutionName(),
                        req.degree(),
                        req.fieldOfStudy(),
                        normalizeEducationType(req.educationType()),
                        req.startDate(),
                        req.isCurrent(), req.endDate(),
                        req.gpa(),
                        req.description()
                )
                .fetchOne(r -> r.get("academic_record_id", UUID.class));
    }

    Optional<UUID> update(UUID recordId, UUID profileId, AcademicRecordRequest req) {
        int rows = dsl.execute(
                """
                UPDATE core.academic_records
                SET    institution    = ?,
                       degree         = ?,
                       field_of_study = ?,
                       education_type = ?::core_types.education_type,
                       start_date     = ?::date,
                       end_date       = CASE WHEN ? THEN NULL ELSE ?::date END,
                       gpa            = ?,
                       description    = ?,
                       updated_at     = NOW()
                WHERE  academic_record_id = ?
                  AND  profile_id         = ?
                  AND  deleted_at         IS NULL
                """,
                req.institutionName(),
                req.degree(),
                req.fieldOfStudy(),
                normalizeEducationType(req.educationType()),
                req.startDate(),
                req.isCurrent(), req.endDate(),
                req.gpa(),
                req.description(),
                recordId,
                profileId
        );
        return rows > 0 ? Optional.of(recordId) : Optional.empty();
    }

    boolean delete(UUID recordId, UUID profileId) {
        int rows = dsl.execute(
                """
                UPDATE core.academic_records
                SET    deleted_at = NOW()
                WHERE  academic_record_id = ?
                  AND  profile_id         = ?
                  AND  deleted_at         IS NULL
                """,
                recordId, profileId
        );
        return rows > 0;
    }

    private String normalizeEducationType(String raw) {
        if (raw == null || raw.isBlank()) return "INFORMAL";
        return switch (raw.toUpperCase().trim()) {
            case "HIGH_SCHOOL", "BACHILLERATO"           -> "HIGH_SCHOOL";
            case "TECHNICAL",   "TECNICO", "TÉCNICO"    -> "TECHNICAL";
            case "BACHELOR",    "PREGRADO", "LICENCIATURA" -> "BACHELOR";
            case "MASTER",      "MAESTRIA", "MAESTRÍA"   -> "MASTER";
            case "DOCTORATE",   "DOCTORADO", "PHD"       -> "DOCTORATE";
            case "POSTDOC"                               -> "POSTDOC";
            default                                      -> "INFORMAL";
        };
    }
}
