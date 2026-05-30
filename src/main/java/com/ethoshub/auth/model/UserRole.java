package com.ethoshub.auth.model;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

public enum UserRole {

    PROFESSIONAL,
    RECRUITER,
    ADMIN;

    @JsonCreator
    public static UserRole fromValue(String value) {
        if (value == null) return PROFESSIONAL;
        return switch (value.toUpperCase().trim()) {
            case "PROFESSIONAL", "ESTANDAR"                -> PROFESSIONAL;
            case "RECRUITER",    "RECLUTADOR"              -> RECRUITER;
            case "ADMIN",        "ADMINISTRADOR"           -> ADMIN;
            case "INVITADO",     "GUEST"                   -> PROFESSIONAL;
            default -> PROFESSIONAL;
        };
    }

    @JsonValue
    public String toValue() {
        return name().toLowerCase();
    }

    public String toDbValue() {
        return name().toLowerCase();
    }

    public String toSpringAuthority() {
        return "ROLE_" + name();
    }
}
