package com.nyamnyam.backend.global.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

/**
 * 보안 필터 체인의 최소 골격.
 *
 * <p><b>D(Spring 홈) 확정 전 초안.</b> 세션 없는(stateless) REST API만 전제로 한다. 인증 방식(JWT·OAuth 카카오/구글, 토큰 저장
 * 위치)은 아직 정하지 않았다.
 *
 * <p>TODO(1주차 이후, D·C): 인증 방식이 정해지면 {@code anyRequest().permitAll()}을 {@code authenticated()}로 바꾸고
 * 인증 필터와 401·403 응답(ApiResponse 모양)을 붙인다. 지금은 모든 요청을 허용한다.
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    /** 인증 없이 열어 두는 경로. 인증 도입 뒤에도 유지된다. */
    static final String[] PUBLIC_PATHS = {
        "/actuator/health", "/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html"
    };

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http.csrf(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .logout(AbstractHttpConfigurer::disable)
                .sessionManagement(
                        session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(
                        auth ->
                                auth.requestMatchers(PUBLIC_PATHS)
                                        .permitAll()
                                        // TODO: 인증 방식 확정 후 authenticated()로 바꾼다(1주차 임시 전체 허용)
                                        .anyRequest()
                                        .permitAll());
        return http.build();
    }
}
