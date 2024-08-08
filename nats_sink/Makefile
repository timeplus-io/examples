
PWD = $(shell pwd)
PIPELINE = pipeline.yaml
PIPELINE_NAME= nats_sink

start:
	docker compose up -d

stop:
	docker compose down

init:
	docker compose exec timeplus /bin/bash -c 'timeplusd client --multiquery < /script/init.sql'

create:
	yq -o=json $(PWD)/$(PIPELINE) | curl http://localhost:4195/streams/$(PIPELINE_NAME) -X POST  -d  @-

delete:
	curl http://localhost:4195/streams/$(PIPELINE_NAME) -X DELETE 

get:
	curl http://localhost:4195/streams/$(PIPELINE_NAME)

nats_sub:
	docker run -it natsio/nats-box nats sub -s nats://host.docker.internal:4222 test_topic

cli:
	docker compose exec -it timeplus timeplusd client


