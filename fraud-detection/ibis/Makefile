VERSION = dev

BIN_NAME = timeplus-ibis
IMAGE_NAME = $(BIN_NAME):$(VERSION)
DOCKER_ID_USER = timeplus
FULLNAME=$(DOCKER_ID_USER)/${IMAGE_NAME}

PWD = $(shell pwd)

.PHONY: docker

docker: Dockerfile
	docker build  -t $(IMAGE_NAME) .