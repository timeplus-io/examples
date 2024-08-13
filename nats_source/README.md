
This example shows how to create a nats source through Timeplus RESTFul API.

## RAW Format

The format `raw` will store raw text content into the stream which has only one string field called `raw`

1. run `make start` to start the stack
2. run `make create_stream_raw` to create a raw stream named `test_stream_raw`
3. run `make create_nats_source_raw` to create source that read nats from topic `test_topic` into `test_stream_raw` using `raw` format
4. run `select * from test_stream_raw` in the timeplus console UI or cli client
5. run `make nats_pub` to publish some test event to the `test_topic` topic
6. the test events should be displayed in the UI or console of step 4

## JSON Format

The format `json` will try to map the json schema and save related fields into target stream

1. run `make start` to start the stack
2. run `make create_stream_json` to create a raw stream named `test_stream_json`, which has two fields: a:int, b:string
3. run `make create_nats_source_json` to create source that read nats from topic `test_topic` into `test_stream_json` using `json` format
4. run `select * from test_stream_json` in the timeplus console UI or cli client
5. run `make nats_pub_json` to publish some test json event to the `test_topic` topic
6. the test events should be displayed in the UI or console of step 4


## REST Reference

both `stream` and `source` can be managed through RESTFul API, refer to
- `stream` API https://docs.timeplus.com/rest.html#tag/Streams-v1beta2
- `source` API https://docs.timeplus.com/rest.html#tag/Sources-v1beta2 

for supported source and source properties, refer to https://docs.timeplus.com/source 