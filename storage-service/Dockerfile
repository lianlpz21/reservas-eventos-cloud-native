
FROM eclipse-temurin:17-jre-jammy

RUN groupadd --system app && \
    useradd --system --gid app --no-create-home app

WORKDIR /app

COPY --chown=app:app target/storage-service-1.0.0.jar app.jar

USER app

EXPOSE 8081

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
