package com.ethoshub.profile;

import com.ethoshub.profile.dto.BasicProfileResponse;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
class BasicProfileRepository {

    private final DSLContext dsl;

    BasicProfileRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    Optional<BasicProfileResponse> findByAuthId(UUID authId) {
        return dsl.resultQuery(
                        """
                        SELECT  p.profile_id,
                                pb.first_name::text,
                                pb.last_name::text,
                                p.photo_url::text                               AS avatar_url,
                                pb.phone_number::text,
                                b.bio_text::text                                AS bio,
                                b.headline::text,
                                ct.name                                         AS location,
                                NULL::text                                      AS website,
                                r.name::text                                    AS role_name
                        FROM    core.profiles p
                        LEFT JOIN core.profiles_basic        pb  ON pb.profile_id  = p.profile_id
                        LEFT JOIN core.biographies           b   ON b.profile_id   = p.profile_id
                        LEFT JOIN core.countries             ct  ON ct.country_id  = p.country_id
                        LEFT JOIN core.profile_roles         pr  ON pr.id_auth     = p.id_auth
                                                                AND pr.revoked_at IS NULL
                        LEFT JOIN core.roles                 r   ON r.roles_id     = pr.roles_id
                        WHERE   p.id_auth    = ?
                          AND   p.deleted_at IS NULL
                        """,
                        authId
                )
                .fetch(record -> new BasicProfileResponse(
                        record.get("profile_id", UUID.class).toString(),
                        record.get("first_name", String.class),
                        record.get("last_name",  String.class),
                        record.get("avatar_url", String.class),
                        record.get("phone_number", String.class),
                        record.get("bio",        String.class),
                        record.get("location",   String.class),
                        record.get("website",    String.class),
                        record.get("role_name",  String.class)
                ))
                .stream()
                .findFirst();
    }

    void updateBasicFields(UUID authId, String firstName, String lastName,
                           String photoUrl, String phoneNumber,
                           String location, String website) {
        // Update photo_url on base profile (only when value provided and looks like a URL)
        if (photoUrl != null && !photoUrl.isBlank() && photoUrl.startsWith("http")) {
            dsl.execute(
                    """
                    UPDATE core.profiles
                    SET    photo_url  = ?,
                           updated_at = NOW()
                    WHERE  id_auth    = ?
                      AND  deleted_at IS NULL
                    """,
                    photoUrl, authId
            );
        }

        // Update profiles_basic fields (first/last name, phone_number)
        dsl.execute(
                """
                UPDATE core.profiles_basic pb
                SET    first_name   = CASE
                                         WHEN regexp_replace(trim(?), '[^a-zA-ZáéíóúÁÉÍÓÚñÑ ]', '', 'g') ~ '^[a-zA-ZáéíóúÁÉÍÓÚñÑ]+(\\s[a-zA-ZáéíóúÁÉÍÓÚñÑ]+)*$'
                                          AND char_length(trim(?)) >= 2
                                         THEN ?
                                         ELSE pb.first_name
                                     END,
                       last_name    = CASE
                                         WHEN regexp_replace(trim(?), '[^a-zA-ZáéíóúÁÉÍÓÚñÑ ]', '', 'g') ~ '^[a-zA-ZáéíóúÁÉÍÓÚñÑ]+(\\s[a-zA-ZáéíóúÁÉÍÓÚñÑ]+)*$'
                                          AND char_length(trim(?)) >= 2
                                         THEN ?
                                         ELSE pb.last_name
                                     END,
                       updated_at   = NOW()
                FROM   core.profiles p
                WHERE  pb.profile_id = p.profile_id
                  AND  p.id_auth     = ?
                  AND  pb.deleted_at IS NULL
                """,
                firstName, firstName, firstName,
                lastName,  lastName,  lastName,
                authId
        );
    }

    void updateBio(UUID authId, String bio) {
        dsl.execute(
                """
                INSERT INTO core.biographies (profile_id, bio_text)
                SELECT p.profile_id, ?
                FROM   core.profiles p
                WHERE  p.id_auth    = ?
                  AND  p.deleted_at IS NULL
                ON CONFLICT (profile_id) DO UPDATE
                    SET bio_text   = EXCLUDED.bio_text,
                        updated_at = NOW()
                """,
                bio, authId
        );
    }
}
