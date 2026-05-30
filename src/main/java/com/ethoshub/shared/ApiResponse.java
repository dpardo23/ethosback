package com.ethoshub.shared;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "Standard API envelope returned by all endpoints")
public record ApiResponse<T>(

    @Schema(description = "True when the operation succeeded", example = "true")
    boolean success,

    @Schema(description = "HTTP status code mirrored in the body", example = "200")
    int status,

    @Schema(description = "Human-readable result message", example = "Login successful")
    String message,

    @Schema(description = "Response payload; null on error responses")
    T data,

    @Schema(description = "Validation or business errors; null on success responses")
    List<String> errors
) {

    public static <T> ApiResponse<T> ok(T data, String message) {
        return new ApiResponse<>(true, 200, message, data, null);
    }

    public static <T> ApiResponse<T> created(T data, String message) {
        return new ApiResponse<>(true, 201, message, data, null);
    }

    public static <T> ApiResponse<T> badRequest(String message, List<String> errors) {
        return new ApiResponse<>(false, 400, message, null, errors);
    }

    public static <T> ApiResponse<T> unauthorized(String message) {
        return new ApiResponse<>(false, 401, message, null, null);
    }

    public static <T> ApiResponse<T> forbidden(String message) {
        return new ApiResponse<>(false, 403, message, null, null);
    }

    public static <T> ApiResponse<T> conflict(String message) {
        return new ApiResponse<>(false, 409, message, null, null);
    }

    public static <T> ApiResponse<T> internalError(String message) {
        return new ApiResponse<>(false, 500, message, null, null);
    }
}
