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