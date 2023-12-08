IMAGE_NAME 	 	= dev-test-image
IMAGE_VERSION   = latest
CONTAINER_NAME 	= dev-test-container
HOST_PATH 	    = ./app
USER_UID 		:= $(shell id -u)
USER_GROUP_GID 	:= $(shell id -g)
USER_GROUP_NAME := $(shell id -gn)
USER_NAME 		:= $(shell id -un)
USER_SHELL 		:= $(shell echo $$SHELL)
USER_HOME 		:= $(shell echo $$HOME)

# Make target to echo variable values
show-variables:
	@echo "USER_UID: $(USER_UID)"
	@echo "USER_GROUP_GID: $(USER_GROUP_GID)"
	@echo "USER_GROUP_NAME: $(USER_GROUP_NAME)"
	@echo "USER_NAME: $(USER_NAME)"
	@echo "USER_SHELL: $(USER_SHELL)"
	@echo "USER_HOME: $(USER_HOME)"
	@echo "IMAGE_NAME: $(IMAGE_NAME)"
	@echo "CONTAINER_NAME: $(CONTAINER_NAME)"
	@echo "HOST_PATH: $(HOST_PATH)"

build:    
	docker build \
		--build-arg USER_UID=$(USER_UID) \
		--build-arg USER_GROUP_GID=$(USER_GROUP_GID) \
		--build-arg USER_GROUP_NAME=$(USER_GROUP_NAME) \
		--build-arg USER_NAME=$(USER_NAME) \
		--build-arg USER_SHELL=$(USER_SHELL) \
		--build-arg USER_HOME=$(USER_HOME) \
		-t $(IMAGE_NAME):${IMAGE_VERSION} -f ./Dockerfile .

run:
	docker run -it --rm \
	--user ${USER_UID}:${USER_GROUP_GID}  \
	--name $(CONTAINER_NAME) \
	$(IMAGE_NAME):${IMAGE_VERSION}

runm:
	docker run -it --rm \
	--user ${USER_UID}:${USER_GROUP_GID} \
	--name ${CONTAINER_NAME} \
	--volume ./app:/app/ \
	${IMAGE_NAME}:${IMAGE_VERSION}

stop:
	docker stop $(CONTAINER_NAME)

clean: stop
	docker rm $(CONTAINER_NAME)
	docker rmi $(IMAGE_NAME)

# Display help message
help:
	@echo "Available targets:"
	@echo "  make build       - Build the Docker image"
	@echo "  make run         - Run the Docker container"
	@echo "  make runm        - Run the Docker container with volume mounted app directory"
	@echo "  make stop        - Stop the Docker container"
	@echo "  make clean       - Stop and remove the Docker container, and remove the Docker image"
	@echo "  make help        - Display this help message"
# vim: set ts=4 sw=4 tw=0 noet :
