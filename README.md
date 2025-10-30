# brettappscode
code editor with live preview

A web-based code editor with real-time HTML/CSS/JavaScript preview.

## Features

- **Split-panel interface** - Code editor on the left, live preview on the right
- **Syntax highlighting** - Powered by CodeMirror with Monokai theme
- **Real-time updates** - See your changes instantly with automatic preview refresh
- **Manual refresh** - Refresh button for manual control
- **Professional UI** - Dark theme similar to VS Code

## Usage

1. Install dependencies:
   ```bash
   npm install
   ```

2. Start the application:
   ```bash
   npm start
   ```

3. Open your browser to [http://localhost:3000](http://localhost:3000)

4. Start coding! Edit the HTML/CSS/JavaScript in the left panel and watch the preview update in real-time on the right.

## Technology Stack

- **CodeMirror** - Advanced code editor component
- **Vanilla JavaScript** - No heavy frameworks needed
- **Blob URLs** - Secure preview rendering
- **Sandboxed iframe** - Safe code execution environment
