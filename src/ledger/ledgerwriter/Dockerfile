# Imagem do ledgerwriter construída do código. Contexto de build: a raiz do repositório,
# porque o pom.xml da raiz agrega os módulos Java.
FROM maven:3.9-eclipse-temurin-17 AS build
# A imagem do Maven define MAVEN_CONFIG=/root/.m2, e o mvnw deste repositório repassa essa
# variável ao Maven como se fosse uma fase do build.
ENV MAVEN_CONFIG=
WORKDIR /w
COPY mvnw pom.xml ./
COPY .mvn .mvn
COPY src/ledger src/ledger
COPY src/ledgermonolith src/ledgermonolith
RUN --mount=type=cache,target=/root/.m2,sharing=locked \
    ./mvnw -B -q -pl src/ledger/ledgerwriter -am package -DskipTests

FROM eclipse-temurin:17-jre
COPY --from=build /w/src/ledger/ledgerwriter/target/*.jar /app/app.jar
CMD ["java", "-jar", "/app/app.jar"]
