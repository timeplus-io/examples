
start:
	docker compose up -d

stop:
	docker compose down

init:
	docker compose exec -it timeplus_edge_1 timeplus sync --username proton --password timeplus@t+ apply /timeplus/tp-sync/
	docker compose exec -it timeplus_edge_2 timeplus sync --username proton --password timeplus@t+ apply /timeplus/tp-sync/
	docker compose exec -it timeplus_central timeplus sync --username proton --password timeplus@t+ apply /timeplus/tp-sync/