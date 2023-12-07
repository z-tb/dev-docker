IMAGE_NAME 	 	= aws-image
CONTAINER_NAME 	= aws-tester
HOST_PATH 	    = ./app

build:
	docker build -t $(IMAGE_NAME) .

run:
	docker run -it --name $(CONTAINER_NAME) $(IMAGE_NAME)

runm:
	docker run -it --rm -v ./app:/app/ ${IMAGE_NAME} /bin/bash

stop:
	docker stop $(CONTAINER_NAME)

clean:
	docker rm $(CONTAINER_NAME)
	docker rmi $(IMAGE_NAME)


# vim: set ts=4 sw=4 tw=0 noet :
