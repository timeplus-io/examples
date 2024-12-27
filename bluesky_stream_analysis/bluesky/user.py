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