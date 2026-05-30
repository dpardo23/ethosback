package com.ethoshub.recruiter;

import com.ethoshub.recruiter.dto.RecruiterProfileResponse;
import com.ethoshub.recruiter.dto.RecruiterProfileUpdateRequest;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
class RecruiterProfileRepository {

    private final DSLContext dsl;

    RecruiterProfileRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    Optional<RecruiterProfileResponse> findByProfileId(UUID profileId, UUID authId) {
        return dsl.resultQuery(
                        """
                        SELECT  p.profile_id,
                                pc.company_name,
                                p.photo_url,
                                p.country_id,
                                pc.industry,
                                pc.website,
                                pc.headcount,
                                pc.founded_year
                        FROM    core.profiles p
                        LEFT JOIN core.profiles_company pc ON pc.profile_id = p.profile_id
                        WHERE   p.profile_id = ?
                          AND   p.id_auth    = ?
                          AND   p.deleted_at IS NULL
                        """,
                        profileId, authId
                )
                .fetch(r -> new RecruiterProfileResponse(
                        r.get("profile_id", UUID.class).toString(),
                        r.get("company_name", String.class),
                        r.get("photo_url",    String.class),
                        r.get("country_id",   Integer.class),
                        r.get("industry",     String.class),
                        r.get("website",      String.class),
                        r.get("headcount",    Integer.class),
                        r.get("founded_year", Integer.class)
                ))
                .stream().findFirst();
    }

    void update(UUID profileId, UUID authId, RecruiterProfileUpdateRequest req) {
        if (req.photoUrl() != null && !req.photoUrl().isBlank()) {
            dsl.execute(
                    """
                    UPDATE core.profiles
                    SET    photo_url  = ?,
                           country_id = COALESCE(?, country_id),
                           updated_at = NOW()
                    WHERE  profile_id = ?
                      AND  id_auth    = ?
                      AND  deleted_at IS NULL
                    """,
                    req.photoUrl(), req.countryId(), profileId, authId
            );
        } else if (req.countryId() != null) {
            dsl.execute(
                    """
                    UPDATE core.profiles
                    SET    country_id = ?,
                           updated_at = NOW()
                    WHERE  profile_id = ?
                      AND  id_auth    = ?
                      AND  deleted_at IS NULL
                    """,
                    req.countryId(), profileId, authId
            );
        }

        dsl.execute(
                """
                UPDATE core.profiles_company
                SET    company_name = COALESCE(?, company_name),
                       industry     = COALESCE(?, industry),
                       website      = COALESCE(?, website),
                       headcount    = COALESCE(?, headcount),
                       founded_year = COALESCE(?, founded_year),
                       updated_at   = NOW()
                FROM   core.profiles p
                WHERE  core.profiles_company.profile_id = p.profile_id
                  AND  p.profile_id = ?
                  AND  p.id_auth    = ?
                  AND  core.profiles_company.deleted_at IS NULL
                """,
                req.companyName(), req.industry(), req.website(),
                req.headcount(), req.foundedYear(),
                profileId, authId
        );
    }
}
