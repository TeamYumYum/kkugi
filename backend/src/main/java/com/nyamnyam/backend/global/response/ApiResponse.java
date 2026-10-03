package com.nyamnyam.backend.global.response;

import com.nyamnyam.backend.global.error.ErrorCode;

/**
 * 모든 API 응답의 공통 포장(ADR-07: controller는 {@code ResponseEntity<ApiResponse<T>>}로 통일).
 *
 * <p><b>D(Spring 홈) 확정 전 초안.</b> 필드 이름과 오류 모양은 웹·Android 생성 타입(ADR-09)에 그대로 드러나므로, 확정 전에 바꾸는 것은
 * 자유지만 확정 후 변경은 계약 변경(엄격)이다.
 *
 * @param success 처리 성공 여부
 * @param data 성공 시 본문. 실패 시 {@code null}
 * @param error 실패 시 오류. 성공 시 {@code null}
 * @param <T> 본문 타입
 */
public record ApiResponse<T>(boolean success, T data, ErrorDetail error) {

    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(true, data, null);
    }

    public static ApiResponse<Void> error(ErrorCode errorCode) {
        return error(errorCode, errorCode.getMessage());
    }

    /** 기본 메시지 대신 구체적인 메시지(예: 검증 실패 필드)를 줄 때 쓴다. */
    public static ApiResponse<Void> error(ErrorCode errorCode, String message) {
        return new ApiResponse<>(false, null, new ErrorDetail(errorCode.name(), message));
    }

    /**
     * 오류 본문(D 확정 전 초안).
     *
     * @param code {@link ErrorCode} 이름. 클라이언트 분기 기준
     * @param message 사람이 읽는 설명. 클라이언트 분기에 쓰지 않는다
     */
    public record ErrorDetail(String code, String message) {}
}
