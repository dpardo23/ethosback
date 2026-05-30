package com.ethoshub.recruiter.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record RecruiterProfileResponse(
        String  profileId,
        String  companyName,
        String  photoUrl,
        Integer countryId,
        String  industry,
        String  website,
        Integer headcount,
        Integer foundedYear
) {}
