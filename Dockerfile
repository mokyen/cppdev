# Use Ubuntu 24.04 LTS as the base image.
FROM ubuntu:24.04

# Avoid interactive prompts during package installation.
ENV DEBIAN_FRONTEND=noninteractive

# Install common development dependencies.
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    build-essential \
    git \
    ninja-build \
    ccache \
    cppcheck \
    doxygen

# Install Clang 20 and related clang tools.
RUN apt-get update && apt-get install -y \
    clang-20 \
    clang-tidy-20 \
    clang-format-20 \
    clangd-20

# Install IWYU (Include-What-You-Use).
RUN apt-get update && apt-get install -y iwyu

# Install and build GoogleTest.
RUN apt-get update && apt-get install -y libgtest-dev && \
    cd /usr/src/gtest && mkdir build && cd build && \
    cmake .. && make -j"$(nproc)" && cp *.a /usr/lib

# Install Python3, pip, and CMake.
RUN apt-get update && apt-get install -y python3 python3-pip cmake

# Install gdb and plantuml.
RUN apt-get update && apt-get install -y gdb plantuml

# Build and install Google’s fuzztest.
RUN git clone https://github.com/google/fuzztest.git /opt/fuzztest && \
    cd /opt/fuzztest && mkdir build && cd build && \
    cmake .. && make -j"$(nproc)" && make install

# Download and configure CPM for CMake dependency management.
RUN mkdir -p /usr/local/share/cmake/Modules && \
    wget -qO /usr/local/share/cmake/Modules/CPM.cmake https://raw.githubusercontent.com/cpm-cmake/CPM.cmake/v1.7.4/cpm.cmake

# Install Visual Studio Code and a representative Bash extension.
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /usr/share/keyrings/microsoft.gpg > /dev/null && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list && \
    apt-get update && apt-get install -y code

RUN code --install-extension mads-hartmann.bash-ide-vscode --force

# Clean up apt caches.
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Set default command to start an interactive shell.
CMD ["/bin/bash"]
