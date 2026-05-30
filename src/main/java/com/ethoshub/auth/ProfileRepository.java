package com.ethoshub.auth;

import com.ethoshub.auth.model.UserRole;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
class ProfileRepository {

    private final DSLContext dsl;

    ProfileRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    /**
     * Delegates profile + sub-profile creation to core.sp_provision_profile.
     * Idempotent: ON CONFLICT DO NOTHING inside the SP ensures repeated calls are safe.
     *
     * @param phoneCode   dial prefix, e.g. "+591"
     * @param phoneNumber national number without prefix, e.g. "75001234"
     * @param provider    identity provider: "email", "google", "github"
     */
    void provision(UUID authId, String email, String firstName, String lastName,
                   String roleKey, String phoneCode, String phoneNumber,
                   String countryCode, String provider) {
        dsl.execute(
                "CALL core.sp_provision_profile(?, ?, ?, ?, ?, ?, ?, ?, ?)",
                authId,
                email,
                firstName != null ? firstName : "",
                lastName  != null ? lastName  : "",
                roleKey,
                phoneCode,
                phoneNumber,
                countryCode,
                provider != null ? provider : "email"
        );
    }

    void updatePhoto(UUID authId, String photoUrl) {
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

    Optional<ProfileRecord> findByAuthId(UUID authId) {
        return dsl.resultQuery(
                        """
                        SELECT  p.profile_id,
                                p.id_auth,
                                u.email::text,
                                pb.first_name::text,
                                pb.last_name::text,
                                r.name::text AS role_name
                        FROM    core.profiles p
                        JOIN    auth.users u               ON u.id          = p.id_auth
                        LEFT JOIN core.profiles_basic pb   ON pb.profile_id = p.profile_id
                        LEFT JOIN core.profile_roles  pr   ON pr.id_auth    = p.id_auth
                                                          AND pr.revoked_at IS NULL
                        LEFT JOIN core.roles           r   ON r.roles_id    = pr.roles_id
                        WHERE   p.id_auth    = ?
                          AND   p.deleted_at IS NULL
                        """,
                        authId
                )
                .fetch(record -> new ProfileRecord(
                        record.get("profile_id", UUID.class),
                        record.get("id_auth",    UUID.class),
                        record.get("email",      String.class),
                        record.get("first_name", String.class),
                        record.get("last_name",  String.class),
                        UserRole.fromValue(record.get("role_name", String.class))
                ))
                .stream()
                .findFirst();
    }

    record ProfileRecord(
            UUID     idProfile,
            UUID     authId,
            String   email,
            String   firstName,
            String   lastName,
            UserRole role
    ) {}
}
