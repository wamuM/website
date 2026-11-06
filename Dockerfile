FROM haskell:9.10 AS builder
WORKDIR /build

COPY stack.yaml package.yaml stack.yaml.lock ./

RUN rm -f *.cabal && mkdir -p src 

RUN stack setup --no-nix \ 
 && stack build --no-nix --only-dependencies -j$(nproc)

COPY . .

RUN stack install --no-nix --local-bin-path /out \
 && strip /out/*



FROM debian:bookworm-slim AS runner

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgmp10 \
    ca-certificates \
    netbase \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /out/ /app/

COPY views /app/views
COPY static /app/static
COPY rooms /app/rooms
COPY goodies /app/goodies

RUN useradd -ms /bin/bash webserver && chown -R webserver:webserver /app
USER webserver

EXPOSE 8080
ENTRYPOINT ["/app/webserver"]
