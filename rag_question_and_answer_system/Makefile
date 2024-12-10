VERSION = $(shell git rev-parse --short HEAD)
BIN_NAME = ragdemo
IMAGE_NAME = $(BIN_NAME):$(VERSION)
DOCKER_ID_USER = timeplus
FULLNAME=$(DOCKER_ID_USER)/${IMAGE_NAME}
FULLNAME_LATEST=$(DOCKER_ID_USER)/$(BIN_NAME):latest

.PHONY: test teste

service:
	uvicorn rag.service:app --port 5001 --host 0.0.0.0 --http h11 --reload

test_embedding:
	curl -X POST http://localhost:5001/embedding -H 'Content-Type: application/json' -d '{"input":["This is a sample input text","I hate u "]}'

index:
	python -m rag.index

docker: Dockerfile
	docker build --build-arg VERSION="$(VERSION)" -t $(IMAGE_NAME) .

docker_run: 
	docker run -p 5001:5001 -e OPENAI_API_KEY=${OPENAI_API_KEY}  $(IMAGE_NAME)

push:
	docker tag $(IMAGE_NAME) $(FULLNAME)
	docker push $(FULLNAME)
	docker tag $(IMAGE_NAME) $(FULLNAME_LATEST)
	docker push $(FULLNAME_LATEST)