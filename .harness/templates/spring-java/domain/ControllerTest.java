package {{base_package}}.domain.{{name_lower}}.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import {{base_package}}.domain.{{name_lower}}.dto.request.{{name_pascal}}CreateRequest;
import {{base_package}}.domain.{{name_lower}}.entity.{{name_pascal}};
import {{base_package}}.domain.{{name_lower}}.service.{{name_pascal}}Service;
import {{base_package}}.global.error.BusinessException;
import {{base_package}}.global.error.ErrorCode;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import {{webmvc_test_package}}.AutoConfigureMockMvc;
import {{webmvc_test_package}}.WebMvcTest;
import org.springframework.context.annotation.Bean;
import org.springframework.http.MediaType;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;

// Controller 슬라이스 테스트. 응답은 ApiResponse로 포장된다($.success·$.data·$.error).
// Service 대역은 @TestConfiguration의 Mockito 빈으로 준다(Boot 4.x에서 @MockBean 제거). 보안 필터는 끄고
// 인가는 별도 테스트로 본다. 공통 예외 처리(GlobalExceptionHandler)는 @WebMvcTest가 함께 올린다.
@WebMvcTest({{name_pascal}}Controller.class)
@AutoConfigureMockMvc(addFilters = false)
class {{name_pascal}}ControllerTest {

    @Autowired private MockMvc mockMvc;

    @Autowired private {{name_pascal}}Service {{name_camel}}Service;

    @AfterEach
    void resetMocks() {
        Mockito.reset({{name_camel}}Service);
    }

    @Test
    void getReturnsWrappedResponse() throws Exception {
        given({{name_camel}}Service.get(1L)).willReturn(saved(1L, "sample"));

        mockMvc.perform(get("/api/v1/{{name_kebab}}/{id}", 1L))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.id").value(1))
                .andExpect(jsonPath("$.data.name").value("sample"));
    }

    @Test
    void getMissingReturnsNotFound() throws Exception {
        given({{name_camel}}Service.get(1L)).willThrow(new BusinessException(ErrorCode.NOT_FOUND));

        mockMvc.perform(get("/api/v1/{{name_kebab}}/{id}", 1L))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));
    }

    @Test
    void createReturnsCreated() throws Exception {
        given({{name_camel}}Service.create(any({{name_pascal}}CreateRequest.class)))
                .willReturn(saved(1L, "sample"));

        mockMvc.perform(
                        post("/api/v1/{{name_kebab}}")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"name\":\"sample\"}"))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", "/api/v1/{{name_kebab}}/1"))
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.id").value(1));
    }

    // 엔티티 id는 DB가 채운다. 테스트에서는 저장된 상태를 흉내 내려고 직접 넣는다
    private static {{name_pascal}} saved(Long id, String name) {
        {{name_pascal}} entity = {{name_pascal}}.create(name);
        ReflectionTestUtils.setField(entity, "id", id);
        return entity;
    }

    @TestConfiguration
    static class ServiceMockConfig {

        @Bean
        {{name_pascal}}Service {{name_camel}}Service() {
            return Mockito.mock({{name_pascal}}Service.class);
        }
    }
}
