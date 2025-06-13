"""This is an example of simulating a chess game with two agents
that play against each other, using tools to reason about the game state
and make moves. The agents subscribe to the default topic and publish their
moves to the default topic."""

import os
import argparse
import asyncio
import logging
import time
from typing import Annotated, Any, Dict, List, Literal
import queue
from datetime import datetime

from autogen_core import (
    AgentId,
    AgentRuntime,
    DefaultTopicId,
    MessageContext,
    RoutedAgent,
    TimeplusAgentRuntime,
    default_subscription,
    message_handler,
)
from autogen_core.model_context import BufferedChatCompletionContext, ChatCompletionContext
from autogen_core.models import (
    ChatCompletionClient,
    LLMMessage,
    SystemMessage,
    UserMessage,
    ModelInfo
)
from autogen_ext.models.openai import OpenAIChatCompletionClient
from autogen_core.tool_agent import ToolAgent, tool_agent_caller_loop
from autogen_core.tools import FunctionTool, Tool, ToolSchema
from chess import BLACK, SQUARE_NAMES, WHITE, Board, Move
from chess import piece_name as get_piece_name
from pydantic import BaseModel

# Web interface imports
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import json

from proton_driver import client

# Set up more detailed logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global variables for web interface
app = FastAPI(title="Chess Game", description="Two LLM agents playing chess")

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

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

websocket_connections: List[WebSocket] = []
ui_update_queue = queue.Queue()

def get_simple_player_instructions(color: str) -> str:
    return f"""You are a chess player as {color}.

SIMPLE PROCESS:
1. get_board()
2. get_legal_moves() 
3. Pick ONE move from that exact list
4. make_move() with that exact string

RULE: The move string you use in make_move() MUST be one move from get_legal_moves() output.
"""

def get_player_instructions(color: str) -> str:
    return f"""You are a chess player playing as {color} pieces.

Available tools:
1. **get_board**: Get the current board state.
2. **get_legal_moves**: Get a list of legal moves for your color.
3. **make_move**: Make a move on the board.

CRITICAL: You MUST only choose moves that appear in the get_legal_moves output. 
- Copy the exact move string from get_legal_moves
- Do NOT modify or create your own moves
- If you think of a good move, check if it exists in get_legal_moves first
- NEVER make a move that isn't in the legal moves list
- END with exactly one move

REQUIRED WORKFLOW for every turn:
1. First, use get_board to see the current position
2. Then, use get_legal_moves to see your available moves
3. Think about which move you want to make
4. VERIFY: Confirm your chosen move exists exactly in the get_legal_moves list
5. Finally, use make_move with your chosen move

"""

class TextMessage(BaseModel):
    source: str
    content: str


@default_subscription
class PlayerAgent(RoutedAgent):
    def __init__(
        self,
        description: str,
        instructions: str,
        model_client: ChatCompletionClient,
        model_context: ChatCompletionContext,
        tool_schema: List[ToolSchema],
        tool_agent_type: str,
    ) -> None:
        super().__init__(description=description)
        self._system_messages: List[LLMMessage] = [SystemMessage(content=instructions)]
        self._model_client = model_client
        self._tool_schema = tool_schema
        self._tool_agent_id = AgentId(tool_agent_type, self.id.key)
        self._model_context = model_context
        logger.info(f"[AGENT] Created PlayerAgent {self.id.key} with tool agent {self._tool_agent_id}")

    @message_handler
    async def handle_message(self, message: TextMessage, ctx: MessageContext) -> None:
        logger.info(f"[AGENT] Player {self.id.key} received message: {message.content}")
        
        try:
            # Add the user message to the model context.
            await self._model_context.add_message(UserMessage(content=message.content, source=message.source))
            
            # Run the caller loop to handle tool calls.
            logger.info(f"[AGENT] Player {self.id.key} starting tool agent call loop")
            messages = await tool_agent_caller_loop(
                self,
                tool_agent_id=self._tool_agent_id,
                model_client=self._model_client,
                input_messages=self._system_messages + (await self._model_context.get_messages()),
                tool_schema=self._tool_schema,
                cancellation_token=ctx.cancellation_token,
            )
            
            logger.info(f"[AGENT] Player {self.id.key} completed tool agent call loop with {len(messages)} messages")
            
            # Add the assistant message to the model context.
            for msg in messages:
                await self._model_context.add_message(msg)
                
            # Publish the final response.
            assert isinstance(messages[-1].content, str)
            response_message = TextMessage(content=messages[-1].content, source=self.id.type)
            
            logger.info(f"[AGENT] Player {self.id.key} publishing response: {response_message.content}")
            await self.publish_message(response_message, DefaultTopicId())
            
        except Exception as e:
            logger.error(f"[AGENT] Error in PlayerAgent {self.id.key}: {e}", exc_info=True)
            raise


def validate_turn(board: Board, player: Literal["white", "black"]) -> None:
    """Validate that it is the player's turn to move."""
    last_move = board.peek() if board.move_stack else None
    if last_move is not None:
        if player == "white" and board.color_at(last_move.to_square) == WHITE:
            #raise ValueError("It is not your turn to move. Wait for black to move.")
            stop_game(player, last_move.uci(), '', "It is not white's turn to move. Wait for black to move.")
        if player == "black" and board.color_at(last_move.to_square) == BLACK:
            #raise ValueError("It is not your turn to move. Wait for white to move.")
            stop_game(player, last_move.uci(), '', "It is not black's turn to move. Wait for white to move.")      
    elif last_move is None and player != "white":
        #raise ValueError("It is not your turn to move. Wait for white to move first.")
        stop_game(player, '', '', "It is not black's turn to move. Wait for white to move first.")


def get_legal_moves(
    board: Board, player: Literal["white", "black"]
) -> Annotated[str, "A list of legal moves in UCI format."]:
    """Get legal moves for the given player."""
    validate_turn(board, player)
    legal_moves = list(board.legal_moves)
    if player == "black":
        legal_moves = [move for move in legal_moves if board.color_at(move.from_square) == BLACK]
    elif player == "white":
        legal_moves = [move for move in legal_moves if board.color_at(move.from_square) == WHITE]
    else:
        #raise ValueError("Invalid player, must be either 'black' or 'white'.")
        stop_game(player, '', '', "Invalid player, must be either 'black' or 'white'.")
    if not legal_moves:
        return "No legal moves. The game is over."

    return "Possible moves are: " + ", ".join([move.uci() for move in legal_moves])


def get_board(board: Board) -> str:
    """Get the current board state."""
    return str(board)


def update_ui(data):
    """Add data to UI update queue."""
    try:
        ui_update_queue.put_nowait(data)
    except queue.Full:
        pass  # If queue is full, just skip this update


def make_move(
    board: Board,
    player: Literal["white", "black"],
    thinking: Annotated[str, "Thinking for the move."],
    move: Annotated[str, "A move in UCI format."],
) -> Annotated[str, "Result of the move."]:
    """Make a move on the board."""
    try:
        validate_turn(board, player) # sometimes the player try to call move twice in a row, so we need to validate the turn
    except ValueError as e:
        stop_game(player, move, thinking, f"invalid turn - {e}")
    
    try:
        new_move = Move.from_uci(move)
    except Exception as e:
        #raise e
        stop_game(player, move, thinking, error=f"Invalid move: {move} - {e}")
        
    try:
        board.push(new_move) # sometimes the LLM will generate illegal moves
    except Exception as e:
        #raise e
        stop_game(player, move, thinking, error=f"Invalid move: {move} - {e}")  
        
    # Print the move (original code)
    print("-" * 50)
    print("Player:", player)
    print("Move:", new_move.uci())
    print("Thinking:", thinking)
    print("Board:")
    print(board.unicode(borders=True))

    # Get the piece name.
    piece = board.piece_at(new_move.to_square)
    if piece is None:
        #raise ValueError(f"Invalid move: {new_move.uci()} - No piece at destination square.")
        stop_game(player, move, thinking, error=f"Invalid move: {new_move.uci()} - No piece at destination square.")
    
    piece_symbol = piece.unicode_symbol()
    piece_name = get_piece_name(piece.piece_type)
    if piece_symbol.isupper():
        piece_name = piece_name.capitalize()
    
    # Send data to UI
    ui_data = {
        "type": "move",
        "player": player,
        "move": new_move.uci(),
        "thinking": thinking,
        "board_unicode": board.unicode(borders=True),
        "board_fen": board.fen(),
        "from_square": SQUARE_NAMES[new_move.from_square],
        "to_square": SQUARE_NAMES[new_move.to_square],
        "piece_name": piece_name,
        "piece_symbol": piece_symbol,
        "is_check": board.is_check(),
        "is_checkmate": board.is_checkmate(),
        "is_game_over": board.is_game_over(),
        "timestamp": datetime.now().isoformat()
    }
    update_ui(ui_data)
    
    return f"Moved {piece_name} ({piece_symbol}) from {SQUARE_NAMES[new_move.from_square]} to {SQUARE_NAMES[new_move.to_square]}."


async def chess_game(runtime: AgentRuntime, model_client: ChatCompletionClient) -> None:
    """Create agents for a chess game and return the group chat."""
    logger.info("[CHESS] Setting up chess game")

    # Create the board.
    board = Board()

    # Create tools for each player.
    def get_legal_moves_black() -> str:
        result = get_legal_moves(board, "black")
        logger.debug(f"[CHESS] Black legal moves: {result}")
        return result

    def get_legal_moves_white() -> str:
        result = get_legal_moves(board, "white")
        logger.debug(f"[CHESS] White legal moves: {result}")
        return result

    def make_move_black(
        thinking: Annotated[str, "Thinking for the move"],
        move: Annotated[str, "A move in UCI format"],
    ) -> str:
        logger.info(f"[CHESS] Black making move: {move} (thinking: {thinking})")
        return make_move(board, "black", thinking, move)

    def make_move_white(
        thinking: Annotated[str, "Thinking for the move"],
        move: Annotated[str, "A move in UCI format"],
    ) -> str:
        logger.info(f"[CHESS] White making move: {move} (thinking: {thinking})")
        return make_move(board, "white", thinking, move)

    def get_board_text() -> Annotated[str, "The current board state"]:
        result = get_board(board)
        logger.debug(f"[CHESS] Current board state retrieved")
        return result

    black_tools: List[Tool] = [
        FunctionTool(
            get_legal_moves_black,
            name="get_legal_moves",
            description="Get legal moves.",
        ),
        FunctionTool(
            make_move_black,
            name="make_move",
            description="Make a move.",
        ),
        FunctionTool(
            get_board_text,
            name="get_board",
            description="Get the current board state.",
        ),
    ]

    white_tools: List[Tool] = [
        FunctionTool(
            get_legal_moves_white,
            name="get_legal_moves",
            description="Get legal moves.",
        ),
        FunctionTool(
            make_move_white,
            name="make_move",
            description="Make a move.",
        ),
        FunctionTool(
            get_board_text,
            name="get_board",
            description="Get the current board state.",
        ),
    ]

    # Register the agents.
    logger.info("[CHESS] Registering tool agents")
    await ToolAgent.register(
        runtime,
        "PlayerBlackToolAgent",
        lambda: ToolAgent(description="Tool agent for chess game.", tools=black_tools),
    )

    await ToolAgent.register(
        runtime,
        "PlayerWhiteToolAgent",
        lambda: ToolAgent(description="Tool agent for chess game.", tools=white_tools),
    )

    logger.info("[CHESS] Registering player agents")
    await PlayerAgent.register(
        runtime,
        "PlayerBlack",
        lambda: PlayerAgent(
            description="Player playing black.",
            instructions= get_simple_player_instructions("black"),
            model_client=model_client,
            model_context=BufferedChatCompletionContext(buffer_size=10),
            tool_schema=[tool.schema for tool in black_tools],
            tool_agent_type="PlayerBlackToolAgent",
        ),
    )

    await PlayerAgent.register(
        runtime,
        "PlayerWhite",
        lambda: PlayerAgent(
            description="Player playing white.",
            instructions= get_simple_player_instructions("white"),
            model_client=model_client,
            model_context=BufferedChatCompletionContext(buffer_size=10),
            tool_schema=[tool.schema for tool in white_tools],
            tool_agent_type="PlayerWhiteToolAgent",
        ),
    )
    
    logger.info("[CHESS] All agents registered successfully")


# FastAPI Routes
@app.get("/", response_class=HTMLResponse)
async def get_chess_interface():
    """Serve the chess game interface."""
    with open("static/index.html", "r") as f:
        return HTMLResponse(content=f.read())


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time game updates."""
    await websocket.accept()
    websocket_connections.append(websocket)
    logger.info(f"New WebSocket connection. Total connections: {len(websocket_connections)}")
    
    try:
        while True:
            # Keep connection alive and send updates
            await websocket.receive_text()
    except WebSocketDisconnect:
        websocket_connections.remove(websocket)
        logger.info(f"WebSocket disconnected. Total connections: {len(websocket_connections)}")


async def broadcast_updates():
    """Background task to broadcast UI updates."""
    while True:
        try:
            # Check for updates every 0.1 seconds
            await asyncio.sleep(0.1)
            
            updates = []
            while True:
                try:
                    update = ui_update_queue.get_nowait()
                    updates.append(update)
                except queue.Empty:
                    break
            
            # Send updates to all connected clients
            if updates and websocket_connections:
                for update in updates:
                    message = json.dumps(update)
                    active_connections = []
                    for websocket in websocket_connections:
                        try:
                            await websocket.send_text(message)
                            active_connections.append(websocket)
                        except Exception:
                            pass
                    websocket_connections[:] = active_connections
                    
        except Exception as e:
            logger.error(f"Error in broadcast_updates: {e}")
            
def wait_for_timeplus():
    logger.info("[MAIN] wait Timeplus start")
    max_retries = 30  # Add a maximum retry limit
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            # Add connection timeout
            c = client.Client(
                host=os.getenv("TIMEPLUS_HOST", "localhost"),
                port=int(os.getenv("TIMEPLUS_PORT", 8463)),
                user=os.getenv("TIMEPLUS_USER", "proton"),
                password=os.getenv("TIMEPLUS_PASSWORD", "timeplus@t+"),
                database=os.getenv("TIMEPLUS_DATABASE", "default"),
                connect_timeout=5,  # 5 second connection timeout
                send_receive_timeout=10  # 10 second query timeout
            )

            # Test the connection with a timeout
            c.execute("select 1")
            logger.info("[MAIN] Timeplus is ready")
            return  # Exit the function successfully
            
        except Exception as e:
            retry_count += 1
            logger.warning(f"[MAIN] Timeplus not ready (attempt {retry_count}/{max_retries}): {e}")
            time.sleep(1)
    
    # If we get here, all retries failed
    raise Exception(f"Failed to connect to Timeplus after {max_retries} attempts")


async def run_chess_game_async(model_config: Dict[str, Any]) -> None:
    """Run the chess game with agents."""
    logger.info("[MAIN] Starting chess game application") 
    try:
        # Create runtime
        logger.info("[MAIN] Creating TimeplusAgentRuntime")
        runtime = TimeplusAgentRuntime(
            host=os.getenv("TIMEPLUS_HOST", "localhost"),
            port=int(os.getenv("TIMEPLUS_PORT", 8463)),
            user=os.getenv("TIMEPLUS_USER", "proton"),
            password=os.getenv("TIMEPLUS_PASSWORD", "timeplus@t+"),
            database=os.getenv("TIMEPLUS_DATABASE", "default"),
        )
        
        logger.info("[MAIN] Loading model client")
        
        model_info = ModelInfo(
            family=model_config["model"],
            function_calling=True,
            json_output=False,
            vision=False,
        )
        
        model_client = OpenAIChatCompletionClient(
            model=model_config["model"],
            base_url=model_config["base_url"],
            api_key=model_config["api_key"],
            model_info=model_info,
            temperature=1.0,
        )
        
        #model_client = ChatCompletionClient.load_component(model_config)
        
        logger.info("[MAIN] Setting up chess game")
        await chess_game(runtime, model_client)
        
        logger.info("[MAIN] Starting runtime")
        runtime.start()
        
        logger.info("[MAIN] Runtime is ready, sending initial message to start the game")
        
        # Send an initial message to player white to start the game.
        initial_message = TextMessage(content="Game started, white player your move.", source="System")
        white_agent_id = AgentId("PlayerWhite", "default")
        
        logger.info(f"[MAIN] Sending message to {white_agent_id}: {initial_message.content}")
        await runtime.send_message(initial_message, white_agent_id)
        
        logger.info("[MAIN] Waiting for game to complete")
        await runtime.stop_when_idle()
        
        logger.info("[MAIN] Game completed, closing model client")
        await model_client.close()
        
    except Exception as e:
        logger.error(f"[MAIN] Error in main: {e}", exc_info=True)
        raise
    finally:
        logger.info("[MAIN] Application finished")
        
def get_model_config() -> Dict[str, Any]:
    """Get the model configuration from environment variables."""
    return {
            "model": os.getenv("OPENAI_MODEL", "gpt-4o"),
            "api_key": os.getenv("OPENAI_API_KEY"),
            "base_url": os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1"),
        }

async def start_cli():
    await run_chess_game_async(get_model_config())

def start_web_server(host: str = "0.0.0.0", port: int = 5001):
    """Start the FastAPI web server."""
    
    # Start the chess game in the background
    async def startup_event():
        """Start the chess game when the server starts."""
        logger.info("[STARTUP] Starting chess game and broadcast task")
        asyncio.create_task(broadcast_updates())
        asyncio.create_task(run_chess_game_async(get_model_config()))
    
    app.add_event_handler("startup", startup_event)
    
    # Start the server
    logger.info(f"[STARTUP] Starting web server on {host}:{port}")
    uvicorn.run(app, host=host, port=port)
    
def stop_game(player: str , move: str , thinking: str , error: str ):
    """Stop the chess game and close the runtime."""
    logger.info("[STOP] Stopping chess game")
    
    error_msg = f"Game stopped due to an error: {error}"
    
    ui_data = {
        "type": "error",
        "player": player,
        "move": move,
        "thinking": thinking,
        "error":error_msg
    }
    update_ui(ui_data)
    
    time.sleep(5)
    os._exit(1)  # Force exit the application


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run a chess game between two agents.")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging.")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host to bind the web server to.")
    parser.add_argument("--port", type=int, default=5001, help="Port to bind the web server to.")
    
    parser.add_argument("--cli", type=bool, default=False, help="whether to run in CLI mode.")
    
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger("autogen_core").setLevel(logging.DEBUG)
        logging.getLogger(__name__).setLevel(logging.DEBUG)
        
        # Add file handler for detailed logs
        handler = logging.FileHandler("chess_game.log")
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        logging.getLogger("autogen_core").addHandler(handler)
        logging.getLogger(__name__).addHandler(handler)

    wait_for_timeplus()
    if args.cli:
        asyncio.run(start_cli())
    else:
        # Start the web server
        start_web_server(args.host, args.port)