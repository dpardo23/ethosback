package com.ethoshub.auth.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record OAuthSyncRequest(
        String role,
        @JsonProperty("avatarUrl")          String  avatarUrl,
        @JsonProperty("isNewRegistration")  boolean isNewRegistration
) {}
