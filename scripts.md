Below is a **comprehensive Markdown document** that includes everything we’ve discussed—plus two additional [`.gitignore` files](#9---gitignore-for-python-repositories-and-10---gitignore-for-c-projects) for Python and C++ projects. You can copy this entire document to your laptop and then split its contents into the appropriate files and folders. Each section has a description explaining where to put it and how to use it.

---

# Development Environment Setup Files

This document collects all of the configuration files and scripts for your development and blogging workflows. It includes:

1. **Host Dependency Installation Script** – Installs Docker, Git, Visual Studio Code, and Zsh (with Oh My Zsh and Powerlevel10k) on your local Ubuntu system.  
2. **Dockerfiles** –  
   - One for your **C++ development container** (with Clang 20, GoogleTest, fuzz testing, etc.).  
   - One for your **MkDocs blogging container** (to build and serve your MkDocs site).  
3. **.dockerignore Files** –  
   - For your **C++ development repository** (excludes build artifacts, caches, etc.).  
   - For your **MkDocs blog repository** (excludes Git metadata, Python caches, and MkDocs build output).  
4. **VS Code Devcontainer Configurations** – For your two C++ repositories (_sudoku_solver_ and _gtest_ct_).  
5. **VS Code Task for MkDocs Blogging** – A task that builds your MkDocs site in a Docker container, serves it locally on port 8000, and opens Firefox to display your blog.  
6. **.gitignore Files** –  
   - A typical **Python .gitignore** for Python-based projects (like your MkDocs blog repository).  
   - A typical **C++ .gitignore** for your C++ repositories (regardless of using clang, g++, or similar).

Use the instructions below to create each file in the proper location.

---

## 1. Host Dependency Installation Script

**Filename:** `install_host_dependencies.sh`  
**Location:** On your local machine (e.g., in a tools folder).  
**Usage:** Run this script with root privileges to install Docker, Git, VS Code, and Zsh (with Oh My Zsh/Powerlevel10k).

```bash
#!/bin/bash
set -e

# Ensure script is run as root.
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo or as root."
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "Updating package lists..."
apt-get update

echo "Installing essential packages: git, zsh, curl, apt-transport-https, ca-certificates, gnupg, lsb-release..."
apt-get install -y git zsh curl apt-transport-https ca-certificates gnupg lsb-release

#########################
# Docker Installation
#########################
echo "Installing Docker..."
apt-get remove -y docker docker-engine docker.io containerd runc &>/dev/null || true
apt-get install -y ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
if [ -n "$SUDO_USER" ]; then
    usermod -aG docker "$SUDO_USER"
    echo "User '$SUDO_USER' added to the docker group. Please log out and log back in for changes to take effect."
fi

#########################
# Visual Studio Code Installation
#########################
echo "Installing Visual Studio Code..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
rm packages.microsoft.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
apt-get update
apt-get install -y code

#########################
# Oh My Zsh and Powerlevel10k Installation
#########################
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

echo "Setting up Oh My Zsh for user $TARGET_USER (home directory: $TARGET_HOME)..."
if [ ! -d "$TARGET_HOME/.oh-my-zsh" ]; then
    sudo -u "$TARGET_USER" git clone https://github.com/ohmyzsh/ohmyzsh.git "$TARGET_HOME/.oh-my-zsh"
fi
if [ ! -d "$TARGET_HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    sudo -u "$TARGET_USER" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$TARGET_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
fi
if [ ! -f "$TARGET_HOME/.zshrc" ]; then
    sudo -u "$TARGET_USER" cp "$TARGET_HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$TARGET_HOME/.zshrc"
fi

echo "Installation complete! Please log out and log back in for changes to take effect."
```

---

## 2. Dockerfile for C++ Development Container

**Filename:** `Dockerfile`  
**Location:** In your C++ development repository (or a dedicated container folder).  
**Usage:** Use this Dockerfile to build an image containing Clang 20, GoogleTest, fuzz testing, and other C++ tools.

```dockerfile
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
```

**Build & Run Commands:**

```bash
docker build -t my-cpp-dev .
docker run -it my-cpp-dev
```

---

## 3. Dockerfile for MkDocs Blogging Container

**Filename:** `Dockerfile.blog`  
**Location:** In the root directory of your MkDocs blog repository (next to your `requirements.txt`).  
**Usage:** Use this Dockerfile to build an image that installs MkDocs, the Material theme, and related plugins for your blog.

```dockerfile
# Use an official slim version of Python 3.11.
FROM python:3.11-slim

# Install essential build tools and system libraries.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libffi-dev \
    libcairo2-dev \
    libjpeg-dev \
    libpng-dev \
    libxml2-dev \
    libxslt1-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory.
WORKDIR /docs

# Copy requirements and install Python dependencies.
COPY requirements.txt .
RUN python -m pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Expose port 8000 for MkDocs live serve.
EXPOSE 8000

# Default command: start MkDocs live server.
CMD ["mkdocs", "serve", "-a", "0.0.0.0:8000"]
```

**Build & Run Commands:**

```bash
docker build -f Dockerfile.blog -t my-blog .
docker run -p 8000:8000 my-blog
```

---

## 4. .dockerignore for C++ Development Container

**Filename:** `.dockerignore`  
**Location:** In the root of your C++ development repository.  
**Usage:** This file prevents temporary files, build artifacts, and local configuration files from being sent to Docker during the build process.

```dockerignore
# Ignore build artifacts and binaries.
build/
*.o
*.a
*.so
*.exe
*.dll
*.dSYM/
*.out

# Ignore CMake-generated files.
CMakeCache.txt
CMakeFiles/
cmake_install.cmake
Makefile

# Ignore test artifacts.
tests/build/
tests/*.log

# Ignore version control metadata.
.git
.gitignore

# Ignore editor-specific files.
.vscode/
.idea/
.DS_Store

# Ignore Docker-specific override files.
docker-compose.override.yml
```

---

## 5. .dockerignore for MkDocs Blog Repository

**Filename:** `.dockerignore`  
**Location:** In the root of your MkDocs blog repository.  
**Usage:** This file excludes unnecessary files (such as Git metadata, Python caches, and the MkDocs build output) from the Docker build context.

```dockerignore
# Ignore Git metadata.
.git
.gitignore

# Ignore Python caches.
__pycache__
*.pyc
*.pyo

# Ignore Python virtual environments.
venv
env

# Ignore MkDocs build output.
site/

# Ignore editor-specific files.
.vscode/
.idea/

# Ignore OS-generated files.
.DS_Store
```

---

## 6. VS Code Devcontainer Configuration for `sudoku_solver` Repository

**Filename:** `.devcontainer/devcontainer.json`  
**Location:** In the root of your `sudoku_solver` repository (inside a folder named `.devcontainer`).  
**Usage:** This file configures VS Code to open your project inside the C++ development container with all the necessary extensions.

```json
{
    "name": "Sudoku Solver Development",
    "dockerFile": "../Dockerfile",
    "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind",
    "workspaceFolder": "/workspace",
    "remoteUser": "root",
    "extensions": [
        "ms-vscode.cpptools",
        "ms-vscode.cmake-tools",
        "twxs.cmake",
        "jeff-hykin.code-gnu-global",
        "ms-vscode.vscode-clangd"
    ],
    "settings": {
        "C_Cpp.default.compilerPath": "/usr/bin/clang-20",
        "C_Cpp.default.intelliSenseMode": "clang-x64",
        "cmake.generator": "Ninja"
    },
    "postCreateCommand": "cmake --version"
}
```

---

## 7. VS Code Devcontainer Configuration for `gtest_ct` Repository

**Filename:** `.devcontainer/devcontainer.json`  
**Location:** In the root of your `gtest_ct` repository (inside a folder named `.devcontainer`).  
**Usage:** This file configures VS Code to open the _GoogleTest_ project inside the C++ development container.

```json
{
    "name": "GoogleTest Development",
    "dockerFile": "../Dockerfile",
    "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind",
    "workspaceFolder": "/workspace",
    "remoteUser": "root",
    "extensions": [
        "ms-vscode.cpptools",
        "ms-vscode.cmake-tools",
        "twxs.cmake",
        "jeff-hykin.code-gnu-global",
        "ms-vscode.vscode-clangd",
        "vadimcn.vscode-lldb"
    ],
    "settings": {
        "C_Cpp.default.compilerPath": "/usr/bin/clang-20",
        "C_Cpp.default.intelliSenseMode": "clang-x64",
        "cmake.generator": "Ninja"
    },
    "postCreateCommand": "echo 'GoogleTest Development Environment Ready!'"
}
```

---

## 8. VS Code Task for MkDocs Blogging Container

**Filename:** `.vscode/tasks.json`  
**Location:** In the root of your MkDocs blog repository (inside a folder named `.vscode`).  
**Usage:** This task builds your MkDocs image, runs the container (exposing port 8000), waits briefly for the live server to start, and opens Firefox to view your blog. A second task stops the container.

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Serve MkDocs Blog",
      "type": "shell",
      "command": "docker build -f Dockerfile.blog -t my-blog . && docker run -d --name mkdocs_blog -p 8000:8000 --rm my-blog && sleep 3 && firefox http://localhost:8000",
      "problemMatcher": [],
      "group": {
        "kind": "build",
        "isDefault": true
      }
    },
    {
      "label": "Stop MkDocs Blog",
      "type": "shell",
      "command": "docker stop mkdocs_blog",
      "problemMatcher": [],
      "group": {
        "kind": "build",
        "isDefault": false
      }
    }
  ]
}
```

---

## 9. .gitignore for Python Repositories

**Filename:** `.gitignore`  
**Location:** In the root of any Python project (for example, your MkDocs blog repository).  
**Usage:** This file ignores common Python artifacts, caches, virtual environments, and build directories.

```gitignore
# Byte-compiled / optimized / DLL files.
__pycache__/
*.py[cod]
*$py.class

# C extensions.
*.so

# Distribution / packaging.
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
*.egg-info/
.installed.cfg
*.egg

# Installer logs.
pip-log.txt
pip-delete-this-directory.txt

# Unit test / coverage reports.
htmlcov/
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.py,cover
.hypothesis/

# Translations.
*.mo
*.pot

# Django stuff:
*.log
local_settings.py
db.sqlite3

# Flask stuff:
instance/
.webassets-cache

# Scrapy stuff:
.scrapy

# Sphinx documentation.
docs/_build/

# PyBuilder.
target/

# Jupyter Notebook.
.ipynb_checkpoints

# IPython.
profile_default/
ipython_config.py

# Pyenv.
.python-version

# Pipenv.
venv/
ENV/
env/
.env
.venv

# pytest.
.cache/

# mypy.
.mypy_cache/
.dmypy.json
dmypy.json

# Pyre type checker.
.pyre/

# pytype static type analyzer.
.pytype/
```

---

## 10. .gitignore for C++ Projects

**Filename:** `.gitignore`  
**Location:** In the root of any C++ repository (such as your _sudoku_solver_ or _gtest_ct_ projects).  
**Usage:** This file ignores build directories, compiled binaries, temporary files, and editor-specific folders. It works for projects using Clang, g++, or similar compilers.

```gitignore
# Build directories and generated files.
build/
CMakeFiles/
CMakeCache.txt
cmake_install.cmake
Makefile

# Compiled object files, libraries, and binaries.
*.o
*.obj
*.so
*.dll
*.exe
*.out
*.a
*.lib
*.dSYM/

# Precompiled headers.
*.gch
*.pch

# Temporary files.
*.tmp

# Editor and IDE folders.
.vscode/
.idea/

# OS generated files.
.DS_Store
Thumbs.db
```

---

# Final Notes

- **Host Dependency Script:** Run once on your local machine to set up system-level tools.  
- **Dockerfiles:** Build distinct container images for C++ development and MkDocs blogging.  
- **.dockerignore Files:** Ensure only necessary files are included in the Docker build context.  
- **VS Code Devcontainer Configurations:** Open your project repositories inside Docker containers using VS Code’s Remote Containers feature.  
- **VS Code Task for MkDocs:** Quickly build, serve, and preview your MkDocs blog using one-click tasks.  
- **.gitignore Files:** Include the appropriate `.gitignore` file in your Python and C++ repositories to avoid checking in unwanted build artifacts and temporary files.
