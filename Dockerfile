# Use Ubuntu 24.04 LTS as the base image.
FROM ubuntu:24.04

# Avoid interactive prompts during package installation.
ENV DEBIAN_FRONTEND=noninteractive

# Install common development dependencies and tools for adding repositories.
# Added ca-certificates explicitly.
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    ca-certificates \
    software-properties-common \
    build-essential \
    git \
    ninja-build \
    ccache \
    cppcheck \
    doxygen

# Add the LLVM APT repository and install Clang 20 and related tools.
RUN apt-get update && apt-get install -y wget gnupg software-properties-common && \
    # Import the LLVM GPG key.
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    # Add the LLVM repository for Ubuntu 24.04 (Noble)
    add-apt-repository "deb http://apt.llvm.org/noble/ llvm-toolchain-noble main" && \
    # Update package lists again after adding the new repository.
    apt-get update && \
    # Install Clang 20 and related tools.
    # Fallback to Clang 20 or generic clang if 20 is not available.
    apt-get install -y \
    clang-20 \
    clang-tidy-20 \
    clang-format-20 \
    clangd-20 \
    || (echo "Clang 20 not found, attempting Clang 18" && \
        apt-get install -y clang-18 clang-tidy-18 clang-format-18 clangd-18) \
    || (echo "Clang 18 also not found, attempting generic clang from LLVM repo" && \
        apt-get install -y clang clang-tidy clang-format clangd)


# Install IWYU (Include-What-You-Use).
RUN apt-get update && apt-get install -y iwyu

# Install and build GoogleTest.
# CMake is needed here, so ensure it's installed before this step.
RUN apt-get update && apt-get install -y libgtest-dev cmake && \
    cd /usr/src/gtest && mkdir build && cd build && \
    cmake .. && make -j"$(nproc)" && cp lib/*.a /usr/lib
    # Corrected path for gtest libraries

# Install Python3, pip. CMake was installed with gtest.
RUN apt-get update && apt-get install -y python3 python3-pip

# Install gdb and plantuml.
RUN apt-get update && apt-get install -y gdb plantuml

# Build and install Google’s fuzztest.
# Requires CMake, Git, and a C++ compiler (Clang installed above).
RUN git clone https://github.com/google/fuzztest.git /opt/fuzztest && \
    cd /opt/fuzztest && mkdir build && cd build && \
    cmake .. && make -j"$(nproc)" && make install

# Download and configure CPM for CMake dependency management.
# Using latest stable release v0.39.0 from github.com/cpm-cmake/CPM.cmake (as of May 2024)
# Corrected filename and path for CPM.cmake
RUN echo "Attempting to download CPM.cmake from master" && \
    mkdir -p /usr/local/share/cmake/Modules && \
    wget -O /usr/local/share/cmake/Modules/CPM.cmake https://raw.githubusercontent.com/cpm-cmake/CPM.cmake/refs/heads/master/cmake/CPM.cmake

# Install Visual Studio Code and a representative Bash extension.
RUN apt-get update && apt-get install -y apt-transport-https && \
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /usr/share/keyrings/microsoft.gpg > /dev/null && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list && \
    apt-get update && apt-get install -y code

# Install VS Code extension.
RUN useradd -m vscode && \
    chown -R vscode:vscode /home/vscode && \
    # Switch to the vscode user before running code
    su - vscode -c "code --install-extension mads-hartmann.bash-ide-vscode --force --no-sandbox --user-data-dir=/home/vscode/.vscode-server"

# Clean up apt caches.
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Set default command to start an interactive shell.
CMD ["/bin/bash"]

