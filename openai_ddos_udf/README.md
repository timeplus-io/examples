# openai ddos udf
 
First create a .env file with your OpenAI API key:
```
OPENAI_API_KEY=key here
```

To run:
```docker build -t ddos_detection .```
then
```docker compose up```

Make sure to register the UDF in Timeplus console:

![register udf](https://github.com/user-attachments/assets/f68b7784-7a0a-4698-9741-55e5227e45a3)

Create a random stream simulating live network data:
```
CREATE RANDOM STREAM network(
    bwd_packet_length_min float default rand()%7,
    bwd_packet_length_std float default rand()%2437,
    avg_packet_size float default rand()%1284 + 8,
    flow_duration float default rand()%1452333 + 71180,
    flow_iat_std float default rand()%564168 + 19104
) SETTINGS eps=0.1
```
Then test the DDoS detection UDF:
```
SELECT *,
is_ddos(
    bwd_packet_length_min,
    bwd_packet_length_std,
    avg_packet_size,
    flow_duration,
    flow_iat_std
    )
FROM
network
```

Now we are detecting DDoS network activity in real-time!
