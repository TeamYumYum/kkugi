package com.nyamnyam.backend.global.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.boot.test.web.server.LocalManagementPort;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.yaml.snakeyaml.Yaml;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

// 관측 설정(observability.yml)을 실제 서버로 확인한다. 관리 포트는 무작위로 따로 띄운다(운영 값은 8081).
@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = "management.server.port=0")
@ExtendWith(OutputCaptureExtension.class)
class ObservabilityConfigTest {

    private static final HttpClient HTTP = HttpClient.newHttpClient();
    private static final JsonMapper JSON = JsonMapper.builder().build();

    @LocalServerPort private int serverPort;
    @LocalManagementPort private int managementPort;

    @Test
    void prometheusEndpointExposed() throws Exception {
        get(serverPort, "/v3/api-docs");

        HttpResponse<String> response = get(managementPort, "/actuator/prometheus");

        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.body())
                .contains("http_server_requests_seconds_bucket")
                .contains("hikaricp_connections")
                .contains("jvm_memory_used_bytes")
                // 공통 태그(플랜 결정6)
                .containsPattern("jvm_memory_used_bytes\\{[^}]*application=\"kkugi-backend\"")
                .containsPattern("jvm_memory_used_bytes\\{[^}]*service=\"kkugi-backend\"")
                .containsPattern("jvm_memory_used_bytes\\{[^}]*env=\"[^\"]+\"")
                .containsPattern("jvm_memory_used_bytes\\{[^}]*version=\"[^\"]+\"");
    }

    @Test
    void onlyHealthAndPrometheusExposed() throws Exception {
        assertThat(get(managementPort, "/actuator/health").statusCode()).isEqualTo(200);
        assertThat(get(managementPort, "/actuator/env").statusCode()).isEqualTo(404);
        assertThat(get(managementPort, "/actuator/beans").statusCode()).isEqualTo(404);
        // 업무 포트에는 actuator가 없다(nginx /api/ 프록시로 닿지 않게)
        assertThat(get(serverPort, "/actuator/prometheus").statusCode()).isEqualTo(404);
    }

    @Test
    void logIsJsonWithCommonFields(CapturedOutput output) {
        Logger log = LoggerFactory.getLogger(ObservabilityConfigTest.class);
        String traceId = "4bf92f3577b34da6a3ce929d0e0e4736";

        MDC.put("trace_id", traceId);
        try {
            log.info("observability log check");
        } finally {
            MDC.remove("trace_id");
        }

        List<String> lines = output.getOut().lines().filter(line -> !line.isBlank()).toList();
        assertThat(lines).isNotEmpty();
        JsonNode checked = null;
        for (String line : lines) {
            JsonNode node = JSON.readTree(line);
            if ("observability log check".equals(node.path("message").asString())) {
                checked = node;
            }
        }
        assertThat(checked).as("검사용 로그 줄").isNotNull();
        assertThat(checked.path("@timestamp").asString()).isNotBlank();
        assertThat(checked.path("level").asString()).isEqualTo("INFO");
        assertThat(checked.path("service").asString()).isEqualTo("kkugi-backend");
        assertThat(checked.path("env").asString()).isNotBlank();
        assertThat(checked.path("version").asString()).isNotBlank();
        assertThat(checked.path("trace_id").asString()).isEqualTo(traceId);
    }

    // 테스트 application.yml이 main 파일을 가리므로, 운영 배선(import·관리 포트)은 main 파일을 직접 읽어 확인한다
    @Test
    @SuppressWarnings("unchecked")
    void mainApplicationYmlWiresObservability() throws Exception {
        Map<String, Object> main;
        try (var reader = Files.newBufferedReader(Path.of("src/main/resources/application.yml"))) {
            main = new Yaml().load(reader);
        }
        Map<String, Object> spring = (Map<String, Object>) main.get("spring");
        Map<String, Object> config = (Map<String, Object>) spring.get("config");
        Map<String, Object> management = (Map<String, Object>) main.get("management");
        Map<String, Object> server = (Map<String, Object>) management.get("server");

        assertThat(String.valueOf(config.get("import"))).contains("classpath:observability.yml");
        assertThat(server.get("port")).isEqualTo(8081);
    }

    private static HttpResponse<String> get(int port, String path) throws Exception {
        HttpRequest request =
                HttpRequest.newBuilder(URI.create("http://localhost:" + port + path)).build();
        return HTTP.send(request, HttpResponse.BodyHandlers.ofString());
    }
}
