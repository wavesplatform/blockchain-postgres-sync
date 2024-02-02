FROM rust:1.75 AS builder
WORKDIR /app

RUN rustup component add rustfmt
RUN apt-get update && apt-get install -y protobuf-compiler

COPY Cargo.* ./
COPY ./src ./src
COPY ./migrations ./migrations

RUN cargo build --release


FROM debian:12 as runtime
WORKDIR /app

RUN apt-get update && apt-get install -y curl openssl libssl-dev libpq-dev postgresql-client
RUN /usr/sbin/update-ca-certificates

COPY --from=builder /app/target/release/consumer ./consumer
COPY --from=builder /app/target/release/migration ./migration
COPY --from=builder /app/migrations ./migrations/


CMD ['./consumer']
