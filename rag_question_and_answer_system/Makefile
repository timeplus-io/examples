VERSION = $(shell git rev-parse --short HEAD)
BIN_NAME = ragdemo
IMAGE_NAME = $(BIN_NAME):$(VERSION)
DOCKER_ID_USER = timeplus
FULLNAME=$(DOCKER_ID_USER)/${IMAGE_NAME}
FULLNAME_LATEST=$(DOCKER_ID_USER)/$(BIN_NAME):latest
PWD = $(shell pwd)

.PHONY: test teste

test_service:
	uvicorn rag.service:app --port 5001 --host 0.0.0.0 --http h11 --reload

test_embedding:
	curl -X POST http://localhost:5001/embedding -H 'Content-Type: application/json' -d '{"input":["This is a sample input text","I hate u "]}'

test_index:
	python -m rag.index

start:
	docker compose up -d

stop:
	docker compose down

update_models:
	docker compose exec -it ollama ollama pull mxbai-embed-large:latest
	docker compose exec -it ollama ollama pull llama3.2:1b

index_docs:
	docker run \
		-e TIMEPLUS_HOST=host.docker.internal \
		-e TIMEPLUS_USER=${TIMEPLUS_USER} \
		-e TIMEPLUS_PASSWORD=${TIMEPLUS_PASSWORD} \
		-e LLM_BASE_URL=http://host.docker.internal:11434/v1/ \
		--volume $(PWD)/timeplus_docs:/docs \
		--entrypoint /bin/bash \
		-it \
		timeplus/ragdemo:latest \
		-c 'python -m rag.index --path /docs'


docker: Dockerfile
	docker build --build-arg VERSION="$(VERSION)" -t $(IMAGE_NAME) .

docker_run: 
	docker run -p 5001:5001 -e OPENAI_API_KEY=${OPENAI_API_KEY}  $(IMAGE_NAME)

push:
	docker tag $(IMAGE_NAME) $(FULLNAME)
	docker push $(FULLNAME)
	docker tag $(IMAGE_NAME) $(FULLNAME_LATEST)
	docker push $(FULLNAME_LATEST)