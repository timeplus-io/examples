VERSION = $(shell git rev-parse --short HEAD)
BIN_NAME = bluesky
IMAGE_NAME = $(BIN_NAME):$(VERSION)
DOCKER_ID_USER = timeplus
FULLNAME=$(DOCKER_ID_USER)/${IMAGE_NAME}
FULLNAME_LATEST=$(DOCKER_ID_USER)/$(BIN_NAME):latest


test_service:
	uvicorn bluesky.service:app --port 5001 --host 0.0.0.0 --http h11 --reload

test_user:
	curl -X POST http://localhost:5001/user -H 'Content-Type: application/json' -d '{"did":["did:plc:z72i7hdynmk6r22z27h6tvur","did:plc:mawpfrbywnhgnog2fwdjqeb7"]}'


test_post:
	curl -X POST http://localhost:5001/post -H 'Content-Type: application/json' -d '{"cid":["bafyreiax3qmdxlcp2k33k522uecf5qunuj4vok5b2tsczpa4fspe6p5y7u"], "url":["at://did:plc:6igmqrjdv7lvsgmp5h7wikvl/app.bsky.feed.post/3le2lxv4pes23"]}'


docker: Dockerfile
	docker buildx build \
		--no-cache -t $(FULLNAME) \
		--platform linux/arm64,linux/amd64 \
		--builder container \
		--push .
