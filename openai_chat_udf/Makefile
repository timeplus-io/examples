VERSION = $(shell git rev-parse --short HEAD)
BIN_NAME = chatudf
IMAGE_NAME = $(BIN_NAME):$(VERSION)
DOCKER_ID_USER = timeplus
FULLNAME=$(DOCKER_ID_USER)/${IMAGE_NAME}

.PHONY: test teste

service:
	uvicorn chat.service:app --port 5001 --host 0.0.0.0 --http h11 --reload

test_chat:
	curl -X POST http://localhost:5001/chat -H 'Content-Type: application/json' -d '{"input":["This is a sample input text","I hate u "],"temperature":[0.7,0.5]}'

test_embedding:
	curl -X POST http://localhost:5001/embedding -H 'Content-Type: application/json' -d '{"input":["This is a sample input text","I hate u "]}'

docker: Dockerfile
	docker build --build-arg VERSION="$(VERSION)" -t $(IMAGE_NAME) .

docker_run: 
	docker run -p 5001:5001 -e OPENAI_API_KEY=${OPENAI_API_KEY}  $(IMAGE_NAME)

push:
	docker tag $(IMAGE_NAME) $(FULLNAME)
	docker push $(FULLNAME)