
PWD = $(shell pwd)
PIPELINE = pipeline.yaml
PIPELINE_NAME= nats_sink

start:
	docker compose up -d

stop:
	docker compose down

nats_pub:
	docker run -it natsio/nats-box nats pub -s nats://host.docker.internal:4222 test_topic "this is a test message"

nats_pub_json:
	docker run -it natsio/nats-box nats pub -s nats://host.docker.internal:4222 test_topic '{"a": 10, "b": "hello"}'

nats_sub:
	docker run -it natsio/nats-box nats sub -s nats://host.docker.internal:4222 test_topic

cli:
	docker compose exec -it timeplus timeplusd client


# refer to https://docs.timeplus.com/rest.html#tag/Streams-v1beta2/paths/~1v1beta2~1streams/post
create_stream_raw:
	curl  -X POST \
		'http://localhost:8000/local/api/v1beta2/streams' \
		--header 'Accept: */*' \
		--header 'Content-Type: application/json' \
		--data-raw '{ \
			"columns": [ \
				{ \
					"name": "raw",  \
					"type": "string"  \
				}  \
			], \
			"description": "raw stream", \
			"name": "test_stream_raw" \
		}'

# refer to https://docs.timeplus.com/rest.html#tag/Sources-v1beta2/paths/~1v1beta2~1sources/post
create_nats_source_raw:
	curl  -X POST \
		'http://localhost:8000/local/api/v1beta2/sources' \
		--header 'Accept: */*' \
		--header 'Content-Type: application/json' \
		--data-raw '{ \
			"description": "nats source to raw stream", \
			"name": "nats_raw", \
			"properties": { \
				"urls": ["nats://nats:4222"], \
				"subject": "test_topic", \
				"queue":"", \
				"nak_delay":"1s", \
				"prefetch_count":524288, \
				"tls": { \
				"disable": true, \
				"skip_verify_server": true \
				}, \
				"data_type": "text" \
			}, \
			"stream": "test_stream_raw", \
			"type": "nats_jetstream" \
		}'


# refer to https://docs.timeplus.com/rest.html#tag/Streams-v1beta2/paths/~1v1beta2~1streams/post
create_stream_json:
	curl -X POST \
		'http://localhost:8000/local/api/v1beta2/streams' \
		--header 'Accept: */*' \
		--header 'Content-Type: application/json' \
		--data-raw '{ \
		"columns": [ \
			{ \
				"name": "a", \
				"type": "int" \
			}, \
			{ \
				"name": "b", \
				"type": "string" \
			} \
		], \
		"description": "json stream", \
		"name": "test_stream_json" \
		}'

# refer to https://docs.timeplus.com/rest.html#tag/Sources-v1beta2/paths/~1v1beta2~1sources/post
create_nats_source_json:
	curl  -X POST \
		'http://localhost:8000/local/api/v1beta2/sources' \
		--header 'Accept: */*' \
		--header 'Content-Type: application/json' \
		--data-raw '{  \
			"description": "nats source to json stream",  \
			"name": "nats_json",  \
			"properties": {  \
				"urls": ["nats://nats:4222"],  \
				"subject": "test_topic",  \
				"queue":"",  \
				"nak_delay":"1s",  \
				"prefetch_count":524288,  \
				"tls": {  \
					"disable": true,  \
					"skip_verify_server": true  \
				},  \
				"data_type": "json"  \
			},  \
			"stream": "test_stream_json",  \
			"type": "nats_jetstream"  \
		}'


