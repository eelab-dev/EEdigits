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
RUN cmake .. && \
    make -j$(nproc) && \
    make install

# Stage 4: SymbiYosys (sby) Builder
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

# Stage 5: Final
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    readline \
    zlib \
    tcl \
    python3 \
    py3-click \
    libffi \
    graphviz \
    zip \
    make \
    bash

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

# Copy Sby artifacts
COPY --from=sby-builder /usr/local/bin/sby* /usr/local/bin/
COPY --from=sby-builder /usr/local/share/yosys/python3 /usr/local/share/yosys/python3

# Set working directory
WORKDIR /workspace

# Set default command
CMD ["/bin/sh"]
