# Video Inference Streaming Server with Roboflow and Timeplus

This project creates a video analytic application that:
1. Uses Roboflow's inference pipeline to process video frames with machine learning models
2. Streams the detection visualizations to a web interface in real-time
3. Forwards structured detection data to Timeplus for real-time analytics and monitoring

The system forms an end-to-end pipeline from video input through ML inference to real-time analytics dashboards.

## Features

- **Roboflow Integration**: Leverages Roboflow's powerful inference pipeline for object detection
- **Real-time Video Streaming**: Low-latency delivery of processed video frames to web browsers
- **Live Detection Results**: Displays structured detection data alongside video
- **Timeplus Analytics**: Forwards all detection data to Timeplus for real-time analytics


## Requirements

- Python 3.7+
- FastAPI & Uvicorn
- OpenCV (cv2)
- Roboflow inference package
- Proton driver for Timeplus stream data ingest

## Development

1. Install the required dependencies:

```bash
pip install fastapi uvicorn opencv-python python-multipart
pip install inference supervision proton-driver
```

2. Set the required environment variables:

```bash
export ROBOFLOW_API_KEY="your_api_key"
export ROBOFLOW_USERNAME="your_username"
export ROBOFLOW_WORKFLOW="your_workflow_id" 
export INPUT_VIDEO="path_to_your_video"

# Timeplus configuration
export TIMEPLUS_HOST="localhost"
export TIMEPLUS_USER="proton" 
export TIMEPLUS_PASSWORD="timeplus@t+"
export STREAM_NAME="video_stream_log"

# Server configuration
export SERVER_HOST="0.0.0.0"
export SERVER_PORT="5001"
```

## Project Structure

```
├── server.py             # The main FastAPI server file
├── static/               # Static assets directory
│   ├── css/              # CSS stylesheets
│   │   └── style.css     # Main stylesheet
│   └── index.html        # Main HTML page
```

## Usage

Set requirement environment and input stream using environment variables. Run with docker compose `make start` and then create the dashboard use `create_dashboard`, login to timeplust from `localhost:8000` to view the dashboard.

Or you can run the server seperatedly.

Run timeplus with docker
```bash
docker run -d \
    --name timeplus \
    --platform linux/amd64 \
    -p 8000:8000 \
    -p 8463:8463 \
    -p 8123:8123 \
    -v timeplus_data:/timeplus/data/ \
    timeplus/timeplus-enterprise:2.9.0-aitest2
```

Run the inference server:

```bash
python server.py
```

Then open your web browser and run the onboarding process to create timeplus user:
```
http://localhost:8000
```

In the Timeplus Query UI, run following SQL to inspect the video detection output 'SELECT * FROM video_stream_log'

To stop the inference server, press `Ctrl+C` in the terminal. The server will handle this gracefully, shutting down the inference pipeline process and releasing all resources.

## How It Works

1. **Video Processing Pipeline**: 
   - The server initializes Roboflow's inference pipeline with your specified model/workflow
   - Video frames are captured from the specified source file

2. **ML Inference**:
   - Each frame is processed through Roboflow's machine learning models
   - Object detection, classification, or other ML tasks are performed based on your workflow

3. **Dual Streaming**:
   - **Visual Stream**: Processed frames with visualizations are streamed to web browsers
   - **Data Stream**: Structured detection data is:
      - Displayed in the browser as JSON
      - Sent to Timeplus for real-time analytics

4. **Real-time Analytics**:
   - All inference results are formatted and sent to Timeplus
   - Timeplus can be used to:
      - Create real-time dashboards of detection patterns
      - Set up alerts based on specific object detections
      - Analyze trends over time
      - Correlate detections with other data sources

## Customization

- **Web Interface:** Modify the `static/index.html` and `static/css/style.css` files to change the appearance
- **Performance:** Adjust the FPS in the `generate_frames` method by changing the sleep duration (default is 0.03 for ~30 FPS)
- **Visualizations:** Enhance the frame processing logic in the `sink` method to add more visualizations or overlay data
- **Detection Format:** Modify the `detection_to_json` method to change how detections are formatted
- **Video Source:** Change the `video_path` environment variable to use a different video source

## API Endpoints

- `/` - Main web interface showing video and inference results
- `/video_feed` - Raw video stream endpoint
- `/inference_results` - JSON API endpoint for latest detection results

## Timeplus Integration

The server automatically creates a stream in Timeplus and forwards all inference results in real-time. This enables powerful analytics capabilities:

### Real-time Analytics with Timeplus
- **Live Dashboards**: Create visualizations of detection counts, confidence levels, and object types
- **Stream Processing**: Apply SQL queries to filter, aggregate, and analyze detection data on the fly
- **Alerting**: Set up real-time alerts when specific objects are detected or patterns emerge
- **Data Correlation**: Join video detection data with other data sources in your Timeplus instance
- **Historical Analysis**: Analyze detection patterns over time with Timeplus' time-series capabilities

### Data Flow
1. Inference results from Roboflow are processed and serialized to JSON
2. The server formats and forwards this data to a dedicated Timeplus stream
3. Within Timeplus, you can create queries, dashboards, and alerts based on this data

This integration creates a complete end-to-end pipeline from video input through ML inference to actionable analytics.

## Troubleshooting

- If no video appears, check that your environment variables are set correctly
- Verify that the video path is accessible to the application
- Check the logs for any error messages
- If inference results aren't showing, check the browser console for errors