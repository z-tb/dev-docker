# Makefile for running a Docker image used for development
# default to dev-test if PROJECT is not set
DEFAULT_PROJECT := devops

# if PROJECT is exported into environment, use it instead, otherwise warn about using default
ifndef PROJECT
$(info $(shell echo "\033[0;33mPROJECT environment variable is not set. Using default value: $(DEFAULT_PROJECT)\033[0m"))
    PROJECT := $(DEFAULT_PROJECT)
else
    $(info $(shell echo "\033[0;32mUsing PROJECT $(PROJECT) from environment\033[0m"))
endif

# if DEBUG=1 is exported, then use additional options for docker build
ifeq ($(DEBUG),1)
    DEBUG_OPTS = --progress=plain
endif

# Define variables for Docker image and container
IMAGE_NAME     := $(PROJECT)-image
IMAGE_VERSION  := latest
CONTAINER_NAME := $(PROJECT)-container

HOST_PATH       = ./apps
CONT_APP_MNT    = /apps

USER_UID        := $(shell id -u)
USER_GROUP_GID  := $(shell id -g)
USER_GROUP_NAME := $(shell id -gn)
USER_NAME       := $(shell id -un)
USER_SHELL      := $(shell echo $$SHELL)
USER_HOME       := $(shell echo $$HOME)
# custom persistent home directory, not your $HOME
PERSIST_HOME    := $(USER_HOME)/.devdocker-home

# Container user defaults to host user unless explicitly overridden
CON_USER    ?= $(USER_NAME)

# ----------------------------------------------------------------------
# supplemental groups for runtime user add to the container user groups
# use current user groups, or define your own here
# ----------------------------------------------------------------------
SUPP_GROUPS := $(shell id -Gn | tr ' ' '\n' | while read g; do \
    gid=$$(getent group "$$g" | cut -d: -f3); \
    [ -n "$$gid" ] && printf "%s:%s," "$$g" "$$gid"; \
done | sed 's/,$$//')


DOCKER_SOCKET      := /var/run/docker.sock
CONT_DOCKER_SOCKET := /var/run/docker.sock
DOCKER_GID         := $(shell getent group docker | cut -d':' -f3)

# eg: make build -e PIP_UPGRADE=true
PIP_UPGRADE   := "false"

AWS_REGION    ?= "us-east-2"

# Docker build options for including optional tools
WITH_AWS_CLI  ?= 1
WITH_TOFU     ?= 1
WITH_BREW     ?= 1
WITH_SPACECTL ?= 0
WITH_GHCLI    ?= 1
WITH_GCP_SDK  ?= 0

# get AWS_REGION from the user's shell environment if it is set
ifeq ($(AWS_REGION),)
    AWS_REGION := $(shell aws configure get region)
endif

# create the HOST_PATH directory
$(shell mkdir -p $(HOST_PATH))

# create persistent home directory for the container user
$(shell mkdir -p $(PERSIST_HOME))

# Check if HOST_PATH directory exists before any build targets
ifeq ($(wildcard $(HOST_PATH)),)
    $(error $(shell echo "\033[0;31mHOST_PATH directory '$(HOST_PATH)' does not exist\033[0m"))
endif

# Common build arguments shared across build targets
BUILD_ARGS = \
    --build-arg USER_UID=$(USER_UID) \
    --build-arg USER_GROUP_GID=$(USER_GROUP_GID) \
    --build-arg USER_GROUP_NAME=$(USER_GROUP_NAME) \
    --build-arg USER_NAME=$(USER_NAME) \
    --build-arg USER_SHELL=$(USER_SHELL) \
    --build-arg USER_HOME=$(USER_HOME) \
    --build-arg WITH_AWS_CLI=$(WITH_AWS_CLI) \
    --build-arg WITH_TOFU=$(WITH_TOFU) \
    --build-arg WITH_BREW=$(WITH_BREW) \
    --build-arg WITH_SPACECTL=$(WITH_SPACECTL) \
    --build-arg WITH_GHCLI=$(WITH_GHCLI) \
    --build-arg WITH_GCP_SDK=$(WITH_GCP_SDK) \
    --build-arg CONT_APP_MNT=$(CONT_APP_MNT) \
    --build-arg IMAGE_NAME=$(IMAGE_NAME) \
    --build-arg IMAGE_VERSION=$(IMAGE_VERSION)

# Make target to echo variable values
show-variables:
	@echo "USER_UID: $(USER_UID)"
	@echo "USER_GROUP_GID: $(USER_GROUP_GID)"
	@echo "USER_GROUP_NAME: $(USER_GROUP_NAME)"
	@echo "USER_NAME: $(USER_NAME)"
	@echo "USER_SHELL: $(USER_SHELL)"
	@echo "USER_HOME: $(USER_HOME)"
	@echo "PERSIST_HOME: $(PERSIST_HOME)"
	@echo "IMAGE_NAME: $(IMAGE_NAME)"
	@echo "IMAGE_VERSION: $(IMAGE_VERSION)"
	@echo "CONTAINER_NAME: $(CONTAINER_NAME)"
	@echo "HOST_PATH: $(HOST_PATH)"
	@echo "CONT_APP_MNT: $(CONT_APP_MNT)"

# Make target to generate a Docker .env file
env:
	@echo "USER_UID=$(USER_UID)" > .env
	@echo "USER_GROUP_GID=$(USER_GROUP_GID)" >> .env
	@echo "USER_GROUP_NAME=$(USER_GROUP_NAME)" >> .env
	@echo "USER_NAME=$(USER_NAME)" >> .env
	@echo "USER_SHELL=$(USER_SHELL)" >> .env
	@echo "USER_HOME=$(USER_HOME)" >> .env
	@echo "PIP_UPGRADE=$(PIP_UPGRADE)" >> .env
	@echo "CONT_APP_MNT=$(CONT_APP_MNT)" >> .env
	@echo "IMAGE_VERSION=$(IMAGE_VERSION)" >> .env
	@echo "IMAGE_NAME=$(IMAGE_NAME)" >> .env
	@echo "AWS_REGION=$(AWS_REGION)" >> .env

# Make target to build the Docker image
build:
	docker build $(DEBUG_OPTS) \
		$(BUILD_ARGS) \
		--build-arg PIP_UPGRADE=$(PIP_UPGRADE) \
		-t $(IMAGE_NAME):$(IMAGE_VERSION) -f ./Dockerfile .

# Make target to rebuild the Docker image with --no-cache option
rebuild:
	docker build --pull --no-cache $(DEBUG_OPTS) \
		$(BUILD_ARGS) \
		--build-arg PIP_UPGRADE=$(PIP_UPGRADE) \
		-t $(IMAGE_NAME):$(IMAGE_VERSION) -f ./Dockerfile .

# Make target to build the Docker image with PIP upgrade for things in the requirements.txt file
build_upgrade:
	docker build $(DEBUG_OPTS) \
		$(BUILD_ARGS) \
		--build-arg PIP_UPGRADE="true" \
		-t $(IMAGE_NAME):$(IMAGE_VERSION) -f ./Dockerfile .


# Make target to run the Docker container with mounted app directory and persistent home (~/.devdocker-home)
run:
	@# Detect SSH Agent on the host and construct flags natively in Make variables
	$(eval SSH_FORWARD_FLAGS := $(if $(SSH_AUTH_SOCK),--env SSH_AUTH_SOCK=$(SSH_AUTH_SOCK) --volume $(SSH_AUTH_SOCK):$(SSH_AUTH_SOCK),))
	$(if $(SSH_AUTH_SOCK),,@echo "⚠️ SSH_AUTH_SOCK not set on host; mount ~/.ssh manually or start an ssh-agent.")

	docker run -it --rm \
		--hostname $(IMAGE_NAME) \
		--user $(USER_UID):$(USER_GROUP_GID) \
		--env USER_UID="$(USER_UID)" \
		--env USER_GROUP_GID="$(USER_GROUP_GID)" \
		--env USER_GROUP_NAME="$(USER_GROUP_NAME)" \
		--env USER_NAME="$(CON_USER)" \
		--env USER_SHELL="$(USER_SHELL)" \
		--env USER_HOME="/home/$(CON_USER)" \
		--env USER_GROUPS="$(SUPP_GROUPS)" \
		$(SSH_FORWARD_FLAGS) \
		--name $(CONTAINER_NAME) \
		--volume $(HOST_PATH):$(CONT_APP_MNT) \
		--volume $(PERSIST_HOME):/home/$(CON_USER) \
		$(IMAGE_NAME):$(IMAGE_VERSION)


# Mount app directory and persistent home (~/.devdocker-home) with host docker socket inside container
rundock:
	$(eval SSH_FORWARD_FLAGS := $(if $(SSH_AUTH_SOCK),--env SSH_AUTH_SOCK=$(SSH_AUTH_SOCK) --volume $(SSH_AUTH_SOCK):$(SSH_AUTH_SOCK),))
	$(if $(SSH_AUTH_SOCK),,@echo "⚠️ SSH_AUTH_SOCK not set on host; mount ~/.ssh manually or start an ssh-agent.")

	docker run -it --rm \
		--hostname $(IMAGE_NAME) \
		--user $(USER_UID):$(USER_GROUP_GID) \
		--env USER_UID="$(USER_UID)" \
		--env USER_GROUPS="$(SUPP_GROUPS)" \
		--env USER_GROUP_GID="$(USER_GROUP_GID)" \
		--env USER_GROUP_NAME="$(USER_GROUP_NAME)" \
		--env USER_NAME="$(CON_USER)" \
		--env USER_SHELL="$(USER_SHELL)" \
		--env USER_HOME="/home/$(CON_USER)" \
		--env USER_GROUPS="$(SUPP_GROUPS)" \
		$(SSH_FORWARD_FLAGS) \
		--name $(CONTAINER_NAME)-docksock \
		--volume $(DOCKER_SOCKET):$(CONT_DOCKER_SOCKET) \
		--volume $(HOST_PATH):$(CONT_APP_MNT) \
		--volume $(PERSIST_HOME):/home/$(CON_USER) \
		$(IMAGE_NAME):$(IMAGE_VERSION)
	

# Make target to connect to the running container
connect:
	docker exec -it $(CONTAINER_NAME) /bin/bash

# Make target to stop the Docker container
stop:
	docker stop $(CONTAINER_NAME)

# Make target to stop and remove the Docker container, and remove the Docker image
clean: stop
	docker rm $(CONTAINER_NAME)
	docker rmi $(IMAGE_NAME)

# Display help message
help:
	@echo "Available targets:"
	@echo "  make build         - Build the Docker image"
	@echo "  make run           - Run the Docker container"
	@echo "  make runm          - Run the Docker container with volume mounted app directory"
	@echo "  make runmh         - Run the Docker container with mounted app directory and persistent home (~/.devdocker-home)"
	@echo "  make runmhdock     - Run the Docker container same as runmh, but with mounted docker socket from host"
	@echo "  make nodemh        - Expose port 3000 for use with nodejs"
	@echo "  make connect       - Connect to the running container"
	@echo "  make stop          - Stop the Docker container"
	@echo "  make clean         - Stop and remove the Docker container, and remove the Docker image"
	@echo "  make help          - Display this help message"
	@echo "  make rebuild       - Build the docker image with --pull and --no-cache option"
	@echo "  make build_upgrade - Build the docker image with OS and PIP upgrade for things in the requirements.txt file"
	@echo "  make env           - Create a .env file for use with docker compose"

# vim: set ts=4 sw=4 tw=0 noet :
