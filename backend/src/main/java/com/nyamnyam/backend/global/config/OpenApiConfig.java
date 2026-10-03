package com.nyamnyam.backend.global.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * springdoc 문서 정보(ADR-09). {@code /v3/api-docs}가 {@code contracts/openapi.json}의 원천이다.
 *
 * <p>생성 경로와 CI 재생성은 저장소 루트 {@code contracts/README.md}를 본다.
 */
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI nyamnyamOpenApi() {
        return new OpenAPI()
                .info(new Info().title("NyamNyam Coach API").version("v1").description("냠냠코치 API"));
    }
}
