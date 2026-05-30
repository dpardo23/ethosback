package com.ethoshub.education.dto;

import java.math.BigDecimal;

public record AcademicRecordRequest(
        String     profileId,
        String     institutionName,
        String     degree,
        String     fieldOfStudy,
        String     educationType,
        String     startDate,
        String     endDate,
        boolean    isCurrent,
        BigDecimal gpa,
        String     description
) {}
