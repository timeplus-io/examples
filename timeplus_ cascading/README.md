this examples how to leverage timeplus external stream to directly query and aggregate the streams on edge timeplus in a central timeplus.

Here is the quick start guide:
1. run `make start` to start the stack, there are three timeplus instances, `timeplus_edge_1` ,  `timeplus_edge_2` and `timeplus_central`
2. run `make init` which will create simulated network stream on `timeplus_edge_1` and `timeplus_edge_2`, it will also create external streams on the central timeplus and use a mv `mv_network` to aggregate those two remote streams, persist to a local stream `network`

login to these timeplus using `localhost:8000` which is central timeplus ,  `localhost:8001` and `localhost:8002` are `timeplus_edge_1` and  `timeplus_edge_2`



