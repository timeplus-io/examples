
install_dep_rest:
	curl -X POST http://localhost:8123/timeplusd/v1/python_packages \
		-u proton:timeplus@t+ \
		-d '{"packages": [{"name": "proton-driver"}]}'

install_dep_cli:
	docker compose exec -it timeplus timeplusd python --config-file /timeplus/conf/timeplusd.yaml -m pip install --user proton-driver