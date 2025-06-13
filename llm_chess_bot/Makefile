VERSION = $(shell git rev-parse --short HEAD)
BIN_NAME = autogen-agent-chess
IMAGE_NAME = $(BIN_NAME):$(VERSION)
DOCKER_ID_USER = timeplus
FULLNAME=$(DOCKER_ID_USER)/${IMAGE_NAME}
FULLNAME_LATEST=$(DOCKER_ID_USER)/$(BIN_NAME):latest
PWD = $(shell pwd)

timeplus:
	docker run -p 8463:8463 timeplus/timeplus-enterprise:2.9.0-rc.3

builder_driver:
	docker buildx create \
  		--name container \
  		--driver=docker-container

dockerx: Dockerfile
	docker buildx build \
		-t $(FULLNAME) \
		--platform linux/arm64,linux/amd64 \
		--builder container \
		--push .