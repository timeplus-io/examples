VERSION = $(shell git rev-parse --short HEAD)
BIN_NAME = violence-detector-roboflow
IMAGE_NAME = $(BIN_NAME):$(VERSION)
DOCKER_ID_USER = timeplus
FULLNAME=$(DOCKER_ID_USER)/${IMAGE_NAME}
FULLNAME_LATEST=$(DOCKER_ID_USER)/$(BIN_NAME):latest
PWD = $(shell pwd)


start:
	docker compose up -d

stop:
	docker compose down

create_dashboard:
	curl -X POST --user proton:timeplus@t+ -H "Content-Type: application/json" -d @./dashboard/payload.json http://localhost:8000/default/api/v1beta2/dashboards


run_timeplus:
	docker run -d \
		--name timeplus \
		--platform linux/amd64 \
		-p 8000:8000 \
		-p 8463:8463 \
		-p 8123:8123 \
		-v timeplus_data:/timeplus/data/ \
		timeplus/timeplus-enterprise:2.9.0-aitest2

run_inference:
	python server.py


dockerx: Dockerfile
	docker buildx build \
		-t $(FULLNAME) \
		--platform linux/arm64,linux/amd64 \
		--builder container \
		--push .