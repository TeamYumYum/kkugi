# syntax=docker/dockerfile:1
# 꾸기 backend 최소 이미지(빌드: JDK 21, 실행: JRE 21).
# infra/docker-compose.yml이 `build: ../backend`로 사용한다. 테스트는 이미지 빌드에서 돌리지 않는다(영역 검증은 ./gradlew build).
# OTel Java Agent는 이미지에 넣지 않는다. 관측 overlay(infra/docker-compose.observability.yml)가 마운트해서 켠다.

FROM eclipse-temurin:21-jdk-noble AS build
WORKDIR /workspace

# 의존성 계층을 소스와 분리해 소스만 바뀌면 재다운로드하지 않는다
COPY gradlew settings.gradle build.gradle ./
COPY gradle gradle
RUN ./gradlew --no-daemon dependencies > /dev/null

COPY src src
RUN ./gradlew --no-daemon bootJar \
    && find build/libs -name '*.jar' ! -name '*-plain.jar' -exec cp {} /workspace/app.jar \;

FROM eclipse-temurin:21-jre-noble
RUN groupadd --system app && useradd --system --gid app --no-create-home app
WORKDIR /app
COPY --from=build /workspace/app.jar app.jar
USER app
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
