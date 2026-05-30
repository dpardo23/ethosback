package com.ethoshub.auth;

// [RED] Tests that expose two bugs in AuthService.oauthSync():
//   1. profileId is returned as authId instead of id_profile from public.profile
//   2. existing profile's stored role is ignored when computing the response

import com.ethoshub.auth.dto.AuthResponse;
import com.ethoshub.auth.model.UserRole;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Answers;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.client.RestClient;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceOAuthSyncTest {

    @Mock(answer = Answers.RETURNS_DEEP_STUBS)
    RestClient restClient;

    @Mock
    ProfileRepository profileRepository;

    AuthService sut;

    @BeforeEach
    void setUp() {
        sut = new AuthService(restClient, profileRepository,
                "https://test.supabase.co", "anon-key", "service-key");
    }

    // ── Bug 1: existing profile returns authId instead of id_profile ──────────

    @Test
    void oauthSync_existingProfile_returnsIdProfile_notAuthId() {
        UUID authId    = UUID.randomUUID();
        UUID idProfile = UUID.randomUUID(); // must differ from authId

        when(profileRepository.findByAuthId(authId)).thenReturn(Optional.of(
                new ProfileRepository.ProfileRecord(
                        idProfile, authId, "u@test.com", "Juan", "Pérez", UserRole.PROFESSIONAL)
        ));

        AuthResponse result = sut.oauthSync(authId, "u@test.com", "Juan Pérez", null);

        // [RED] current code returns authId.toString() → this assertion fails
        assertThat(result.profileId())
                .as("profileId must be the DB-side id_profile, not the Supabase auth_id")
                .isEqualTo(idProfile.toString())
                .isNotEqualTo(authId.toString());
    }

    // ── Bug 2: existing RECRUITER profile must not downgrade to PROFESSIONAL ──

    @Test
    void oauthSync_existingRecruiterProfile_ignoresRequestedRole_preservesRECRUITER() {
        UUID authId    = UUID.randomUUID();
        UUID idProfile = UUID.randomUUID();

        when(profileRepository.findByAuthId(authId)).thenReturn(Optional.of(
                new ProfileRepository.ProfileRecord(
                        idProfile, authId, "r@test.com", "Ana", "López", UserRole.RECRUITER)
        ));

        // Frontend mistakenly sends "professional" on re-sync; stored role must win
        AuthResponse result = sut.oauthSync(authId, "r@test.com", "Ana López", "professional");

        assertThat(result.role())
                .as("stored role must not be overwritten by the OAuth re-sync payload")
                .isEqualTo(UserRole.RECRUITER.name());
    }

    // ── New user: provision + return id_profile ───────────────────────────────

    @Test
    void oauthSync_newUser_recruiterRole_provisionsAndReturnsCorrectRole() {
        UUID authId    = UUID.randomUUID();
        UUID idProfile = UUID.randomUUID();

        when(profileRepository.findByAuthId(authId))
                .thenReturn(Optional.empty())  // first call: user not yet in DB
                .thenReturn(Optional.of(       // second call after provision
                        new ProfileRepository.ProfileRecord(
                                idProfile, authId, "new@test.com", "New", "User", UserRole.RECRUITER)));

        AuthResponse result = sut.oauthSync(authId, "new@test.com", "New User", "recruiter");

        verify(profileRepository).provision(
                eq(authId), eq("new@test.com"), eq("New"), eq("User"),
                eq("recruiter"), isNull(), isNull());

        assertThat(result.role()).isEqualTo(UserRole.RECRUITER.name());
        // [RED] also verifies profileId is id_profile, not authId
        assertThat(result.profileId()).isEqualTo(idProfile.toString());
    }

    @Test
    void oauthSync_newUser_noRoleSupplied_defaultsToPROFESSIONAL() {
        UUID authId    = UUID.randomUUID();
        UUID idProfile = UUID.randomUUID();

        when(profileRepository.findByAuthId(authId))
                .thenReturn(Optional.empty())
                .thenReturn(Optional.of(
                        new ProfileRepository.ProfileRecord(
                                idProfile, authId, "p@test.com", "Pro", "", UserRole.PROFESSIONAL)));

        AuthResponse result = sut.oauthSync(authId, "p@test.com", "Pro", null);

        verify(profileRepository).provision(
                eq(authId), eq("p@test.com"), eq("Pro"), eq(""), eq("professional"), isNull(), isNull());
        assertThat(result.role()).isEqualTo(UserRole.PROFESSIONAL.name());
        assertThat(result.profileId()).isEqualTo(idProfile.toString());
    }

    @Test
    void oauthSync_noFullName_derivesFirstNameFromEmail() {
        UUID authId    = UUID.randomUUID();
        UUID idProfile = UUID.randomUUID();

        when(profileRepository.findByAuthId(authId))
                .thenReturn(Optional.empty())
                .thenReturn(Optional.of(
                        new ProfileRepository.ProfileRecord(
                                idProfile, authId, "user@company.com", "user", "", UserRole.PROFESSIONAL)));

        sut.oauthSync(authId, "user@company.com", null, null);

        verify(profileRepository).provision(any(), any(), eq("user"), any(), any(), any(), any());
    }
}
