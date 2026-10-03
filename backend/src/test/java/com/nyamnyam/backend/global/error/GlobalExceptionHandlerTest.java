package com.nyamnyam.backend.global.error;

import static org.hamcrest.Matchers.startsWith;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.nyamnyam.backend.global.response.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

// 공통 응답 모양(ApiResponse)과 예외 → 상태 코드 변환을 테스트 전용 컨트롤러로 확인한다.
@WebMvcTest(GlobalExceptionHandlerTest.ProbeController.class)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandlerTest.ProbeController.class)
class GlobalExceptionHandlerTest {

    @Autowired private MockMvc mockMvc;

    @Test
    void okWrapsData() throws Exception {
        mockMvc.perform(get("/probe/ok"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data").value("pong"))
                .andExpect(jsonPath("$.error").doesNotExist());
    }

    @Test
    void businessExceptionUsesErrorCodeStatus() throws Exception {
        mockMvc.perform(get("/probe/not-found"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.data").doesNotExist())
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"))
                .andExpect(jsonPath("$.error.message").value(ErrorCode.NOT_FOUND.getMessage()));
    }

    @Test
    void validationFailureIsInvalidInput() throws Exception {
        mockMvc.perform(
                        post("/probe/validate")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"name\":\"\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_INPUT"))
                .andExpect(jsonPath("$.error.message").value(startsWith("name")));
    }

    @Test
    void malformedBodyIsInvalidInput() throws Exception {
        mockMvc.perform(
                        post("/probe/validate")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{not json"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_INPUT"));
    }

    @Test
    void unexpectedExceptionHidesInternalMessage() throws Exception {
        mockMvc.perform(get("/probe/boom"))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.error.code").value("INTERNAL_ERROR"))
                .andExpect(
                        jsonPath("$.error.message").value(ErrorCode.INTERNAL_ERROR.getMessage()));
    }

    record ProbeRequest(@NotBlank String name) {}

    @RestController
    static class ProbeController {

        @GetMapping("/probe/ok")
        ResponseEntity<ApiResponse<String>> ok() {
            return ResponseEntity.ok(ApiResponse.ok("pong"));
        }

        @GetMapping("/probe/not-found")
        ResponseEntity<ApiResponse<String>> notFound() {
            throw new BusinessException(ErrorCode.NOT_FOUND);
        }

        @PostMapping("/probe/validate")
        ResponseEntity<ApiResponse<String>> validate(@Valid @RequestBody ProbeRequest request) {
            return ResponseEntity.ok(ApiResponse.ok(request.name()));
        }

        @GetMapping("/probe/boom")
        ResponseEntity<ApiResponse<String>> boom() {
            throw new IllegalStateException("internal detail");
        }
    }
}
