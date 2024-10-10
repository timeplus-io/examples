package com.timeplus.examples;

import static org.apache.commons.math3.primes.Primes.isPrime;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.fail;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.clients.consumer.Consumer;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.IntegerDeserializer;
import org.apache.kafka.common.serialization.IntegerSerializer;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.apache.kafka.common.serialization.StringSerializer;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.Network;
import org.testcontainers.kafka.KafkaContainer;
import org.testcontainers.timeplus.TimeplusContainer;

public class KafkaPrimalityRouterTest {

    protected static final String INPUT_TOPIC = "input-topic";
    protected static final String PRIME_TOPIC = "primes";
    protected static final String COMPOSITE_TOPIC = "composites";
    protected static final String DLQ_TOPIC = "dlq";

    @Test
    public void testPrimalityRouter() {
        try (
            Network network = Network.newNetwork();
            KafkaContainer kafka = new KafkaContainer(
                "apache/kafka-native:3.8.0"
            )
                .withListener("kafka:19092")
                .withNetwork(network);
        ) {
            // Step 1: start Apache Kafka (we will start Timeplus container when data is ready)
            kafka.start();

            // Step 2: create topics
            try (
                var admin = AdminClient.create(
                    Map.of(
                        AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG,
                        kafka.getBootstrapServers()
                    )
                )
            ) {
                admin.createTopics(
                    List.of(
                        new NewTopic(INPUT_TOPIC, 1, (short) 1),
                        new NewTopic(PRIME_TOPIC, 1, (short) 1),
                        new NewTopic(COMPOSITE_TOPIC, 1, (short) 1),
                        new NewTopic(DLQ_TOPIC, 1, (short) 1)
                    )
                );
            }

            // Step 3.1: produce 100 ints that should go to prime / composite topics
            try (
                final Producer<Integer, Integer> producer = buildProducer(
                    kafka.getBootstrapServers(),
                    StringSerializer.class
                )
            ) {
                for (int i = 1; i <= 100; i++) {
                    ProducerRecord record = new ProducerRecord<>(
                        INPUT_TOPIC,
                        "" + i,
                        "" + i
                    );
                    producer.send(record, (event, ex) -> fail(ex));
                }
            }

            // Step 3.2: produce strings to test DLQ routing
            try (
                final Producer<String, String> producer = buildProducer(
                    kafka.getBootstrapServers(),
                    StringSerializer.class
                )
            ) {
                ProducerRecord record = new ProducerRecord<>(
                    INPUT_TOPIC,
                    "hello",
                    "world"
                );
                producer.send(record, (event, ex) -> fail(ex));
            }

            // Step 4: start Timeplus container and run init.sql to create ETL pipelines
            TimeplusContainer timeplus = new TimeplusContainer(
                "timeplus/timeplusd:2.3.31"
            )
                .withNetwork(network)
                .withInitScript("init.sql"); // inside src/test/resources
            timeplus.start();

            // Step 5: validate prime / composite routing
            try (
                final Consumer<String, String> consumer = buildConsumer(
                    kafka.getBootstrapServers(),
                    "test-group-id",
                    StringDeserializer.class
                )
            ) {
                consumer.subscribe(List.of(PRIME_TOPIC, COMPOSITE_TOPIC));

                int numConsumed = 0;
                for (int i = 0; i < 10 && numConsumed < 100; i++) {
                    final ConsumerRecords<String, String> consumerRecords =
                        consumer.poll(Duration.ofSeconds(5));
                    numConsumed += consumerRecords.count();

                    for (ConsumerRecord<
                        String,
                        String
                    > record : consumerRecords) {
                        int key = Integer.parseInt(record.key());
                        String expectedTopic = isPrime(key)
                            ? PRIME_TOPIC
                            : COMPOSITE_TOPIC;
                        assertEquals(expectedTopic, record.topic());
                    }
                }
                assertEquals(100, numConsumed);

                // make sure no more events show up in prime / composite topics
                assertEquals(0, consumer.poll(Duration.ofMillis(200)).count());
            }

            // valdate DLQ routing
            try (
                final Consumer<String, String> dlqConsumer = buildConsumer(
                    kafka.getBootstrapServers(),
                    "test-group-id",
                    StringDeserializer.class
                )
            ) {
                dlqConsumer.subscribe(List.of(DLQ_TOPIC));

                int numConsumed = 0;
                for (int i = 0; i < 10 && numConsumed < 1; i++) {
                    final ConsumerRecords<String, String> consumerRecords =
                        dlqConsumer.poll(Duration.ofSeconds(5));
                    numConsumed += consumerRecords.count();

                    for (ConsumerRecord<
                        String,
                        String
                    > record : consumerRecords) {
                        assertEquals("world", record.value());
                    }
                }
                assertEquals(1, numConsumed);

                // make sure no more events show up in DLQ topic
                assertEquals(
                    0,
                    dlqConsumer.poll(Duration.ofMillis(200)).count()
                );
            }

            timeplus.stop();
            kafka.stop();
        }
    }

    /**
     * Helper to build a producer.
     *
     * @param bootstrapServers bootstrap servers endpoint
     * @param serializerClass  serializer to use
     * @return Producer instance
     */
    protected static Producer buildProducer(
        String bootstrapServers,
        Class serializerClass
    ) {
        final Properties producerProps = new Properties() {
            {
                put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
                put(
                    ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG,
                    serializerClass
                );
                put(
                    ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG,
                    serializerClass
                );
            }
        };

        return new KafkaProducer(producerProps);
    }

    /**
     * Helper to build a consumer with auto.offset.reset set to earliest.
     *
     * @param bootstrapServers  bootstrap servers endpoint
     * @param consumerGroupId   consumer group ID
     * @param deserializerClass deseriaizer to use
     * @return Consumer instance
     */
    protected static Consumer buildConsumer(
        String bootstrapServers,
        String consumerGroupId,
        Class deserializerClass
    ) {
        final Properties consumerProps = new Properties() {
            {
                put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
                put(
                    ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG,
                    deserializerClass
                );
                put(
                    ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG,
                    deserializerClass
                );
                put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
                put(ConsumerConfig.GROUP_ID_CONFIG, consumerGroupId);
            }
        };

        return new KafkaConsumer<>(consumerProps);
    }
}
