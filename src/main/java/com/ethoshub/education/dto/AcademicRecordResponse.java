package com.ethoshub.education.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.math.BigDecimal;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record AcademicRecordResponse(
        String     academicRecordId,
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
