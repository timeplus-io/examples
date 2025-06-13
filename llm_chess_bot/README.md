# 🤖 CheckBot: LLM Chess Battle

An interactive chess game where two Large Language Model (LLM) agents play against each other, demonstrating AI agent communication and decision-making through the game of chess. The system uses Timeplus for real-time agent communication and provides both a web interface and CLI mode for gameplay observation.

## 🎯 Overview

This project showcases:
- **AI Agent Communication**: Two LLM agents (white and black players) communicate through Timeplus messaging
- **Real-time Chess Gameplay**: Watch AI agents make moves with their reasoning displayed
- **Web Interface**: Interactive chess board with live move updates and game history
- **Agent Monitoring**: Dashboard for analyzing agent behavior, hallucinations, and decision patterns
- **Tool-based Architecture**: Agents use structured tools to interact with the chess board

## 🏗️ Architecture

The system consists of several key components:

- **PlayerAgent**: LLM-powered chess players that use tools to analyze board state and make moves
- **ToolAgent**: Provides chess-specific tools (get_board, get_legal_moves, make_move)
- **TimeplusAgentRuntime**: Handles real-time communication between agents
- **FastAPI Web Server**: Serves the chess interface and WebSocket updates
- **Timeplus Database**: Stores and streams agent communication messages

## 🚀 Features

### Chess Gameplay
- Two AI agents play a complete chess game
- Real-time move validation and board state management
- Game state visualization with Unicode chess board
- Move history and player reasoning display

### Web Interface
- Interactive chess board with piece visualization
- Live move updates via WebSocket
- Current move display with AI reasoning
- Complete move history
- Error handling and game status updates

### Monitoring & Analytics
- Agent communication message tracking
- Hallucination detection (illegal moves, turn violations)
- Move analysis and thinking process visualization
- Real-time dashboard with multiple analytics panels

## 🛠️ Installation

### Prerequisites
- Python 3.13+
- Docker and Docker Compose
- OpenAI API key (or compatible LLM API)

### Environment Setup

1. **Clone the repository**
```bash
git clone <repository-url>
cd llm_chess_bot
```

2. **Set up environment variables**
Create a `.env` file with:
```bash
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_MODEL=gpt-4o
OPENAI_BASE_URL=https://api.openai.com/v1
```

3. **Install dependencies**
```bash
# Using uv (recommended)
uv sync

# Or using pip
pip install -r requirements.txt
```

## 🎮 Usage

### Option 1: Docker Compose (Recommended)

Start the complete system with Timeplus and the chess application:

```bash
docker-compose up -d
```

This will start:
- Timeplus database on port 8463
- Chess web interface on port 5001
- Timeplus web console on port 8000

### Option 2: Local Development

1. **Start Timeplus database**
```bash
make timeplus
# Or manually:
docker run -p 8463:8463 timeplus/timeplus-enterprise:2.9.0-rc.3
```

2. **Run the chess application**
```bash
# Web interface mode (default)
python main_server.py --host 0.0.0.0 --port 5001

# CLI mode
python main_server.py --cli true

# Verbose logging
python main_server.py --verbose
```

### Accessing the Application

- **Chess Game Interface**: http://localhost:5001
- **Timeplus Console**: http://localhost:8000
- **Dashboard**: Import `dashboard/dashboard.json` into Timeplus console

## 🎯 How It Works

### Agent Workflow

Each chess agent follows this process:

1. **Receive Turn Signal**: Agent receives message indicating it's their turn
2. **Analyze Board**: Uses `get_board()` tool to see current position
3. **Get Legal Moves**: Uses `get_legal_moves()` tool to see available moves
4. **Reason About Move**: LLM analyzes position and selects best move
5. **Make Move**: Uses `make_move(thinking, move)` tool to execute the move
6. **Publish Result**: Sends move result to trigger opponent's turn

### Communication Flow

```
System → White Agent → ToolAgent → Chess Board → UI Update
   ↓                                                ↑
Black Agent ← Message Bus ← Move Result ← Board State
```

### Error Handling

The system includes robust error handling for:
- Invalid moves (not in legal moves list)
- Turn violations (playing out of turn)
- Malformed move notation
- Agent communication failures

## 📊 Monitoring

The dashboard provides several analytics panels:

1. **Message Stats per Type**: Communication pattern analysis
2. **Chess Board**: Live game visualization
3. **Thinking and Moves**: Agent reasoning display
4. **Hallucination Detection**: 
   - Illegal move attempts
   - Turn violation detection

## 🔧 Configuration

### Model Configuration

Supported LLM providers:
- OpenAI (GPT-4, GPT-3.5)
- Azure OpenAI
- Any OpenAI-compatible API

### Timeplus Configuration

Environment variables for Timeplus connection:
```bash
TIMEPLUS_HOST=localhost
TIMEPLUS_PORT=8463
TIMEPLUS_USER=proton
TIMEPLUS_PASSWORD=timeplus@t+
TIMEPLUS_DATABASE=default
```

## 🧪 Development

### Project Structure

```
├── main_server.py          # Main application server
├── static/                 # Web interface files
│   ├── index.html         # Chess board UI
│   ├── chess.js           # Frontend JavaScript
│   └── style.css          # Styling
├── dashboard/             # Timeplus dashboard config
│   └── dashboard.json     # Dashboard panels
├── script/                # SQL monitoring scripts
│   └── monitor.sql        # Agent monitoring queries
├── docker-compose.yaml    # Docker services
├── Dockerfile            # Application container
├── pyproject.toml        # Python dependencies
└── requirements.txt      # Pip requirements
```

### Building Docker Image

```bash
# Build multi-platform image
make dockerx

# Or build locally
docker build -t chess-bot .
```

### Running Tests

```bash
# Run with verbose logging to see agent communication
python main_server.py --verbose --cli true
```


## 📝 License

This project is part of the Timeplus examples collection and is provided for educational and demonstration purposes.

## 🔗 Related Links

- [Timeplus Documentation](https://docs.timeplus.com/)
- [AutoGen Core](https://github.com/microsoft/autogen)
- [Chess.py Library](https://python-chess.readthedocs.io/)

## 🐛 Troubleshooting

### Common Issues

1. **Connection refused to Timeplus**
   - Ensure Timeplus is running: `docker ps`
   - Check port 8463 is available
   - Wait for Timeplus to fully start (30-60 seconds)

2. **Agents not making moves**
   - Check OpenAI API key is valid
   - Verify model name is correct
   - Check logs for LLM errors: `--verbose` flag

3. **Web interface not updating**
   - Check WebSocket connection in browser dev tools
   - Ensure port 5001 is accessible
   - Restart the application

### Logs

Enable detailed logging:
```bash
python main_server.py --verbose
```

Logs are written to `chess_game.log` when verbose mode is enabled.
