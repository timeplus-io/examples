
## Timeplus Enterprise Obserbaility

This is an example to show how to mointor Timeplus enterprise using metrics


## Quickstart

To run this examples, you need have `docker` , and `make` installed in your system.

To start the stack run `make start` which will start Timeplus enterprise, Prometheus and Grafana using docker compose.  Run `make stop` to stop the whole stack and run `make start` if you already initialized the resoruces before.   Run `make clean` to delete all data volumes and unused docker resources.

After start, the timeplus is running at `http://localhost:8000` and go through the onboarding process by creating new user.  Grafana is running on `http://localhost:3000` with username `admin`, password `grafana`.

## Metrics and Logs collection configurations

Timeplus enterprise metrics is expose as Prometheus endpoint at `http://timeplus_host:9363/metrics`, a prometheus scraper is configured in `./prometheus/prometheus.yml`.

A promtheus datasource is configured at `./grafana/datasource.yml`, so user should be able to explore all the Timeplus metrics in Grafana after login to grafana

Timeplus logs are located at /timeplus/logs, in this sample it is mounted to data volume `timeplus_logs`, user can use any log analysis tools to analysis these logs


## Grafana Dashboard

Two sample dashboards are provided in json model.  user can create new dashboard by importing these two jsons `./dashboard/timeplusd.json` and `./dashboard/external_stream.json`. just import these two json into the dashboard.
