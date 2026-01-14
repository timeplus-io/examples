
docker exec -it -u splunk splunk-heavy-forwarder bash

docker exec -it -u splunk splunk-enterprise bash

# list forward servers
/opt/splunk/bin/splunk list forward-server -auth admin:Password!

cat /opt/splunk/var/log/splunk/splunkd.log | grep -i tcpout | tail -20
cat /opt/splunk/var/log/splunk/splunkd.log | grep "Connected to idx" | tail -10
cat /opt/splunk/var/log/splunk/metrics.log | grep "group=tcpout_connections" | tail -20

tail -f /opt/splunk/var/log/splunk/splunkd.log | grep -i "tcpout\|forward\|connect"

index=_internal source=*metrics.log group=tcpout_connections 
| stats sum(kb) as kb_sent by host

index=_internal source=*metrics.log component=Metrics group=tcpout_connections 
| timechart sum(kb) as kb_sent

index=_internal source=*metrics.log component=Metrics group=queue name=parsingQueue 
| timechart sum(current_size_kb) as queue_size


curl -k http://splunk:8088/services/collector/event \
  -H "Authorization: Splunk f3d27ad5-e643-4b84-82f8-57c5db6226d8" \
  -d '{"event": "Hello from curl", "sourcetype": "manual"}'


curl -k http://localhost:8088/services/collector/event \
  -H "Authorization: Splunk f3d27ad5-e643-4b84-82f8-57c5db6226d8" \
  -d '{"event": "Hello from curl", "sourcetype": "manual"}'

curl -k http://splunk:8088/services/collector/event \
  -H "Authorization: Splunk f3d27ad5-e643-4b84-82f8-57c5db6226d8" \
  -d '{
    "event": "Hello from curl with index", 
    "sourcetype": "manual",
    "index": "main"
  }'