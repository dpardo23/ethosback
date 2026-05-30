package com.ethoshub.shared;

import org.springframework.http.HttpStatus;

public class AuthException extends RuntimeException {

    private final HttpStatus httpStatus;

    public AuthException(String message, HttpStatus httpStatus) {
        super(message);
        this.httpStatus = httpStatus;
    }

    public AuthException(String message) {
        this(message, HttpStatus.UNAUTHORIZED);
    }

    public HttpStatus getHttpStatus() {
        return httpStatus;
    }
}
