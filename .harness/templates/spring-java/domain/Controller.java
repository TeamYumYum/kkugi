package {{base_package}}.domain.{{name_lower}}.controller;

import {{base_package}}.domain.{{name_lower}}.dto.request.{{name_pascal}}CreateRequest;
import {{base_package}}.domain.{{name_lower}}.dto.response.{{name_pascal}}Response;
import {{base_package}}.domain.{{name_lower}}.service.{{name_pascal}}Service;
import {{base_package}}.global.response.ApiResponse;
import jakarta.validation.Valid;
import java.net.URI;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

// HTTP 경계만 담당한다(ADR-07). 응답은 ResponseEntity<ApiResponse<T>>로 통일하고, Service가 돌려준 엔티티를
// 응답 DTO로 바꾼다. 엔티티 타입을 이 클래스에서 직접 쓰지 않는다(harness.json: controller → service·request·response).
@RestController
@RequestMapping("/api/v1/{{name_kebab}}")
@RequiredArgsConstructor
public class {{name_pascal}}Controller {

    private final {{name_pascal}}Service {{name_camel}}Service;

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<{{name_pascal}}Response>> get(@PathVariable("id") Long id) {
        {{name_pascal}}Response response = {{name_pascal}}Response.from({{name_camel}}Service.get(id));
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<{{name_pascal}}Response>> create(
            @Valid @RequestBody {{name_pascal}}CreateRequest request) {
        {{name_pascal}}Response response = {{name_pascal}}Response.from({{name_camel}}Service.create(request));
        return ResponseEntity.created(URI.create("/api/v1/{{name_kebab}}/" + response.id()))
                .body(ApiResponse.ok(response));
    }
}
