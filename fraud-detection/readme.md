
## Quick Start

1. in `docker` dir, run `make start`
2. after stack started, in `docker` dir, run `make init` to create all resources (views, mv, udfs)
3. go to 'localhost:8000' and complete the onboarding


## Key Resources

1. MV `mv_fraud_all_features` contains the features used for train the fraud detection model and for real-time inference
2. MV `mv_detected_fraud` contains all the detected fraud and the groud truth
3. View `v_realtime_model_performance_1m` contains real-time model evalution for every 1 minute tumble window.