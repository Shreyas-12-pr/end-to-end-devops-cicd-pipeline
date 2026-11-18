FROM eclipse-temurin:21-jre-jammy

WORKDIR /app
RUN mkdir -p /tmp && chown 10001:10001 /tmp
COPY --chown=10001:10001 target/app.jar /app/app.jar
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-Djava.io.tmpdir=/tmp", "-jar", "/app/app.jar"]
