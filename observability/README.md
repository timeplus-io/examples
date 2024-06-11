
## Timeplus Enterprise Obserbaility

This is an example to show how to mointor Timeplus enterprise using metrics


## Quickstart

To run this examples, you need have `docker` , and `make` installed in your system.

To start the stack run `make start_init` which will start Timeplus enterprise, Prometheus and Grafana using docker compose, and it will initialize observability release resources in Timeplus.  Run `make stop` to stop the whole stack and run `make start` if you already initialized the resoruces before.   Run `make clean` to delete all data volumes and unused docker resources.

After start, the timeplus is running at `http://localhost:8000`.  Grafana is running on `http://localhost:3000` with username `admin`, password `grafana`.  

## Metrics and Logs collection configurations

Timeplus enterprise metrics is expose as Prometheus endpoint at `http://timeplus_host:9363/metrics`, a prometheus scraper is configured in `./prometheus/prometheus.yml`. 

A promtheus datasource is configured at `./grafana/datasource.yml`, so user should be able to explore all the Timeplus metrics in Grafana after login to grafana

Timeplus logs are located at /timeplus/logs, in this sample it is mounted to data volume `timeplus_logs`, user can use any log analysis tools to analysis these logs

## Self Mointoring

There is a dashboaed `Timeplus Mointoring` created at startup of this stack, which contains sample metrics to be monitored.

To mointor logs, try run 'select * from timeplusd_log' from console UI or CLI.

## Grafana Dashboard

Two sample dashboards are provided in json model.  user can create new dashboard by importing these two jsons `./dashboard/grafana_timeplus_qeuries_dashboard.json` and `./dashboard/grafana_timeplus_external_streams_dashboard.json`

Note due to the datasource id is dynamically generated, user can find the datasource uuid using grafana API and replace all premetheus UUID in the dashboard and then import it.

1. generate a service account token in grafana UI
2. run `curl -H "Authorization: Bearer GRAFANA_SA_TOKEN" http://localhost:3000/api/datasources`
which will return something like `[{"id":1,"uid":"PBFA97CFB590B2093", ... ...`
3. replace all datasource uuid with the prometheus datasource uuid returned from the API call.
