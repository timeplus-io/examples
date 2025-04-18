import os
import sys
import cv2
import torch
import json
import logging
from PIL import Image
import streamlink
import threading
import time
from queue import Queue
from typing import List, Any, Optional
from yt_dlp import YoutubeDL


import fastapi
from fastapi import FastAPI, Response
from fastapi.responses import HTMLResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

from ultralytics import YOLO
from transformers import ViTForImageClassification, ViTImageProcessor

from proton_driver import client

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global frame buffer that will be accessed by the FastAPI app
global_frame = None
global_frame_lock = threading.Lock()

class VideoProcessor:
    def __init__(self):
        # Set random seeds for reproducibility
        torch.manual_seed(42)
        if torch.cuda.is_available():
            torch.cuda.manual_seed_all(42)
            torch.backends.cudnn.deterministic = True
            torch.backends.cudnn.benchmark = False
            self.device = torch.device("cuda")
        else:
            self.device = torch.device("cpu")
        
        # Timeplus configuration
        self.timeplus_host = os.getenv("TIMEPLUS_HOST", "localhost")
        self.timeplus_user = os.getenv("TIMEPLUS_USER", "proton")
        self.timeplus_password = os.getenv("TIMEPLUS_PASSWORD", "timeplus@t+")
        self.stream_name = os.getenv("STREAM_NAME", "video_stream_log")
        self.batch_size = int(os.getenv("BATCH_SIZE", "0"))
        
        logger.info(f"Timeplus configuration: host={self.timeplus_host}, user={self.timeplus_user}, stream_name={self.stream_name}")
        # Check if batch size is set
        
        # Server configuration
        self.server_host = os.getenv("SERVER_HOST", "0.0.0.0")
        self.server_port = int(os.getenv("SERVER_PORT", "5001"))
        self.streaming_enabled = os.getenv("ENABLE_STREAMING", "True").lower() == "true"
        
        # Initialize client for Timeplus (keep for data logging)
        self.client = client.Client(
            host=self.timeplus_host,
            user=self.timeplus_user,
            password=self.timeplus_password,
            port=8463,
        )
        
        # Initialize models
        self.init_models()
        
        # Data processing queue
        self.data_queue = Queue(maxsize=100)
        
        # Runtime variables
        self.is_running = False
        self.display_output = os.getenv("DISPLAY_OUTPUT", "False").lower() == "true"
        
        # Latest detection results for API
        self.latest_results = {
            "timestamp": 0,
            "violence": {"class": "unknown", "confidence": 0.0},
            "objects": []
        }
        self.results_lock = threading.Lock()
    
    def init_models(self):
        """Initialize object detection and violence detection models"""
        try:
            # Load YOLOv8 model
            logger.info("Loading YOLOv8 model...")
            self.yolo_model = YOLO("ultralytics/yolov8n")
            
            # Load violence detection model
            logger.info("Loading violence detection model...")
            self.vio_model = ViTForImageClassification.from_pretrained('jaranohaal/vit-base-violence-detection')
            self.vio_model.to(self.device)
            self.vio_model.eval()
            
            self.feature_extractor = ViTImageProcessor.from_pretrained('jaranohaal/vit-base-violence-detection')
            logger.info("Models loaded successfully")
        except Exception as e:
            logger.error(f"Failed to load models: {e}")
            sys.exit(1)
    
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
            sys.exit(1)
    
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
            
    def get_youtube_vod_stream_url(self, youtube_url: str) -> Optional[str]:
        """
        Get direct video URL (MP4 or M3U8) using yt-dlp for both live and non-live YouTube videos.
        """
        try:
            ydl_opts = {
                'quiet': True,
                'skip_download': True,
                #'format': 'bestvideo+bestaudio/best',  # Allow merging of separate streams
                'format': 'bestvideo[vcodec!=av01][vcodec!=vp9]+bestaudio/best[vcodec!=av01][vcodec!=vp9]/best',
                'merge_output_format': 'mp4',          # Merge into MP4 if needed
                'allow_unplayable_formats': False,
                'verbose': False,
            }

            with YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(youtube_url, download=False)
                
                # Check if the info contains a direct URL
                if info and "url" in info:
                    return info.get("url")
                
                # If no direct URL, try to get it from the selected format
                elif info and "requested_formats" in info:
                    # For HLS/m3u8 streams, prefer those
                    for fmt in info["requested_formats"]:
                        if fmt.get("protocol") == "m3u8" and fmt.get("url"):
                            return fmt.get("url")
                    
                    # Otherwise return the first available URL
                    if info["requested_formats"] and "url" in info["requested_formats"][0]:
                        return info["requested_formats"][0].get("url")
                
                logger.warning(f"URL not found in extracted info for {youtube_url}")
                return None

        except Exception as e:
            logger.error(f"Failed to extract stream URL: {e}")
            return None
    
    def get_video_stream_url(self, youtube_url: str) -> Optional[str]:
        """
        Extract best available video stream URL (live or not) from YouTube
        """
        try:
            available_streams = streamlink.streams(youtube_url)
            if not available_streams:
                logger.warning("No streams found.")
                return None

            # Prioritize HLS (live), otherwise fallback to best progressive stream
            if "hls" in available_streams:
                return available_streams["hls"].url
            elif "best" in available_streams:
                return available_streams["best"].url
            else:
                logger.warning("No suitable stream found.")
                return None

        except Exception as e:
            logger.error(f"Failed to extract video stream: {e}")
            return self.get_youtube_vod_stream_url(youtube_url)
    
    def detect_violence(self, pil_image):
        """Detect violence in an image"""
        try:
            # Preprocess the image
            inputs = self.feature_extractor(images=pil_image, return_tensors="pt")
            inputs = {k: v.to(self.device) for k, v in inputs.items()}
            
            # Perform inference
            with torch.no_grad():
                outputs = self.vio_model(**inputs)
                logits = outputs.logits
                # Get probabilities
                probs = torch.nn.functional.softmax(logits, dim=-1)
                predicted_class_idx = logits.argmax(-1).item()
                confidence = probs[0][predicted_class_idx].item()
            
            # Get the class label and confidence
            predicted_label = self.vio_model.config.id2label[predicted_class_idx]
            return {
                "class": predicted_label, 
                "confidence": float(confidence)
            }
        except Exception as e:
            logger.error(f"Violence detection error: {e}")
            return {"class": "unknown", "confidence": 0.0}
    
    def data_sender_thread(self):
        """Thread to send batched data to Timeplus"""
        data_batch = []
        last_send_time = time.time()
        
        while self.is_running or not self.data_queue.empty():
            try:
                # Get data or timeout after 1 second
                try:
                    item = self.data_queue.get(timeout=1)
                    data_batch.append([item])
                    self.data_queue.task_done()
                except Exception:
                    # Timeout is ok, we'll check if we need to send the batch
                    pass
                
                # Send data if batch is full or timeout occurred
                current_time = time.time()
                timeout_reached = current_time - last_send_time > 2  # Send at least every 2 seconds
                
                if len(data_batch) >= self.batch_size or (data_batch and timeout_reached):
                    self.insert_data(data_batch)
                    data_batch = []
                    last_send_time = current_time
                    
            except Exception as e:
                logger.error(f"Data sender thread error: {e}")
        
        # Send any remaining data
        if data_batch:
            self.insert_data(data_batch)
            
    def process_videos(self, video_path: str):
        self.create_log_stream()
        input_streams = video_path.split(",")
        for s in input_streams:
            self.process_video(s)
        
    
    def process_video(self, video_path: str):        
        input_stream = None
        
        if video_path.startswith("http"):
            # Get stream URL
            input_stream = self.get_youtube_vod_stream_url(video_path)
            if not input_stream:
                logger.error("Failed to extract video URL")
                return
            logger.info(f"Extracted URL: {input_stream}")
        else:
            input_stream = video_path
        
        # Open HLS video stream
        cap = cv2.VideoCapture(input_stream)
        if os.getenv("DISABLE_HARDWARE_ACCELERATION", "false").lower() == "true":
            cap.set(cv2.CAP_PROP_HW_ACCELERATION, 0)
        
        if not cap.isOpened():
            logger.error("Could not open input stream")
            return
        
        # Get stream properties
        frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        fps = int(cap.get(cv2.CAP_PROP_FPS) or 30)
        
        logger.info(f"Stream Properties - Width: {frame_width}, Height: {frame_height}, FPS: {fps}")
        
        # Start data sender thread
        self.is_running = True
        sender_thread = threading.Thread(target=self.data_sender_thread)
        sender_thread.daemon = True
        sender_thread.start()
        
        frame_count = 0
        skip_frames = int(os.getenv("SKIP_FRAMES", "1"))
        
        try:
            while cap.isOpened():
                ret, frame = cap.read()
                if not ret:
                    logger.info("Failed to read frame from stream. Ending stream.")
                    break
                
                # Process only every nth frame to reduce computational load
                frame_count += 1
                if frame_count % skip_frames != 0:
                    continue
                
                # Convert frame (OpenCV BGR format) to PIL Image (RGB)
                frame_copy = frame.copy()
                image = cv2.cvtColor(frame_copy, cv2.COLOR_BGR2RGB)
                pil_image = Image.fromarray(image)
                
                # Detect violence
                violence_result = self.detect_violence(pil_image)
                
                detected_objects = []
                
                # Run YOLOv8 object detection
                try:
                    results = self.yolo_model(frame)
                    
                    # Draw detections on the frame
                    for result in results:
                        for box in result.boxes:
                            x1, y1, x2, y2 = map(int, box.xyxy[0])
                            conf = box.conf[0].item()
                            cls = int(box.cls[0].item())
                            class_name = self.yolo_model.names[cls]
                            label = f"{class_name}: {conf:.2f}"
                            
                            # Add to detected objects
                            detected_objects.append({
                                "class": class_name,
                                "confidence": float(conf),
                                "bbox": [x1, y1, x2, y2]
                            })
                            
                            # Draw bounding box and label
                            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
                            cv2.putText(frame, label, (x1, y1 - 10), 
                                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
                    
                    # Process detection results                    
                    for result in results:
                        detected_object = json.loads(result.to_json())
                        stream_log_object = {
                            'timestamp': time.time(),
                            'violence': violence_result,
                            'detected_objects': detected_object
                        }
                        stream_log_object_str = json.dumps(stream_log_object, indent=2)
                        self.data_queue.put(stream_log_object_str)
                        
                except Exception as detection_error:
                    logger.error(f"Object detection error: {detection_error}")
                
                # Update latest results for API
                with self.results_lock:
                    self.latest_results = {
                        "timestamp": time.time(),
                        "violence": violence_result,
                        "objects": detected_objects
                    }
                
                # Add violence detection result to the frame
                cv2.putText(frame, f"Violence: {violence_result['class']} ({violence_result['confidence']:.2f})", 
                            (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                
                # Update the global frame that will be served by FastAPI
                with global_frame_lock:
                    global global_frame
                    global_frame = frame.copy()
                
                # Show output locally if enabled
                if self.display_output:
                    cv2.imshow("YOLOv8 Live Stream", frame)
                    
                    # Press 'q' to stop
                    if cv2.waitKey(1) & 0xFF == ord('q'):
                        break
        
        except Exception as main_loop_error:
            logger.error(f"Main loop error: {main_loop_error}")
        
        finally:
            # Set flag to stop sender thread
            self.is_running = False
            
            # Wait for sender thread to complete
            sender_thread.join()
            
            # Release resources
            cap.release()
            if self.display_output:
                cv2.destroyAllWindows()
            logger.info("Streaming stopped")
    
    def get_latest_results(self):
        """Get the latest detection results"""
        with self.results_lock:
            return self.latest_results.copy()


# FastAPI app
app = FastAPI(
    title="Video Stream Analysis API",
    description="API for real-time video analysis with object and violence detection",
    version="1.0.0"
)

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

# Mount the "static" directory at "/static"
app.mount("/static", StaticFiles(directory="static"), name="static")

# Store the processor instance
video_processor = None

def generate_frames():
    """Generator function for video frames"""
    while True:
        # Get current frame with lock
        with global_frame_lock:
            if global_frame is None:
                time.sleep(0.1)
                continue
            
            # Convert frame to JPEG
            ret, buffer = cv2.imencode('.jpg', global_frame)
            if not ret:
                continue
            
            frame_bytes = buffer.tobytes()
        
        # Yield frame in multipart response
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
        
        # Control frame rate
        time.sleep(0.03)  # ~30fps

@app.get("/", response_class=HTMLResponse)
async def index():
    return HTMLResponse(content=open('static/index.html').read(), status_code=200)

@app.get("/video")
async def video_endpoint():
    """Stream video frames"""
    return StreamingResponse(
        generate_frames(),
        media_type="multipart/x-mixed-replace; boundary=frame"
    )

@app.get("/api/results")
async def get_results():
    """Get latest detection results"""
    global video_processor
    if video_processor:
        return video_processor.get_latest_results()
    return {"error": "Video processor not initialized"}

def start_fastapi_server(host: str, port: int):
    """Start the FastAPI server using uvicorn"""
    import uvicorn
    uvicorn.run(app, host=host, port=port)

def main():
    try:
        # Video URL/Path
        video_path = os.getenv("INPUT_STREAM")
        if not video_path:
            logger.error("No input stream path provided. Set the INPUT_STREAM environment variable.")
            sys.exit(1)
        
        global video_processor
        video_processor = VideoProcessor()
        
        # Start FastAPI server in a separate thread if streaming is enabled
        if video_processor.streaming_enabled:
            server_thread = threading.Thread(
                target=start_fastapi_server,
                args=(video_processor.server_host, video_processor.server_port)
            )
            server_thread.daemon = True
            server_thread.start()
            logger.info(f"FastAPI server started at http://{video_processor.server_host}:{video_processor.server_port}")
        
        # Process video in main thread
        video_processor.process_videos(video_path)
        
    except KeyboardInterrupt:
        logger.info("Process interrupted by user")
    except Exception as e:
        logger.error(f"Unhandled exception: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()