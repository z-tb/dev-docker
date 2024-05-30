# Use the official Ubuntu base image
FROM python:3.8-slim-buster

# build arguments from Makefile
ARG USER_UID
ARG USER_GROUP_GID
ARG USER_GROUP_NAME
ARG USER_NAME
ARG USER_SHELL
ARG USER_HOME
ARG PIP_UPGRADE
ARG CONT_APP_MNT

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
        pip3 install --upgrade -r requirements.txt; \
    else \
        pip3 install -r requirements.txt; \
    fi

# get latest updates
RUN apt update && apt dist-upgrade -y

# install some support packages, and sudo
RUN apt-get install sudo \
    net-tools \
    lsb-release \
    curl \
    gnupg \
    wget \
    vim \
    jq \
    make \
    nano \
    procps \
    pylint \
    tree \
    iputils-ping \
    zsh \
    zip \
    git -y

# create a user account, non-root, of the user running the build
#   user gets supplementary sudo group membership
RUN groupadd -g ${USER_GROUP_GID} ${USER_GROUP_NAME} \
 && useradd -u ${USER_UID} -g ${USER_GROUP_GID} -G sudo -m -s ${USER_SHELL} ${USER_NAME} -d ${USER_HOME}

# add sudo NOPASS access in sudoers
# RUN echo '%sudo ALL=(ALL:ALL) NOPASSWD:ALL' > /etc/sudoers.d/sudo-group

# with %sudo, you need to use 'newgrp' after login for some reason, so use the USERNAME here instead
RUN echo "${USER_NAME} ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/sudo-users

# install opentofu - Download the installer script:
RUN cd /tmp/ && curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh && \
   chmod +x install-opentofu.sh && \
   ./install-opentofu.sh --install-method deb
#rm install-opentofu.sh

# lsb-release is needed by Terraform, but causes problems with Python modules
# needed with OpenTofu ?
RUN apt purge lsb-release -y && apt autoremove -y

# create the home directory mount point
RUN mkdir -p /mnt/${USER_HOME}

# switch to non-root build user for shell
USER ${USER_NAME}

# enable custom prompt via alias in /etc/bash.bashrc
# symlink ~/.ssh and .gitconfigfrom mounted $HOME
RUN echo 'pcol' >> ~/.bashrc
RUN test -d /mnt/${USER_HOME} && rm -rfv ~/.ssh
RUN test -d /mnt/${USER_HOME} && ln -s /mnt/${USER_HOME}/.ssh ~/
RUN test -d /mnt/${USER_HOME} && ln -s /mnt/${USER_HOME}/.gitconfig ~/

# if the /$HOME/bin directory exists, link it so .bashrc picks it up and puts in the path
RUN if [ -d "/mnt/${USER_HOME}/bin" ]; then ln -s "/mnt/${USER_HOME}/bin" ~/; fi

# add ~/.aws/credentials and ~/.aws/config
RUN mkdir -p ~/.aws
RUN printf "[default]\nregion = ${AWS_REGION}\noutput = json\n" > ${HOME}/.aws/config
RUN printf "[default]\naws_access_key_id =\naws_secret_access_key =\n" > ${HOME}/.aws/credentials

# Command to run when the container starts
CMD ["/bin/bash"]
