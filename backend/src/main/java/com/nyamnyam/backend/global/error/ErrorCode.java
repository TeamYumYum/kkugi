package com.nyamnyam.backend.global.error;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

/**
 * 공통 오류 코드.
 *
 * <p><b>D(Spring 홈) 확정 전 초안.</b> 도메인별 코드는 각 담당이 이 enum에 추가한다(도메인 전용 예외 클래스는 만들지 않는다). 이름은 {@code
 * ApiResponse.ErrorDetail.code}로 클라이언트에 그대로 나간다.
 */
@Getter
@RequiredArgsConstructor
public enum ErrorCode {
    INVALID_INPUT(HttpStatus.BAD_REQUEST, "요청 값이 올바르지 않다"),
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED, "인증이 필요하다"),
    FORBIDDEN(HttpStatus.FORBIDDEN, "권한이 없다"),
    NOT_FOUND(HttpStatus.NOT_FOUND, "리소스를 찾을 수 없다"),
    METHOD_NOT_ALLOWED(HttpStatus.METHOD_NOT_ALLOWED, "지원하지 않는 메서드다"),
    CONFLICT(HttpStatus.CONFLICT, "현재 상태와 충돌한다"),
    INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "서버 오류가 발생했다");

    private final HttpStatus status;
    private final String message;
}
