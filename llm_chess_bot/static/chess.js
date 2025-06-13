class ChessUI {
    constructor() {
        this.websocket = null;
        this.connectWebSocket();
        this.initializeBoard();
    }
    
    connectWebSocket() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}/ws`;
        
        this.websocket = new WebSocket(wsUrl);
        
        this.websocket.onopen = () => {
            console.log('WebSocket connected');
        };
        
        this.websocket.onmessage = (event) => {
            const data = JSON.parse(event.data);
            this.handleUpdate(data);
        };
        
        this.websocket.onclose = () => {
            console.log('WebSocket disconnected');
            setTimeout(() => this.connectWebSocket(), 3000);
        };
        
        this.websocket.onerror = (error) => {
            console.error('WebSocket error:', error);
        };
    }
    
    initializeBoard() {
        const board = document.getElementById('chessBoard');
        board.innerHTML = '';
        
        for (let rank = 8; rank >= 1; rank--) {
            for (let file = 0; file < 8; file++) {
                const square = document.createElement('div');
                const squareName = String.fromCharCode(97 + file) + rank;
                square.id = squareName;
                square.className = `square ${(rank + file) % 2 === 0 ? 'dark' : 'light'}`;
                board.appendChild(square);
            }
        }
    }
    
    handleUpdate(data) {
        if (data.type === 'move') {
            this.updateCurrentMove(data);
            this.addMoveToHistory(data);
            this.updateBoardText(data.board_unicode);
            this.updateBoardFromFEN(data.board_fen);
            this.highlightMove(data.from_square, data.to_square);
            this.hideError();
        } else if (data.type === 'error') {
            this.updateError(data);
        }
    }

    hideError() {
        const currentError = document.getElementById('currentError');
        currentError.className = 'current-error';
        currentError.innerHTML = '';
    }

    updateError(data) {
        const currentError = document.getElementById('currentError');
        currentError.className = 'current-error show';
        currentError.innerHTML = `
            <strong>Error:</strong> ${data.error} <br>
            <strong>${data.player.charAt(0).toUpperCase() + data.player.slice(1)}:</strong> ${data.move}<br>
            <strong>Thinking:</strong> ${data.thinking} <br>
        `;
    }
    
    updateCurrentMove(data) {
        const currentMove = document.getElementById('currentMove');
        currentMove.innerHTML = `
            <strong>${data.player.charAt(0).toUpperCase() + data.player.slice(1)}:</strong> ${data.move}<br>
            <strong>From:</strong> ${data.from_square} → <strong>To:</strong> ${data.to_square}<br>
            <strong>Piece:</strong> ${data.piece_name} (${data.piece_symbol})<br>
            <strong>Thinking:</strong> ${data.thinking}
        `;
    }
    
    addMoveToHistory(data) {
        const container = document.getElementById('movesContainer');
        
        if (container.children.length === 1 && container.children[0].textContent.includes('Waiting')) {
            container.innerHTML = '';
        }
        
        const moveEntry = document.createElement('div');
        moveEntry.className = `move-entry ${data.player}`;
        moveEntry.innerHTML = `
            <strong>${data.player.charAt(0).toUpperCase() + data.player.slice(1)}:</strong> 
            ${data.move} (${data.from_square} → ${data.to_square})<br>
            <small>${data.thinking}</small>
        `;
        
        container.appendChild(moveEntry);
        container.scrollTop = container.scrollHeight;
    }
    
    updateBoardText(boardUnicode) {
        document.getElementById('boardText').textContent = boardUnicode;
    }
    
    updateBoardFromFEN(fen) {
        const board = fen.split(' ')[0];
        const ranks = board.split('/');
        
        // Clear all pieces
        document.querySelectorAll('.square').forEach(square => {
            square.textContent = '';
        });
        
        // Place pieces
        for (let rankIndex = 0; rankIndex < 8; rankIndex++) {
            const rank = ranks[rankIndex];
            let fileIndex = 0;
            
            for (let char of rank) {
                if ('12345678'.includes(char)) {
                    fileIndex += parseInt(char);
                } else {
                    const squareName = String.fromCharCode(97 + fileIndex) + (8 - rankIndex);
                    const square = document.getElementById(squareName);
                    if (square) {
                        //square.textContent = this.getPieceUnicode(char);
                        square.innerHTML = this.getPieceEl(char);
                    }
                    fileIndex++;
                }
            }
        }
    }
    
    getPieceUnicode(piece) {
        const pieces = {
            'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟',
            'K': '♔', 'Q': '♕', 'R': '♖', 'B': '♗', 'N': '♘', 'P': '♙' 
        };
        
        return pieces[piece] || '';
    }

    getPieceEl(piece) {
        const pieces = {
            'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟',
            'K': '♚', 'Q': '♛', 'R': '♜', 'B': '♝', 'N': '♞', 'P': '♟' 
        };
        
        const isWhite = piece === piece.toUpperCase();
        const colorClass = isWhite ? 'white' : 'black';
        const char = pieces[piece];
        return `<span class="piece ${colorClass}">${char}</span>`;
    }
    
    highlightMove(fromSquare, toSquare) {
        // Clear previous highlights
        document.querySelectorAll('.square.highlight').forEach(square => {
            square.classList.remove('highlight');
        });
        
        // Highlight the move
        const from = document.getElementById(fromSquare);
        const to = document.getElementById(toSquare);
        
        if (from) from.classList.add('highlight');
        if (to) to.classList.add('highlight');
        
        // Remove highlight after 3 seconds
        setTimeout(() => {
            if (from) from.classList.remove('highlight');
            if (to) to.classList.remove('highlight');
        }, 3000);
    }
}

// Initialize the chess UI when the page loads
document.addEventListener('DOMContentLoaded', () => {
    new ChessUI();
});
