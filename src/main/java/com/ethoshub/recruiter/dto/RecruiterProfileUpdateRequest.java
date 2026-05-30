package com.ethoshub.recruiter.dto;

public record RecruiterProfileUpdateRequest(
        String  companyName,
        String  photoUrl,
        Integer countryId,
        String  industry,
        String  website,
        Integer headcount,
        Integer foundedYear
) {}
