
start:
	docker compose up -d

stop:
	docker compose down

init:
	docker compose exec -it timeplus timeplus sync --username proton --password timeplus@t+ apply ./tp-sync/

install_deps:
	curl -X POST http://localhost:8123/timeplusd/v1/python_packages \
		-u proton:timeplus@t+ \
		-d '{"packages": [{"name": "pandas"},{"name": "numpy"},{"name": "scikit-learn"},{"name": "torch"},{"name": "transformers"},{"name": "openai"},{"name": "statsmodels"}]}'

list_deps:
	curl http://localhost:8123/timeplusd/v1/python_packages \
		-u proton:timeplus@t+ 

uninstall_deps:
	curl -X DELETE http://localhost:8123/timeplusd/v1/python_packages/prophet \
		-u proton:timeplus@t+
	curl -X DELETE http://localhost:8123/timeplusd/v1/python_packages/darts \
		-u proton:timeplus@t+
	curl -X DELETE http://localhost:8123/timeplusd/v1/python_packages/jsondiff \
		-u proton:timeplus@t+