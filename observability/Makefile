
start_init:
	docker compose --profile init up -d

start:
	docker compose up -d

stop:
	docker compose down

clean:
	docker system prune  -f
	docker volume prune  -f
	docker volume rm observability_timeplus_data observability_timeplus_logs observability_prom_data observability_grafana_data