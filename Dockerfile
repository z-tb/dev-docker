# Use the official Ubuntu base image
FROM python:3.8-slim-buster

# build arguments from Makefile
ARG USER_UID
ARG USER_GROUP_GID
ARG USER_GROUP_NAME
ARG USER_NAME
ARG USER_SHELL
ARG USER_HOME

# Copy custom bash.bashrc additions into the image
COPY etc/bashrc-addition /tmp/

# append bash custom code to /etc/bash.bashrc
RUN cat /tmp/bashrc-addition >> /etc/bash.bashrc && \
    rm /tmp/bashrc-addition 

# Set the working directory to the shared app directory
WORKDIR /app

# python reqs - Python 3 and pip
COPY requirements.txt /app/requirements.txt
RUN pip3 install -r requirements.txt

# get latest updates
RUN apt-get update && apt-get dist-upgrade -y

# install some support packages, and sudo
RUN apt-get install sudo net-tools vim nano zsh git -y

# create a user account, non-root, of the user running the build
#   user gets supplementary sudo group membership
RUN groupadd -g ${USER_GROUP_GID} ${USER_GROUP_NAME} \
 && useradd -u ${USER_UID} -g ${USER_GROUP_GID} -G sudo -m -s ${USER_SHELL} ${USER_NAME} -d ${USER_HOME}

# add sudo NOPASS access in sudoers
# RUN echo '%sudo ALL=(ALL:ALL) NOPASSWD:ALL' > /etc/sudoers.d/sudo-group

# with %sudo, you need to use 'newgrp' after login for some reason, so use the USERNAME here instead
RUN echo "${USER_NAME} ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/sudo-users

# switch to non-root build user for shell
USER ${USER_NAME}

# Command to run when the container starts
CMD ["/bin/bash"]
