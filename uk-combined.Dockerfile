ARG trud_api_key
ARG hermes=v0.12.681
ARG release_date=2022-5-18

FROM clojure:openjdk-11-tools-deps-1.11.1.1113-buster as build
ARG hermes
WORKDIR /usr/src
RUN echo "Checking out hermes ${hermes}"
RUN git clone --depth 1 --branch "${hermes}" https://github.com/wardle/hermes
WORKDIR /usr/src/hermes
RUN clj -T:build uber :out '"hermes.jar"'

FROM amazoncorretto:11-alpine-jdk as index
ARG trud_api_key
ARG release_date
COPY --from=build /hermes.jar /hermes.jar
RUN mkdir cache
RUN echo "Downloading UK release ${release_date}"
RUN echo ${trud_api_key} >api-key.txt
RUN java -jar hermes.jar --db snomed.db download uk.nhs/sct-clinical cache-dir /cache api-key api-key.txt release-date ${release_date}
RUN java -jar hermes.jar --db snomed.db download uk.nhs/sct-drug-ext cache-dir /cache api-key api-key.txt release-date ${release_date}
RUN java -jar hermes.jar --db snomed.db compact
RUN java -jar hermes.jar --db snomed.db --locale en-GB index

FROM amazoncorretto:11-alpine-jdk
ENV port 8080
COPY --from=builder /hermes.jar /hermes.jar
COPY --from=index /snomed.db /snomed.db
EXPOSE ${port}    # Comment this out if using docker-compose
CMD ["java", "-XX:+UseContainerSupport","-XX:MaxRAMPercentage=85","-XX:+UnlockExperimentalVMOptions","-XX:+UseZGC","-jar","/hermes.jar", "-a", "0.0.0.0", "-d", "snomed.db", "-p", "${port}", "--allowed-origins", "*", "serve"]