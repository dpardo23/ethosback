package com.ethoshub.auth.model;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UserRoleTest {

    @ParameterizedTest
    @ValueSource(strings = {"professional", "PROFESSIONAL", "estandar", "ESTANDAR"})
    void fromValue_professionalVariants_mapsToPROFESSIONAL(String value) {
        assertThat(UserRole.fromValue(value)).isEqualTo(UserRole.PROFESSIONAL);
    }

    @ParameterizedTest
    @ValueSource(strings = {"recruiter", "RECRUITER", "reclutador", "RECLUTADOR"})
    void fromValue_recruiterVariants_mapsToRECRUITER(String value) {
        assertThat(UserRole.fromValue(value)).isEqualTo(UserRole.RECRUITER);
    }

    @ParameterizedTest
    @ValueSource(strings = {"admin", "ADMIN", "administrador", "ADMINISTRADOR"})
    void fromValue_adminVariants_mapsToADMIN(String value) {
        assertThat(UserRole.fromValue(value)).isEqualTo(UserRole.ADMIN);
    }

    @Test
    void fromValue_null_returnsProfessional() {
        assertThat(UserRole.fromValue(null)).isEqualTo(UserRole.PROFESSIONAL);
    }

    @Test
    void fromValue_unknown_returnsProfessional() {
        assertThat(UserRole.fromValue("superuser")).isEqualTo(UserRole.PROFESSIONAL);
    }

    @Test
    void fromValue_whitespace_trims() {
        assertThat(UserRole.fromValue("  RECRUITER  ")).isEqualTo(UserRole.RECRUITER);
    }

    @Test
    void toDbValue_returnsLowercase() {
        assertThat(UserRole.PROFESSIONAL.toDbValue()).isEqualTo("professional");
        assertThat(UserRole.RECRUITER.toDbValue()).isEqualTo("recruiter");
        assertThat(UserRole.ADMIN.toDbValue()).isEqualTo("admin");
    }

    @Test
    void toSpringAuthority_hasPrefixROLE_() {
        assertThat(UserRole.PROFESSIONAL.toSpringAuthority()).isEqualTo("ROLE_PROFESSIONAL");
        assertThat(UserRole.RECRUITER.toSpringAuthority()).isEqualTo("ROLE_RECRUITER");
    }

    @Test
    void toValue_returnsLowercase() {
        assertThat(UserRole.PROFESSIONAL.toValue()).isEqualTo("professional");
    }

    // ── Role round-trip: DB value → enum → name() ──────────────────────────
    @Test
    void dbValue_roundTrip_preservesIdentity() {
        for (UserRole role : UserRole.values()) {
            assertThat(UserRole.fromValue(role.toDbValue())).isEqualTo(role);
        }
    }
}
