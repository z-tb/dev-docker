# Use python slim 3.10 base image
FROM python:3.10-slim

RUN python --version

# build arguments from Makefile
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


# Copy custom bash.bashrc additions into the image
COPY etc/bashrc-addition /tmp/

# append bash custom code to /etc/bash.bashrc
RUN cat /tmp/bashrc-addition >> /etc/bash.bashrc && \
    rm /tmp/bashrc-addition 

# Set the working directory to the shared app directory
WORKDIR ${CONT_APP_MNT}

# python reqs - Python 3 and pip
COPY requirements.txt ${CONT_APP_MNT}/requirements.txt

# install or upgrade via pip
RUN if [ "${PIP_UPGRADE}" = "true" ]; then \
        pip3 install --upgrade pip; \
        pip3 install --upgrade -r requirements.txt; \
        pip3 freeze > requirements.txt; \
    else \
        pip3 install -r requirements.txt; \
    fi

# don't bother prompting with installer questions
ENV DEBIAN_FRONTEND=noninteractive

# update apt
RUN apt update

# This seems like a good security measure but causes severe bloat in the docker layers.
# It's better to make sure you have the most up-to-date base image instead.
# RUN apt update && apt dist-upgrade -y

# install some support packages, and sudo
RUN apt-get install sudo \
    net-tools \
    dnsutils \
    mandoc \
    lsb-release \
    curl \
    gnupg \
    wget \
    vim \
    jq \
    make \
    nano \
    procps \
    tree \
    rsync \
    sqlite3 \
    iputils-ping \
    zsh \
    zip \
    git -y

RUN python --version

### golang https://go.dev/dl/ #
ENV GO_VERSION=1.23.3 

# download/install
RUN wget https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz -P /tmp \
    && tar -C /usr/local -xvzf /tmp/go${GO_VERSION}.linux-amd64.tar.gz \
    && rm /tmp/go${GO_VERSION}.linux-amd64.tar.gz

# Go env vars
ENV PATH=$PATH:/usr/local/go/bin
ENV GOROOT=/usr/local/go

# put it in the path
RUN sudo ln -s ${GOROOT}/bin/go /usr/local/bin/ \
    && go version

# create a user account, non-root, of the user running the build
#   user gets supplementary sudo group membership
RUN groupadd -g ${USER_GROUP_GID} ${USER_GROUP_NAME} \
    && useradd -u ${USER_UID} -g ${USER_GROUP_GID} -G sudo -m -s ${USER_SHELL} ${USER_NAME} -d ${USER_HOME}

# add sudo NOPASS access in sudoers
# RUN echo '%sudo ALL=(ALL:ALL) NOPASSWD:ALL' > /etc/sudoers.d/sudo-group

# with %sudo, you need to use 'newgrp' after login user USER_NAME works also. Otherwise, use the '--group-add xxxx' at docker run
RUN echo "${USER_NAME} ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/sudo-users

# install opentofu - Download the installer script:
RUN cd /tmp/ && curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh && \
   chmod +x install-opentofu.sh && \
   ./install-opentofu.sh --install-method deb && \
   rm install-opentofu.sh

# install Terraform - works on Bullseye now
RUN wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list \
    && sudo apt update \
    && sudo apt install terraform

# lsb-release is needed by Terraform, but causes problems with Python modules needed by OpenTofu ?
RUN apt purge lsb-release -y && apt autoremove -y

# install v2 of aws cli / aws cli session manager plugin
# https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.htm
RUN cd /tmp && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "/tmp/session-manager-plugin.deb" && \
    unzip awscliv2.zip && \
    dpkg -i /tmp/session-manager-plugin.deb && \
    ./aws/install

 
# Install GCP SDK
RUN wget -q -O - https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - \
    && echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update && apt-get install google-cloud-cli -y \
    && gcloud --version

### docker install for docker-in-docker, ecr uploads/etc (see runmhdock make target)
RUN curl -fsSL https://get.docker.com | sh

# create the home directory mount point
RUN mkdir -p /mnt/${USER_HOME}

# switch to non-root build user for shell
USER ${USER_NAME}

# enable custom prompt via alias in /etc/bash.bashrc
# symlink ~/.ssh and .gitconfigfrom mounted $HOME
RUN echo 'pcol' >> ~/.bashrc \
    && test -d /mnt/${USER_HOME} && rm -rfv ~/.ssh \
    && test -d /mnt/${USER_HOME} && ln -s /mnt/${USER_HOME}/.ssh ~/ \
    && test -d /mnt/${USER_HOME} && ln -s /mnt/${USER_HOME}/.gitconfig ~/

# if the /$HOME/bin directory exists, link it so .bashrc picks it up and puts in the path
RUN if [ -d "/mnt/${USER_HOME}/bin" ]; then ln -s "/mnt/${USER_HOME}/bin" ~/; fi

# add ~/.aws/credentials and ~/.aws/config
RUN mkdir -p ~/.aws \
    && printf "[default]\nregion = ${AWS_REGION}\noutput = json\n" > ${HOME}/.aws/config \
    && printf "[default]\naws_access_key_id =\naws_secret_access_key =\n" > ${HOME}/.aws/credentials

# Command to run when the container starts
CMD ["/bin/bash"]
