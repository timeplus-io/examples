VERSION = $(shell git rev-parse --short HEAD)

BIN_NAME = fraud
IMAGE_NAME = $(BIN_NAME):$(VERSION)
DOCKER_ID_USER = timeplus
FULLNAME=$(DOCKER_ID_USER)/${IMAGE_NAME}

PWD = $(shell pwd)

.PHONY: docker

init:
	pip install -r requirements.txt

docker: Dockerfile
	docker build  --platform linux/amd64 -f Dockerfile.1 -t $(IMAGE_NAME) .

run:
	docker run -p 8000:8000 -e TIMEPLUS_APIKEY=$(TIMEPLUS_APIKEY) -e TIMEPLUS_SERVER_URL=$(TIMEPLUS_SERVER_URL) -e TIMEPLUS_WORKSPACE=$(TIMEPLUS_WORKSPACE) $(IMAGE_NAME)

gen:
	docker run --entrypoint python3 -e TIMEPLUS_APIKEY=$(TIMEPLUS_APIKEY) -e TIMEPLUS_SERVER_URL=$(TIMEPLUS_SERVER_URL) -e TIMEPLUS_WORKSPACE=$(TIMEPLUS_WORKSPACE) $(IMAGE_NAME) transaction.py --target timeplus

run_train:
	docker run --entrypoint python3 -e TIMEPLUS_APIKEY=$(TIMEPLUS_APIKEY) -e TIMEPLUS_SERVER_URL=$(TIMEPLUS_SERVER_URL) -e TIMEPLUS_WORKSPACE=$(TIMEPLUS_WORKSPACE) -v $(PWD)/model:/model  $(IMAGE_NAME) train.py

run_infer:
	docker run --entrypoint python3 -e TIMEPLUS_APIKEY=$(TIMEPLUS_APIKEY) -e TIMEPLUS_SERVER_URL=$(TIMEPLUS_SERVER_URL) -e TIMEPLUS_WORKSPACE=$(TIMEPLUS_WORKSPACE)  -v $(PWD)/model:/model $(IMAGE_NAME) infer.py

run_predict:
	curl -X POST http://localhost:8000/predict -H 'Content-Type: application/json' -d '{"type":["PAYMENT","CASH_IN"],"amount":[100.0,200.0],"previous_amount":[100.0,200.0],"time_to_last_transaction":[100,200],"transaction_count_1m":[1,0],"max_transaction_amount_1m":[100.0,200.0],"avg_transaction_amount_1m":[100.0,200.0],"distinct_transaction_target_count_5m":[1,5],"avg_transaction_count_1d":[10,5],"avg_max_transaction_count_1d":[10,50]}'


push:
	docker tag $(IMAGE_NAME) $(FULLNAME)
	docker push $(FULLNAME)
	docker tag $(IMAGE_NAME) $(DOCKER_ID_USER)/$(BIN_NAME):latest
	docker push $(DOCKER_ID_USER)/$(BIN_NAME):latest