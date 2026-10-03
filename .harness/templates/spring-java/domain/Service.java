package {{base_package}}.domain.{{name_lower}}.service;

import {{base_package}}.domain.{{name_lower}}.dto.request.{{name_pascal}}CreateRequest;
import {{base_package}}.domain.{{name_lower}}.entity.{{name_pascal}};
import {{base_package}}.domain.{{name_lower}}.repository.{{name_pascal}}Repository;
import {{base_package}}.global.error.BusinessException;
import {{base_package}}.global.error.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

// 유스케이스와 트랜잭션 경계를 담당한다. 클래스는 읽기 전용이고 쓰기 메서드에서 @Transactional로 덮어쓴다.
// 응답 DTO(dto.response)를 쓰지 않고 엔티티(또는 service 전용 결과 record)를 돌려준다(ADR-07 규칙 1).
// Servlet API·ResponseEntity 같은 HTTP 표현에 의존하지 않는다. 다른 도메인 상태 변경은 이벤트로 알린다(ADR-08).
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class {{name_pascal}}Service {

    private final {{name_pascal}}Repository {{name_camel}}Repository;

    public {{name_pascal}} get(Long id) {
        // 도메인 전용 예외 클래스는 만들지 않는다. 필요하면 ErrorCode에 코드를 추가한다
        return {{name_camel}}Repository
                .findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
    }

    @Transactional
    public {{name_pascal}} create({{name_pascal}}CreateRequest request) {
        return {{name_camel}}Repository.save({{name_pascal}}.create(request.name()));
    }
}
