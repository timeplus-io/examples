
docker:
	docker build -t ddos_detection .

start:
	docker compose up -d

stop:
	docker compose down

test:
	curl -X POST http://localhost:5001/is_ddos -H 'Content-Type: application/json' -d '{"bwd_packet_length_min":[0,0], "bwd_packet_length_std":[100,100], "avg_packet_size":[1.2,2.3],"flow_duration":[0.7,0.5],"flow_iat_std":[0.7,0.5]}'