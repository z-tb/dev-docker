# Use the official Ubuntu base image
FROM python:3.8-slim-buster

# create a user account, non-root
RUN useradd -ms /bin/bash tux

# Give sudo access
RUN usermod -aG sudo tux

# Copy custom bash.bashrc additions into the image
COPY etc/bashrc-addition /tmp/
 
# Set the working directory
WORKDIR /app

# python reqs
COPY requirements.txt /app/requirements.txt
RUN pip3 install -r requirements.txt

# Install Python 3 and pip
RUN apt-get update && apt-get dist-upgrade -y

# install some support packages
RUN apt-get install sudo net-tools vim nano zsh git -y

# add tux user to sudoers
RUN echo '%sudo ALL=(ALL:AzLL) NOPASSWD:ALL' > /etc/sudoers.d/sudo-group

# append bash custom code to /etc/bash.bashrc
RUN cat /tmp/bashrc-addition >> /etc/bash.bashrc && \
    rm /tmp/bashrc-addition
    
# switch to non-root user for shell
USER tux

# Command to run when the container starts
CMD ["/bin/bash"]

