import os
import sys
import cv2
import logging
import threading
import time
import signal
import numpy as np
import json
from typing import List, Any, Dict
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, StreamingResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

from contextlib import asynccontextmanager
from inference import InferencePipeline
from supervision.detection.core import Detections
from proton_driver import client
import uvicorn

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Environment variables
api_key = os.getenv("ROBOFLOW_API_KEY")
username = os.getenv("ROBOFLOW_USERNAME")
workflow_id = os.getenv("ROBOFLOW_WORKFLOW")
video_path = os.getenv("INPUT_VIDEO")

# Flag to track server state
server_running = True

class VideoProcessor:
    def __init__(self):
        self.timeplus_host = os.getenv("TIMEPLUS_HOST", "localhost")
        self.timeplus_user = os.getenv("TIMEPLUS_USER", "proton")
        self.timeplus_password = os.getenv("TIMEPLUS_PASSWORD", "timeplus@t+")
        self.stream_name = os.getenv("STREAM_NAME", "video_stream_log")
        self.server_host = os.getenv("SERVER_HOST", "0.0.0.0")
        self.server_port = int(os.getenv("SERVER_PORT", "5001"))
        
        # Initialize client for Timeplus (keep for data logging)
        self.client = client.Client(
            host=self.timeplus_host,
            user=self.timeplus_user,
            password=self.timeplus_password,
            port=8463,
        )
        
        # Frame storage for streaming
        self.frame = None
        self.frame_lock = threading.Lock()
        
        # Store the latest inference results
        self.inference_results = {}
        self.results_lock = threading.Lock()
        
        self.running = False
        self.pipeline = None
        
        self.init_timeplus()
        
    def init_timeplus(self):
        while True:
            try:
                self.client.execute(
                    f"""SELECT 1"""
                )
                break
            except Exception as e:
                logger.error(f"Failed to connect to Timeplus: {e}")
                time.sleep(3)
                
        self.create_log_stream     
        
    def create_log_stream(self):
        """Create Timeplus stream if it doesn't exist"""
        try:
            self.client.execute(
                f"""CREATE STREAM IF NOT EXISTS {self.stream_name} (
                raw string
            )"""
            )
            logger.info(f"Created or verified stream: {self.stream_name}")
        except Exception as e:
            logger.error(f"Failed to create stream: {e}")
    
    def insert_data(self, data: List[List[str]]):
        """Insert data into Timeplus stream"""
        try:
            if not data:
                return
                
            self.client.execute(
                f"INSERT INTO {self.stream_name} (raw) VALUES",
                data
            )
        except Exception as e:
            logger.error(f"Error inserting data: {e}")
            
    def detection_to_json(self, value: Detections) -> List[Dict[str, Any]]:
        detections_array = []
        if value.__class__.__name__ == 'Detections':
            # Convert to a cleaner array of detections
            detections_array = []
            
            # Get number of detections
            num_detections = 0
            if hasattr(value, 'xyxy') and value.xyxy is not None:
                num_detections = len(value.xyxy)
            
            # Iterate through each detection
            for i in range(num_detections):
                detection = {}
                
                # Get bounding box
                if hasattr(value, 'xyxy') and value.xyxy is not None and i < len(value.xyxy):
                    # Convert numpy array values to Python floats
                    x1, y1, x2, y2 = [float(x) for x in value.xyxy[i]]
                    detection["bbox"] = {
                        "x1": x1,
                        "y1": y1,
                        "x2": x2, 
                        "y2": y2,
                        "width": x2 - x1,
                        "height": y2 - y1
                    }
                
                # Get confidence
                if hasattr(value, 'confidence') and value.confidence is not None and i < len(value.confidence):
                    detection["confidence"] = float(value.confidence[i])
                
                # Get class id
                if hasattr(value, 'class_id') and value.class_id is not None and i < len(value.class_id):
                    detection["class_id"] = int(value.class_id[i])
                
                # Get tracker id
                if hasattr(value, 'tracker_id') and value.tracker_id is not None and i < len(value.tracker_id):
                    detection["tracker_id"] = int(value.tracker_id[i])
                
                # Add any additional data
                if hasattr(value, 'data') and value.data:
                    for data_key, data_array in value.data.items():
                        if i < len(data_array):
                            try:
                                data_val = data_array[i]
                                # Handle numpy types
                                if isinstance(data_val, (np.integer, np.floating, np.bool_)):
                                    detection[data_key] = data_val.item()
                                else:
                                    detection[data_key] = str(data_val)
                            except:
                                detection[data_key] = str(data_array[i])
                
                detections_array.append(detection)
                
        return detections_array
        

    def sink(self, result, video_frame):
        """Process each frame from the inference pipeline"""
        if not self.running:
            return
            
        if result.get("visualization"):
            # Save the visualization for streaming
            with self.frame_lock:
                self.frame = result["visualization"].numpy_image.copy()
        
        # Store the inference results for the web UI
        with self.results_lock:
            try:
                # Store only relevant data (remove large binary data)
                filtered_result = {}
                for key, value in result.items():
                    # Skip visualization (it's binary data)
                    if key == "visualization":
                        continue
                    
                    # Special handling for Detections class
                    # TODO: check if there is json serializable method for Detections
                    # Special handling for Detections class
                    if value.__class__.__name__ == 'Detections':
                        # Convert to a cleaner array of detections
                        detections_array = self.detection_to_json(value)
                        filtered_result[key] = detections_array
                        continue
                
                    # Convert non-serializable data to strings
                    try:
                        # Test if it's JSON serializable
                        json.dumps({key: value})
                        filtered_result[key] = value
                    except (TypeError, OverflowError):
                        # If not serializable, convert to string representation
                        filtered_result[key] = str(value)
                        logger.info(f"key {key} is not JSON serializable, converted to string type: {type(value)}")
                        
                
                self.inference_results = filtered_result
                logger.debug(json.dumps(self.inference_results, indent=2)) 
                payload = []
                payload.append([json.dumps(self.inference_results, indent=2)])
                self.insert_data(payload)  # Insert into Timeplus stream
            except Exception as e:
                logger.error(f"Error processing inference results: {e}")
                self.inference_results = {"error": "Failed to process results"}
            
        
    def run_inference(self):
        """Run the inference pipeline"""
        try:
            self.running = True
            logger.info("Setting up inference pipeline")
            
            # Initialize a pipeline object
            self.pipeline = InferencePipeline.init_with_workflow(
                api_key=api_key,
                workspace_name=username,
                workflow_id=workflow_id,
                video_reference=video_path,
                max_fps=30,
                on_prediction=self.sink
            )
            
            logger.info("Starting inference pipeline")
            self.pipeline.start()  # start the pipeline
            
            # Check periodically if we should stop
            while self.running and server_running:
                time.sleep(0.5)
                
            # If we exited the loop, need to stop the pipeline
            logger.info("Stopping inference pipeline")
            
            # The pipeline doesn't have a stop method, so we'll just
            # exit the thread and let the main process clean up
                
        except Exception as e:
            logger.error(f"Error in inference thread: {e}")
        finally:
            logger.info("Inference thread exiting")
            self.running = False
    
    def get_frame(self):
        """Get the current frame for streaming"""
        with self.frame_lock:
            if self.frame is not None:
                # Encode the frame as JPEG
                ret, buffer = cv2.imencode('.jpg', self.frame)
                if ret:
                    return buffer.tobytes()
                    
        # Return a blank frame if no frame is available
        blank_image = 255 * np.ones((480, 640, 3), dtype=np.uint8)
        cv2.putText(blank_image, "No video frame available", (100, 240), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 0), 2)
        ret, buffer = cv2.imencode('.jpg', blank_image)
        return buffer.tobytes()

    def generate_frames(self):
        """Generator function for streaming frames"""
        while self.running and server_running:
            frame = self.get_frame()
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')
            time.sleep(0.03)  # ~30 FPS
        
        # Send a final blank frame
        blank_image = 255 * np.ones((480, 640, 3), dtype=np.uint8)
        cv2.putText(blank_image, "Stream ended", (200, 240), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 0), 2)
        ret, buffer = cv2.imencode('.jpg', blank_image)
        final_frame = buffer.tobytes()
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + final_frame + b'\r\n')

    def get_inference_results(self) -> Dict:
        """Get the latest inference results in a thread-safe way"""
        with self.results_lock:
            # Return a copy to avoid threading issues
            return dict(self.inference_results)

# Signal handler for graceful termination
def signal_handler(sig, frame):
    global server_running
    logger.info(f"Received signal {sig}, shutting down...")
    server_running = False
    # Give a short time for threads to notice the change
    time.sleep(0.5)
    # Force exit 
    sys.exit(0)

# Register signal handlers
signal.signal(signal.SIGINT, signal_handler)   # Ctrl+C
signal.signal(signal.SIGTERM, signal_handler)  # termination signal

# Create a global VideoProcessor instance
video_processor = VideoProcessor()

# Define lifespan context
@asynccontextmanager
async def lifespan(app):
    # Startup: Start the inference pipeline in a thread
    logger.info("Starting inference thread")
    inference_thread = threading.Thread(target=video_processor.run_inference)
    inference_thread.daemon = True  # Daemon threads exit when main thread exits
    inference_thread.start()
    yield
    # Shutdown: Stop the inference pipeline
    logger.info("Server shutting down, stopping inference pipeline")
    video_processor.running = False
    # Wait briefly for thread to clean up
    if inference_thread.is_alive():
        logger.info("Waiting for inference thread to exit")
        inference_thread.join(timeout=2.0)
    logger.info("Server shutdown complete")

# Create FastAPI app with lifespan
app = FastAPI(title="Video Inference Streaming", lifespan=lifespan)

# Define allowed origins
origins = [
    "http://localhost:8000",  # Example: Local development front-end
    "*"  # Allow all (only for testing; avoid in production)
]

# Add CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,  # Allow specified origins
    allow_credentials=True,
    allow_methods=["*"],  # Allow all HTTP methods
    allow_headers=["*"],  # Allow all headers
)

# Mount static files directory - assumes you'll create a 'static' folder manually
if os.path.exists("static"):
    app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/", response_class=HTMLResponse)
async def index():
    """Serve the main page"""
    try:
        # Assuming index.html exists in the static folder
        with open("static/index.html", "r") as file:
            return HTMLResponse(content=file.read())
    except FileNotFoundError:
        # If the file doesn't exist, return a helpful error message
        return HTMLResponse(status_code=404, content="""
        <html>
            <head>
                <title>Missing Static Files</title>
                <style>
                    body { font-family: Arial; padding: 40px; line-height: 1.6; }
                    code { background: #f4f4f4; padding: 2px 5px; border-radius: 3px; }
                    pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
                </style>
            </head>
            <body>
                <h1>Missing Static Files</h1>
                <p>The static files required for this application are missing. Please create the following directory structure:</p>
                <pre>
static/
  ├── css/
  │   └── style.css
  └── index.html
                </pre>
                <p>Once you've created these files, restart the server and visit this page again.</p>
            </body>
        </html>
        """)

@app.get("/video_feed")
async def video_feed():
    """Stream video frames"""
    return StreamingResponse(
        video_processor.generate_frames(),
        media_type="multipart/x-mixed-replace; boundary=frame"
    )

@app.get("/inference_results")
async def get_inference_results():
    """Endpoint to get the latest inference results"""
    return JSONResponse(content=video_processor.get_inference_results())

def main():
    """Run the FastAPI server with proper signal handling"""
    try:
        logger.info(f"Starting server on {video_processor.server_host}:{video_processor.server_port}")
        logger.info("Press Ctrl+C to stop the server")
        uvicorn.run(
            app, 
            host=video_processor.server_host, 
            port=video_processor.server_port
        )
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt detected in main")
        # Signal handler will take care of cleanup
    finally:
        # Just to be extra safe, make sure everything is shut down
        global server_running
        server_running = False
        video_processor.running = False

if __name__ == "__main__":
    main()