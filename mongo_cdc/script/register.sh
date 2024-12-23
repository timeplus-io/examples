
curl -X POST http://localhost:8083/connectors \
-H "Content-Type: application/json" \
-d '{
  "name": "mongodb-connector",
  "config": {
    "connector.class": "io.debezium.connector.mongodb.MongoDbConnector",
    "tasks.max": "1",
    "mongodb.connection.string": "mongodb://mongo:27017/?replicaSet=rs0",
    "mongodb.name": "dbserver1",
    "database.include.list": "testdb",
    "collection.include.list": "testdb.testcollection",
    "topic.prefix": "dbserver1",
    "database.history.kafka.bootstrap.servers": "kafka:9092",
    "database.history.kafka.topic": "schema-changes.testdb"
  }
}'