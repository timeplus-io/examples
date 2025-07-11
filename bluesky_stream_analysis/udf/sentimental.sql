
CREATE OR REPLACE FUNCTION sentiment_analyzer(input string) RETURNS string LANGUAGE PYTHON AS 
$$
import json
import traceback
from transformers import pipeline

pipe = pipeline("text-classification", 
                model="distilbert/distilbert-base-uncased-finetuned-sst-2-english", 
                device="cpu",
                trust_remote_code=False)

def sentiment_analyzer(input):
    results = []
    for input_string in input:
        try:
            input_string = input_string[:1024]
            result = pipe(input_string, truncation=True, max_length=512)
            results.append(json.dumps(result[0]))
        except Exception as e:
            trace = traceback.format_exc()
            results.append(trace)

    return results

$$;

CREATE OR REPLACE FUNCTION sentiment_analyzer_complex(input string) RETURNS string LANGUAGE PYTHON AS 
$$
import json
import traceback
import torch
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModelForSequenceClassification

# Check if GPU is available and set device accordingly
device = "cuda" if torch.cuda.is_available() else "cpu"

# Force gradient calculation off for inference
torch.set_grad_enabled(False)

# Load model components separately
model_name = "distilbert-base-uncased-finetuned-sst-2-english"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForSequenceClassification.from_pretrained(
    model_name, 
    torchscript=True,
    return_dict=False
)
# Move model to appropriate device
model = model.to(device)
model.eval()  # Set to evaluation mode

def sentiment_analyzer_complex(input):
    results = []
    
    # Check if input is a string or list-like
    if isinstance(input, str):
        inputs = [input]
    else:
        inputs = input
        
    for input_string in inputs:
        try:
            input_string = str(input_string)[:1024]
            
            # Manual processing instead of using pipeline
            encoded_input = tokenizer(input_string, 
                                     truncation=True, 
                                     max_length=512, 
                                     return_tensors='pt')
            
            # Move input tensors to the same device as model
            encoded_input = {k: v.to(device) for k, v in encoded_input.items()}
            
            with torch.no_grad():
                output = model(**encoded_input)
                
            # Get prediction and convert to probabilities
            logits = output[0][0].detach()
            
            # Apply softmax to convert logits to probabilities
            probs = F.softmax(logits, dim=0)
            
            # Move results back to CPU for numpy conversion if needed
            if device != "cpu":
                probs = probs.cpu()
                
            probs = probs.numpy()
            
            # Create result with probabilities
            result = {
                "label": model.config.id2label[probs.argmax().item()],
                "score": float(probs.max().item()),  # Max probability
                "details": {
                    model.config.id2label[i]: float(prob) 
                    for i, prob in enumerate(probs)
                }
            }
            
            results.append(json.dumps(result))
            
        except Exception as e:
            trace = traceback.format_exc()
            results.append(f"Error: {str(e)}\n{trace}")

    # Return a single string if input was single, otherwise return the list
    if isinstance(input, str):
        return results[0] if results else ""
    return results

$$;


CREATE OR REPLACE FUNCTION get_bluesky_post_by_id(id string, uri string) RETURNS string LANGUAGE PYTHON AS 
$$
import requests
import json
from typing import Dict, Any, Optional
from dataclasses import dataclass, asdict

@dataclass
class BlueskyPost:
    cid: str
    uri: str
    text: str
    author_did: str
    author_handle: str
    created_at: str
    reply_to: Optional[Dict] = None
    images: list = None
    embedding: Optional[Dict] = None
    likes: int = 0
    reposts: int = 0

    def to_json(self) -> str:
        return json.dumps(asdict(self), ensure_ascii=False)

class BlueskyPostFetcher:
    def __init__(self, service_url: str = "https://bsky.social"):
        self.service_url = service_url
        self.auth_token = None
    
    def authenticate(self, identifier: str, password: str) -> bool:
        """Authenticate with Bluesky to get an access token"""
        auth_url = f"{self.service_url}/xrpc/com.atproto.server.createSession"
        try:
            response = requests.post(auth_url, json={
                "identifier": identifier,
                "password": password
            })
            response.raise_for_status()
            
            data = response.json()
            self.auth_token = data.get('accessJwt')
            
            if not self.auth_token:
                print("Authentication failed: No access token received")
                return False
                
            print("Authentication successful!")
            return True
            
        except requests.exceptions.HTTPError as e:
            print(f"Authentication failed with HTTP error: {e.response.status_code}")
            print(f"Error message: {e.response.text}")
        except Exception as e:
            print(f"Authentication failed with error: {e}")
        return False

    def get_post_by_cid(self, cid: str, uri: Optional[str] = None) -> Optional[BlueskyPost]:
        """Fetch post information using CID and optionally URI"""
        if not self.auth_token:
            print("Not authenticated. Please authenticate first.")
            return None

        headers = {"Authorization": f"Bearer {self.auth_token}"}
        
        try:
            # If URI is not provided, we need to find it first using the record endpoint
            if not uri:
                print("No URI provided, attempting to find post...")
                # This might require additional steps to find the URI
                return None

            # Get post using the getPostThread endpoint
            post_url = f"{self.service_url}/xrpc/app.bsky.feed.getPostThread"
            params = {"uri": uri}
            
            response = requests.get(post_url, headers=headers, params=params)
            response.raise_for_status()
            
            data = response.json()
            thread = data.get('thread', {})
            post = thread.get('post', {})
            
            if not post:
                print(f"No post found for URI: {uri}")
                return None

            # Extract post information
            record = post.get('record', {})
            author = post.get('author', {})
            
            # Handle embedded content
            embed = record.get('embed', {})
            images = []
            if embed and embed.get('$type') == 'app.bsky.embed.images':
                for img in embed.get('images', []):
                    image_data = img.get('image', {})
                    image_info = {
                        'alt': img.get('alt', ''),
                        'cid': image_data.get('ref', {}).get('$link', ''),
                        'mime_type': image_data.get('mimeType', ''),
                        'size': image_data.get('size', 0)
                    }
                    images.append(image_info)

            # Handle reply
            reply_to = None
            if record.get('reply'):
                reply_to = {
                    'root': record['reply'].get('root', {}).get('uri'),
                    'parent': record['reply'].get('parent', {}).get('uri')
                }

            return BlueskyPost(
                cid=post.get('cid'),
                uri=post.get('uri'),
                text=record.get('text', ''),
                author_did=author.get('did'),
                author_handle=author.get('handle'),
                created_at=record.get('createdAt'),
                reply_to=reply_to,
                images=images,
                likes=post.get('likeCount', 0),
                reposts=post.get('repostCount', 0)
            )

        except requests.exceptions.HTTPError as e:
            print(f"Error fetching post - HTTP {e.response.status_code}: {e.response.text}")
        except Exception as e:
            print(f"Error fetching post: {e}")
        
        return None

fetcher = BlueskyPostFetcher()
fetcher.authenticate("gangtao.bsky.social", "j45ZimSZnzGhz8Z")  # Replace with actual credentials

def get_bluesky_post_by_id(ids, uris):
    results = []
    for id, uri in zip(ids, uris):
        try:
            post = fetcher.get_post_by_cid(id,uri)
            if post:
                results.append(post.to_json())
            else:
                results.append(f"Post with ID {id} not found.")
        except Exception as e:
            trace = traceback.format_exc()
            results.append(trace)

    return results

$$;

CREATE OR REPLACE FUNCTION get_bluesky_user_by_id(id string) RETURNS string LANGUAGE PYTHON AS 
$$
import requests
import json
from typing import Dict, Any, Optional
from dataclasses import dataclass, asdict

@dataclass
class BlueskyUser:
    did: str
    handle: str
    display_name: Optional[str] = None
    description: Optional[str] = None
    followers: int = 0
    following: int = 0
    posts: int = 0
    avatar_url: Optional[str] = None

    def to_json(self) -> str:
        return json.dumps(asdict(self), ensure_ascii=False)

class BlueskyUserFetcher:
    def __init__(self, service_url: str = "https://bsky.social"):
        self.service_url = service_url
        self.auth_token = None
    
    def authenticate(self, identifier: str, password: str) -> bool:
        """Authenticate with Bluesky to get an access token"""
        auth_url = f"{self.service_url}/xrpc/com.atproto.server.createSession"
        try:
            response = requests.post(auth_url, json={
                "identifier": identifier,
                "password": password
            })
            response.raise_for_status()  # This will raise an exception for error status codes
            
            data = response.json()
            self.auth_token = data.get('accessJwt')
            
            if not self.auth_token:
                print("Authentication failed: No access token received")
                return False
                
            print("Authentication successful!")
            return True
            
        except requests.exceptions.HTTPError as e:
            print(f"Authentication failed with HTTP error: {e.response.status_code}")
            print(f"Error message: {e.response.text}")
        except requests.exceptions.RequestException as e:
            print(f"Authentication failed with error: {e}")
        except json.JSONDecodeError:
            print("Authentication failed: Invalid response format")
        return False

    def get_user_info(self, did: str) -> Optional[BlueskyUser]:
        """Fetch user information using DID"""
        if not self.auth_token:
            print("Not authenticated. Attempting to proceed without authentication...")
            return None

        headers = {"Authorization": f"Bearer {self.auth_token}"}
        
        # Get basic profile info
        profile_url = f"{self.service_url}/xrpc/app.bsky.actor.getProfile"
        params = {"actor": did}
        
        try:
            response = requests.get(profile_url, headers=headers, params=params)
            response.raise_for_status()
            
            data = response.json()
            
            # Construct avatar URL if exists
            avatar_url = None
            if 'avatar' in data:
                # The avatar URL is directly available in the response
                avatar_url = data['avatar']
            
            return BlueskyUser(
                did=data.get('did'),
                handle=data.get('handle'),
                display_name=data.get('displayName'),
                description=data.get('description'),
                followers=data.get('followersCount', 0),
                following=data.get('followsCount', 0),
                posts=data.get('postsCount', 0),
                avatar_url=avatar_url
            )
        except requests.exceptions.HTTPError as e:
            print(f"Error fetching user info - HTTP {e.response.status_code}: {e.response.text}")
        except Exception as e:
            print(f"Error fetching user info: {e}")
        
        return None

fetcher = BlueskyUserFetcher()
fetcher.authenticate("username", "password")  # Replace with actual credentials

def get_bluesky_user_by_id(ids):
    results = []
    for did in ids:
        try:
            user = fetcher.get_user_info(did)
            if user:
                results.append(user.to_json())
            else:
                results.append(f"User with ID {did} not found.")
        except Exception as e:
            trace = traceback.format_exc()
            results.append(trace)

    return results

$$;