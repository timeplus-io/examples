
start:
	docker compose up -d

register:
	curl -X POST http://localhost:8083/connectors \
		-H "Content-Type: application/json" \
		-d '{ \
			"name": "mongodb-connector", \
			"config": { \
				"connector.class": "io.debezium.connector.mongodb.MongoDbConnector", \
				"tasks.max": "1", \
				"mongodb.connection.string": "mongodb://mongo:27017/?replicaSet=rs0", \
				"collection.include.list": "testdb.testcollection*" , \
				"capture.mode": "change_streams_update_full_with_pre_image" , \
				"topic.prefix": "fullfillment" \
			} \
		}'

delete:
	curl -X DELETE http://localhost:8083/connectors/mongodb-connector

mongo_client:
	docker run -it --rm rtsp/mongosh mongosh mongodb://host.docker.internal:27017