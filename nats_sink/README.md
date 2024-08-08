
This example shows how to create a connector pipeline (benthos) to send data from timeplusd MV to a nats subject.

the test pipeline is simple

```yaml
input:
  proton:
    proton_addr: localhost
    query_id: "test_nats_tp_sink"
    source_mv: mv_device_5s
    ckpt_interval: 10
    ckpt_type: none
pipeline:
  threads: 1
output:
  label: ""
  nats:
    urls:
      - nats://nats-server:4222
    subject: test_topic
    max_in_flight: 64
```

user can specify
- `input.proton.query_id` : a unique name to specify the running query in the pipeline that pulls data from MV
- `input.proton.source_mv` : the mv data user want to pull and send to nats
- `input.proton.ckpt_interval` : how often to do the checkpointing to avoid data lose
- `output.nats.subject` : the nats subject where data will send to.

To run query this example

1. run `make start` to start the docker stack the containing a single node timeplus enterprise and a nats server
2. run `make init` which will create a randon stream and a test MV using this random stream
3. run `make create` which will create the data sink pipeline that read data from MV and send data to nats 
4. run `make nats_sub` to verify that data has been send to the nats subject

if everything works, following result will be showing

```
docker run -it natsio/nats-box nats sub -s nats://host.docker.internal:4222 test_topic
18:31:46 Subscribing on test_topic 
[#1] Received on "test_topic"
{"_tp_time":"2024-08-08T18:31:47.004Z","device":"device0","max_temperature":99.6,"ts":"2024-08-08T18:31:42Z"}


[#2] Received on "test_topic"
{"_tp_time":"2024-08-08T18:31:47.004Z","device":"device1","max_temperature":99.7,"ts":"2024-08-08T18:31:42Z"}


[#3] Received on "test_topic"
{"_tp_time":"2024-08-08T18:31:47.004Z","device":"device2","max_temperature":99.8,"ts":"2024-08-08T18:31:42Z"}


[#4] Received on "test_topic"
{"_tp_time":"2024-08-08T18:31:47.004Z","device":"device3","max_temperature":99.9,"ts":"2024-08-08T18:31:42Z"}


[#5] Received on "test_topic"
{"_tp_time":"2024-08-08T18:31:49.004Z","device":"device0","max_temperature":99.6,"ts":"2024-08-08T18:31:44Z"}


[#6] Received on "test_topic"
{"_tp_time":"2024-08-08T18:31:49.004Z","device":"device1","max_temperature":99.7,"ts":"2024-08-08T18:31:44Z"}
```

