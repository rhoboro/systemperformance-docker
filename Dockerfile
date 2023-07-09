# https://github.com/linuxkit/linuxkit/blob/master/docs/kernels.md
# https://github.com/linuxkit/linuxkit/blob/master/kernel/Dockerfile.perf
FROM linuxkit/kernel:5.15.27 AS ksrc
FROM linuxkit/kernel:5.15.27-builder AS build
RUN apk add \
    argp-standalone \
    bash \
    bc \
    binutils-dev \
    bison \
    build-base \
    diffutils \
    flex \
    gmp-dev \
    installkernel \
    kmod \
    elfutils-dev \
    findutils \
    libelf-static \
    mpc1-dev \
    mpfr-dev \
    python3 \
    sed \
    tar \
    xz \
    xz-dev \
    zlib-dev \
    zlib-static

COPY --from=ksrc /linux.tar.xz /kernel-headers.tar /
RUN tar xf linux.tar.xz && \
    tar xf kernel-headers.tar

WORKDIR /linux

RUN mkdir -p /out && \
    make -C tools/perf LDFLAGS=-static V=1 && \
    strip tools/perf/perf && \
    cp tools/perf/perf /out


FROM ubuntu:23.04

# https://qiita.com/a-tsu/items/c32d4d8c472ab4f02421
RUN touch /etc/apt/apt.conf.d/99fixbadproxy && \
 echo "Acquire::http::Pipeline-Depth 0;" >> /etc/apt/apt.conf.d/99fixbadproxy && \
 echo "Acquire::http::No-Cache true;" >> /etc/apt/apt.conf.d/99fixbadproxy && \
 echo "Acquire::BrokenProxy    true;" >> /etc/apt/apt.conf.d/99fixbadproxy

# bpfcc-tools binaries are located on /sbin with -bpfcc extension
RUN apt-get update && apt-get install -y \
 auditd \
 bpfcc-tools \
 bpftrace \
 ethtool \
 iproute2 \
 make \
 net-tools \
 nicstat \
 numactl \
 perf-tools-unstable \
 python3-venv \
 strace \
 sysstat \
 tiptop \
 trace-cmd \
 vim \
 wget \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /
COPY --from=ksrc /kernel-dev.tar /
# It is unclear how much this version mismatch affects the results.
RUN tar xf kernel-dev.tar && rm kernel-dev.tar \
 && ln -s /usr/src/linux-headers-5.15.27-linuxkit /usr/src/linux-headers-5.15.49-linuxkit

COPY --from=build /out/perf /usr/bin/perf

RUN wget -O - https://raw.githubusercontent.com/brendangregg/bpf-perf-tools-book/master/originals/Ch13_Applications/pmlock.bt | sed -e 's|#!/usr/local/bin/bpftrace|#!/usr/bin/bpftrace|g' -e 's/x86_64-linux-gnu/aarch64-linux-gnu/g' > /usr/local/bin/pmlock.bt \
 && chmod +x /usr/local/bin/pmlock.bt
RUN wget -O - https://raw.githubusercontent.com/brendangregg/bpf-perf-tools-book/master/originals/Ch13_Applications/pmheld.bt | sed -e 's|#!/usr/local/bin/bpftrace|#!/usr/bin/bpftrace|g' -e 's/x86_64-linux-gnu/aarch64-linux-gnu/g' > /usr/local/bin/pmheld.bt \
 && chmod +x /usr/local/bin/pmheld.bt

# Allow ptrace(2) to attach to processes.
RUN sed -i 's/^kernel.yama.ptrace_scope = 1$/kernel.yama.ptrace_scope = 0/g' /etc/sysctl.d/10-ptrace.conf

# Enable sar
RUN sed -i 's/^ENABLED="false"$/ENABLED="true"/g' /etc/default/sysstat \
 && sed -i 's|^5-55/10 * * * * root command -v debian-sa1 > /dev/null && debian-sa1 1 1$|*/5 * * * * root command -v debian-sa1 > /dev/null && debian-sa1 1 1 -S ALL|g' /etc/cron.d/sysstat \
 && service sysstat restart

WORKDIR /root

# echo 0 > /proc/sys/kernel/kptr_restrict
