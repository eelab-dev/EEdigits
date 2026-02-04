# Stage 1: Icarus Verilog Builder
FROM alpine:latest AS iverilog-builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    bison \
    flex \
    gperf \
    autoconf \
    zlib-dev \
    linux-headers

# Clone Icarus Verilog repository
WORKDIR /build
RUN git clone https://github.com/steveicarus/iverilog.git .

# Build and install
RUN sh autoconf.sh && \
    ./configure && \
    make -j$(nproc) && \
    make install

# Stage 2: Yosys Builder
FROM alpine:latest AS yosys-builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    clang \
    bison \
    flex \
    readline-dev \
    gawk \
    tcl-dev \
    libffi-dev \
    git \
    pkgconf \
    python3 \
    zlib-dev \
    flex-dev

# Clone Yosys repository
WORKDIR /build
RUN git clone https://github.com/YosysHQ/yosys.git .
RUN git submodule update --init --recursive

# Apply fix for missing unistd.h in linux_perf.cc
RUN sed -i '/#include <stdlib.h>/a #include <unistd.h>' passes/cmds/linux_perf.cc

# Build and install
RUN make config-clang && \
    make -j$(nproc) && \
    make install

# Stage 3: Z3 Builder
FROM alpine:latest AS z3-builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    python3 \
    cmake

# Clone Z3 repository
WORKDIR /build
RUN git clone https://github.com/Z3Prover/z3.git .

# Build and install
WORKDIR /build/build
RUN cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local .. && \
    make -j$(nproc) && \
    make install

# Stage 4: Bitwuzla Builder
FROM alpine:latest AS bitwuzla-builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    python3 \
    meson \
    ninja \
    cmake \
    gmp-dev \
    mpfr-dev \
    pkgconf \
    curl \
    tar

# Clone Bitwuzla repository
WORKDIR /build
RUN git clone https://github.com/bitwuzla/bitwuzla.git .

# Configure, build, and install
RUN ./configure.py release --shared --prefix=/usr/local && \
    cd build && \
    ninja -j$(nproc) && \
    ninja install && \
    (strip /usr/local/bin/bitwuzla 2>/dev/null || true) && \
    (strip /usr/local/lib/libbitwuzla*.so* 2>/dev/null || true)

# Stage 5: CVC5 Builder
FROM alpine:latest AS cvc5-builder

# Optional: pin an explicit CVC5 git tag (e.g. cvc5-1.3.2). If unset,
# we automatically resolve the latest stable cvc5-X.Y.Z tag at build time.
ARG CVC5_TAG=

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    python3 \
    py3-pip \
    cmake \
    gmp-dev \
    bash \
    curl \
    zip

# Helper script to resolve latest stable cvc5-X.Y.Z tag.
COPY Docker/scripts/resolve_cvc5_tag.py /usr/local/bin/resolve_cvc5_tag.py
RUN chmod +x /usr/local/bin/resolve_cvc5_tag.py

# Clone CVC5 repository (auto-resolve latest stable tag by default)
WORKDIR /build
RUN set -e; \
    tag="$(CVC5_TAG="$CVC5_TAG" /usr/local/bin/resolve_cvc5_tag.py)"; \
    echo "Using CVC5 tag: $tag"; \
    git clone --branch "$tag" --depth 1 https://github.com/cvc5/cvc5.git .

# Configure, build, and install (production build)
RUN ./configure.sh production --auto-download --prefix=/usr/local --no-pyvenv && \
    cd build && \
    make -j$(nproc) && \
    make install && \
    (strip /usr/local/bin/cvc5 2>/dev/null || true) && \
    (strip /usr/local/lib/libcvc5*.so* /usr/local/lib/libpoly*.so* 2>/dev/null || true)

# Stage 6: SymbiYosys (sby) Builder
FROM alpine:latest AS sby-builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    python3

# Clone SymbiYosys repository
WORKDIR /build
RUN git clone https://github.com/YosysHQ/sby.git .

# Install
RUN make install

# Stage 6: Verible Downloader
FROM alpine:latest AS verible-downloader

RUN apk add --no-cache curl jq tar gzip

WORKDIR /verible

RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
    ASSET_NAME="linux-static-x86_64"; \
    elif [ "$ARCH" = "aarch64" ]; then \
    ASSET_NAME="linux-static-arm64"; \
    else \
    echo "Unsupported architecture: $ARCH"; exit 1; \
    fi && \
    LATEST_URL=$(curl -s https://api.github.com/repos/chipsalliance/verible/releases/latest | jq -r ".assets[] | select(.name | contains(\"$ASSET_NAME\")) | .browser_download_url") && \
    echo "Downloading Verible from $LATEST_URL" && \
    curl -L -s "$LATEST_URL" | tar -xz --strip-components=1 -C /verible

# Stage 7: Final
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    gmp \
    mpfr \
    readline \
    zlib \
    tcl \
    python3 \
    py3-click \
    libffi \
    graphviz \
    zip \
    make \
    bash \
    git

# Copy Icarus Verilog artifacts
COPY --from=iverilog-builder /usr/local/bin/iverilog /usr/local/bin/iverilog
COPY --from=iverilog-builder /usr/local/bin/iverilog-vpi /usr/local/bin/iverilog-vpi
COPY --from=iverilog-builder /usr/local/bin/vvp /usr/local/bin/vvp
COPY --from=iverilog-builder /usr/local/lib/ivl /usr/local/lib/ivl

# Copy Yosys artifacts
COPY --from=yosys-builder /usr/local/bin/yosys* /usr/local/bin/
COPY --from=yosys-builder /usr/local/share/yosys /usr/local/share/yosys

# Copy Z3 artifacts
COPY --from=z3-builder /usr/local/bin/z3 /usr/local/bin/z3
COPY --from=z3-builder /usr/local/lib/libz3* /usr/local/lib/
COPY --from=z3-builder /usr/local/include/z3* /usr/local/include/

# Copy Bitwuzla artifacts
COPY --from=bitwuzla-builder /usr/local/bin/bitwuzla /usr/local/bin/bitwuzla-real
COPY --from=bitwuzla-builder /usr/local/lib/libbitwuzla* /usr/local/lib/

# Copy CVC5 artifacts
COPY --from=cvc5-builder /usr/local/bin/cvc5 /usr/local/bin/cvc5
COPY --from=cvc5-builder /usr/local/lib/libcvc5* /usr/local/lib/
COPY --from=cvc5-builder /usr/local/lib/libpoly* /usr/local/lib/

# Copy Sby artifacts
COPY --from=sby-builder /usr/local/bin/sby* /usr/local/bin/
COPY --from=sby-builder /usr/local/share/yosys/python3 /usr/local/share/yosys/python3

# Copy Verible artifacts
COPY --from=verible-downloader /verible/bin/* /usr/local/bin/

# Yosys smtbmc invokes Bitwuzla with a legacy `--smt2` flag. Newer Bitwuzla
# uses `--lang smt2` instead, so wrap `bitwuzla` to translate.
COPY Docker/scripts/bitwuzla_wrapper.py /usr/local/bin/bitwuzla
RUN chmod +x /usr/local/bin/bitwuzla

# Convenience alias (optional) for explicit SMT2 invocation.
RUN ln -sf /usr/local/bin/bitwuzla /usr/local/bin/bitwuzla-smt2

# Set working directory
WORKDIR /workspace

# Set default command
CMD ["/bin/sh"]
