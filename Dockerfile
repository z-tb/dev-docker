# Use python slim base image
# https://discuss.python.org/t/information-for-python-users-regarding-emudhra-emsign-ca-certificate-security-incident/109576/60
FROM python:3.15.2-slim

RUN python --version

# Build arguments from Makefile
ARG USER_UID
ARG USER_GROUP_GID
ARG USER_GROUP_NAME
ARG USER_NAME
ARG USER_SHELL
ARG USER_HOME
ARG PIP_UPGRADE
ARG CONT_APP_MNT
ARG IMAGE_VERSION
ARG IMAGE_NAME

# ----------------------------------------------------------------------
# Software installation flags
# ----------------------------------------------------------------------
ARG WITH_AWS_CLI=1
ARG WITH_TOFU=1
ARG WITH_BREW=1
ARG WITH_SPACECTL=0
ARG WITH_GHCLI=1
ARG WITH_GCP_SDK=0

# ----------------------------------------------------------------------
# URLs for external downloads
# ----------------------------------------------------------------------
ARG URL_AWS_CLI="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
ARG URL_SESSION_MANAGER="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb"
ARG URL_TOFU="https://get.opentofu.org/install-opentofu.sh"

# Copy custom bash.bashrc additions into the image
COPY etc/bashrc-addition /tmp/

# Append bash custom code to /etc/bash.bashrc
RUN cat /tmp/bashrc-addition >> /etc/bash.bashrc && \
    rm /tmp/bashrc-addition 

# Set the working directory to the shared app directory
WORKDIR ${CONT_APP_MNT}

# Create a temporary directory for build reports
RUN mkdir -p /tmp/build-report

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# ----------------------------------------------------------------------
# Pre-requisites for Third-Party Repos (gopass, etc)
# ----------------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg2

# ----------------------------------------------------------------------
# Configure Third-Party Repos (gopass + CUDA Key Fix)
# ----------------------------------------------------------------------
RUN if [ -f /etc/apt/trusted.gpg ]; then \
      gpg --no-default-keyring --keyring /etc/apt/trusted.gpg --export 24157E7A > /etc/apt/keyrings/cuda-archive-keyring.gpg 2>/dev/null || true; \
      rm -f /etc/apt/trusted.gpg; \
    fi \
   && printf "\033[0;32mAdding gopass repository...\033[0m\n" \
   && curl -fsSL https://packages.gopass.pw/repos/gopass/gopass-archive-keyring.gpg > /usr/share/keyrings/gopass-archive-keyring.gpg \
   && printf "Types: deb\nURIs: https://packages.gopass.pw/repos/gopass\nSuites: stable\nArchitectures: all amd64 arm64 armhf\nComponents: main\nSigned-By: /usr/share/keyrings/gopass-archive-keyring.gpg\n" > /etc/apt/sources.list.d/gopass.sources

# Install core packages and tools
RUN apt-get update && apt-get install -y \
    ansible \
    ansible-core \
    awscli \
    binutils \
    build-essential \
    curl \
    dnsutils \
    file \
    git \
    gopass \
    gnupg \
    iproute2 \
    iputils-ping \
    isort \
    jq \
    libffi-dev \
    locales \
    lsb-release \
    make \
    mandoc \
    nano \
    net-tools \
    pass \
    procps \
    pkg-config \
    pylint \
    python3 \
    python3-astroid \
    python3-boto3 \
    python3-botocore \
    python3-build \
    python3-certifi \
    python3-cffi \
    python3-charset-normalizer \
    python3-click \
    python3-colorama \
    python3-cryptography \
    python3-dateutil \
    python3-dill \
    python3-docutils \
    python3-idna \
    python3-isort \
    python3-jinja2 \
    python3-jmespath \
    python3-markupsafe \
    python3-mccabe \
    python3-packaging \
    python3-pip \
    python3-platformdirs \
    python3-pyasn1 \
    python3-pycparser \
    python3-pyproject-hooks \
    python3-pytest \
    python3-requests \
    python3-resolvelib \
    python3-rsa \
    python3-s3transfer \
    python3-six \
    python3-tomli \
    python3-tomlkit \
    python3-typing-extensions \
    python3-urllib3 \
    python3-venv \
    python3-yaml \
    rsync \
    sqlite3 \
    strace \
    sudo \
    tree \
    tzdata \
    unzip \
    vim \
    wget \
    zip \
    zsh \
    >/dev/null \
    && sed -i 's/^# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen en_US.UTF-8 >/dev/null \
    && rm -rf /var/lib/apt/lists/*


ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANGUAGE=en_US:en    

# Python reqs - Python 3 and pip
COPY requirements.txt ${CONT_APP_MNT}/requirements.txt

# Install Python deps/compatibility
RUN python -m pip install --no-cache-dir -r requirements.txt \
    && python -m pip check

# Golang environment setup
ENV GO_VERSION=1.23.3 

# golang https://go.dev/dl/ #
RUN wget https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz -P /tmp \
    && tar -C /usr/local -xvzf /tmp/go${GO_VERSION}.linux-amd64.tar.gz \
    && rm /tmp/go${GO_VERSION}.linux-amd64.tar.gz

# Go env vars
ENV PATH=$PATH:/usr/local/go/bin
ENV GOROOT=/usr/local/go

# Put Go it in the path
RUN ln -s ${GOROOT}/bin/go /usr/local/bin/ \
    && go version

# Create non-root user matching host user attributes
RUN groupadd -g ${USER_GROUP_GID} ${USER_GROUP_NAME} \
    && useradd -u ${USER_UID} -g ${USER_GROUP_GID} -G sudo -m -s ${USER_SHELL} -d /home/${USER_NAME} ${USER_NAME}

# Add sudo NOPASS access in sudoers
RUN echo "${USER_NAME} ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/sudo-users

# Install Terraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update \
    && apt-get install -y terraform

# lsb-release used to cause a problem with terraform ...
RUN apt-get purge lsb-release -y && apt-get autoremove -y

# Install AWS CLI
RUN if [ "${WITH_AWS_CLI}" = "1" ]; then \
      printf "\033[0;32mDownloading AWS Cli...\033[0m\n" && \
      cd /tmp && curl -fsSL --retry 5 --retry-delay 3 --retry-max-time 60 ${URL_AWS_CLI} -o awscliv2.zip && \
      unzip awscliv2.zip >/dev/null && \
      printf "\033[0;32mInstalling AWS Cli...\033[0m\n" && \
      ./aws/install >/dev/null && \
      curl -fsSL --retry 5 --retry-delay 3 --retry-max-time 60 ${URL_SESSION_MANAGER} -o plugin.deb && dpkg -i plugin.deb && \
      printf "\033[0;32mAWS Cli installed OK\033[0m\n" && \
      printf "  %-15s : \033[0;32mInstalled OK\033[0m\n" "AWS CLI" > /tmp/build-report/02-aws; \
    else \
      printf "\033[0;33mSkipping AWS Cli installation\033[0m\n" && \
      printf "  %-15s : \033[0;33mSkipped\033[0m\n" "AWS CLI" > /tmp/build-report/02-aws; \
    fi

# Install OpenTofu
RUN if [ "${WITH_TOFU}" = "1" ]; then \
      printf "\033[0;32mInstalling OpenTofu...\033[0m\n" && \
      cd /tmp && curl -fsSL --retry 5 --retry-delay 3 --retry-max-time 60 ${URL_TOFU} -o install.sh && \
      chmod +x install.sh && ./install.sh --install-method deb && rm install.sh && \
      printf "\033[0;32mOpenTofu installed OK\033[0m\n" && \
      printf "  %-15s : \033[0;32mInstalled OK\033[0m\n" "OpenTofu" > /tmp/build-report/03-tofu; \
    else \
      printf "\033[0;33mSkipping OpenTofu installation\033[0m\n" && \
      printf "  %-15s : \033[0;33mSkipped\033[0m\n" "OpenTofu" > /tmp/build-report/03-tofu; \
    fi   

# Install GCP SDK
RUN if [ "${WITH_GCP_SDK}" = "1" ]; then \
      curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | gpg --dearmor -o /etc/apt/keyrings/google-cloud.gpg \
      && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-cloud.gpg] \
      https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
      && apt-get update \
      && apt-get install -y google-cloud-cli \
      && gcloud --version \
    else \
      printf "\033[0;33mSkipping GCP SDK installation\033[0m\n" && \
      printf "  %-15s : \033[0;33mSkipped\033[0m\n" "GCP SDK" > /tmp/build-report/04-gcp; \
    fi

# ----------------------------------------------------------------------
# Homebrew - needed for spacectl
# ----------------------------------------------------------------------
# Conditional condition updated to exclude WITH_GHCLI
RUN if [ "${WITH_BREW}" = "1" ] || [ "${WITH_SPACECTL}" = "1" ]; then \
      printf "\033[0;32mCreating brew user...\033[0m\n" && \
      groupadd -r brew && \
      useradd -r -g brew -m -s /bin/bash brew && \
      mkdir -p /home/linuxbrew/.linuxbrew && \
      chown -R brew:brew /home/linuxbrew && \
      \
      printf "\033[0;32mInstalling Homebrew...\033[0m\n" && \
      su - brew -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' && \
      test -x /home/linuxbrew/.linuxbrew/bin/brew || { echo "❌ brew not found after install"; exit 1; } && \
      su - brew -c '/home/linuxbrew/.linuxbrew/bin/brew --version' && \
      printf "\033[0;32mHomebrew installed OK\033[0m\n" && \
      printf "  %-15s : \033[0;32mInstalled OK\033[0m\n" "Homebrew" > /tmp/build-report/07-brew; \
    else \
      printf "\033[0;33mSkipping Homebrew installation\033[0m\n" && \
      printf "  %-15s : \033[0;33mSkipped\033[0m\n" "Homebrew" > /tmp/build-report/07-brew; \
    fi    

# Install spacectl via Homebrew
RUN if [ "${WITH_SPACECTL}" = "1" ]; then \
      echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /etc/bash.bashrc && \
      su - brew -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
        brew tap spacelift-io/spacelift && \
        brew install spacelift-io/spacelift/spacectl && \
        spacectl version' && \
      printf "\033[0;32mspacectl installed OK\033[0m\n" && \
      printf "  %-15s : \033[0;32mInstalled OK\033[0m\n" "spacectl" > /tmp/build-report/08-spacectl; \
    else \
      printf "\033[0;33mSkipping spacectl installation\033[0m\n" && \
      printf "  %-15s : \033[0;33mSkipped\033[0m\n" "spacectl" > /tmp/build-report/08-spacectl; \
    fi

# ----------------------------------------------------------------------
# Install GitHub CLI via official APT repository
# ----------------------------------------------------------------------
RUN if [ "${WITH_GHCLI}" = "1" ]; then \
      printf "\033[0;32mInstalling GitHub CLI via APT...\033[0m\n" && \
      mkdir -p /etc/apt/keyrings && \
      wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
      chmod 644 /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
      apt-get update && \
      apt-get install -y gh && \
      rm -rf /var/lib/apt/lists/* && \
      gh --version && \
      printf "\033[0;32mGitHub CLI installed OK\033[0m\n" && \
      printf "  %-15s : \033[0;32mInstalled OK\033[0m\n" "GitHub CLI" > /tmp/build-report/09-ghcli; \
    else \
      printf "\033[0;33mSkipping GitHub CLI installation\033[0m\n" && \
      printf "  %-15s : \033[0;33mSkipped\033[0m\n" "GitHub CLI" > /tmp/build-report/09-ghcli; \
    fi

# ----------------------------------------------------------------------
# Install 1Password op CLI
# ----------------------------------------------------------------------
RUN set -eux \
    && curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
        gpg --dearmor --batch --yes \
            --output /usr/share/keyrings/1password-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main" \
        > /etc/apt/sources.list.d/1password.list \
    && apt-get update -qq \
    && apt-get install -y -qq 1password-cli >/dev/null \
    && op --version

# ----------------------------------------------------------------------
# Install epass utility
# ----------------------------------------------------------------------
RUN printf "\033[0;32mInstalling epass utility from GitHub...\033[0m\n" \
   && curl -fsSL "https://raw.githubusercontent.com/z-tb/linuxadmin/refs/heads/main/epass/epass" -o /usr/local/bin/epass \
   && chmod +x /usr/local/bin/epass \
   && printf "\033[0;32mepass utility installed OK\033[0m\n"

# Docker client install for docker-in-docker socket mapping
RUN curl -fsSL https://get.docker.com | sh

# Copy entrypoint script into image (and any other utils we place there)
COPY ./usr/local/bin/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*

# Clone the emudhra repo and copy scripts into /usr/local/bin/ for runtime use
RUN git clone --depth 1 https://github.com/z-tb/emudhra-checks.git /tmp/emudhra-checks \
    && cp /tmp/emudhra-checks/*.py /usr/local/bin/ 2>/dev/null || true \
    && cp /tmp/emudhra-checks/*.sh /usr/local/bin/ 2>/dev/null || true \
    && chmod +x /usr/local/bin/* \
    && rm -rf /tmp/emudhra-checks

# Add default ~/.aws/config
RUN mkdir -p ~/.aws \
    && printf "[default]\nregion = ${AWS_REGION}\noutput = json\n" > ${HOME}/.aws/config \
    && printf "[default]\naws_access_key_id =\naws_secret_access_key =\n" > ${HOME}/.aws/credentials


# run entrypoint as root which will drop to the $USER in the shell script
USER root

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
