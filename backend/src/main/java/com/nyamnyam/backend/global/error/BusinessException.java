package com.nyamnyam.backend.global.error;

import lombok.Getter;

/**
 * 공통 비즈니스 예외. 도메인 전용 예외 클래스는 만들지 않고 {@link ErrorCode}를 늘린다.
 *
 * <p><b>D(Spring 홈) 확정 전 초안.</b>
 */
@Getter
public class BusinessException extends RuntimeException {

    private final ErrorCode errorCode;

    public BusinessException(ErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
    }

    public BusinessException(ErrorCode errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
    }
}
