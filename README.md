# AI-Powered Code Editor with Live Preview

A comprehensive web-based code editor with AI assistant integration, live preview, notebook interface, and advanced data management features.

## 🚀 Features

### Core Features
- **Split-Screen Layout**: Side-by-side code editor and live preview iframe
- **Live Preview**: Real-time HTML/CSS/JavaScript preview
- **Syntax Highlighting**: CodeMirror editor with multiple language support
- **File Operations**: Upload, download, read, and write files
- **Responsive Resizable Panels**: Drag-and-drop panel resizing

### AI Integration
- **Multiple AI APIs**: 
  - DeepSeek API
  - Google Gemini API
  - OpenAI/Copilot API
- **Interactive AI Assistant**: Chat interface with AI models
- **AI-Assisted Data Formatting**: Auto-format data sheets with AI
- **Auto API Gateway**: Unified interface for multiple AI services

### Advanced Features
- **Notebook Interface**: Create and run code cells like Jupyter
- **Dynamic Data Sheets**: Create, edit, and manage structured data
- **AI-Assisted Databank**: Store and retrieve key-value data
- **API Key Vault**: Secure storage for API credentials (local storage)
- **Local Server Connection**: Express.js server for backend operations

## 📋 Prerequisites

- Node.js (v14 or higher)
- npm or yarn

## 🛠️ Installation

1. Clone the repository:
```bash
git clone https://github.com/brettanthonysjoberg179-lab/brettappscode.git
cd brettappscode
```

2. Install dependencies:
```bash
npm install
```

3. (Optional) Create a `.env` file for server configuration:
```bash
cp .env.example .env
```

## 🚀 Usage

### Start the Server

Development mode (with auto-reload):
```bash
npm run dev
```

Production mode:
```bash
npm start
```

The application will be available at `http://localhost:3000`

## 📖 How to Use

### 1. Code Editor
- Write HTML, CSS, JavaScript, Python, or Markdown
- Switch language modes using the dropdown
- Live preview updates automatically as you type
- Use the split-screen resizer to adjust panel sizes

### 2. File Operations
- **New**: Create a new file
- **Save**: Save current file to server
- **Upload**: Upload files from your computer
- **Download**: Download current file
- Click on files in the sidebar to load them

### 3. AI Assistant
- Click "🤖 AI Assistant" to open the AI panel
- Select your preferred AI service (DeepSeek, Gemini, or OpenAI)
- Enter your API key in the API Vault first
- Type your prompt and press Send or Ctrl+Enter
- AI responses appear in the chat interface

### 4. API Key Vault
- Click "🔑 API Vault" to manage API keys
- Enter API keys for different services
- Keys are stored securely in browser local storage
- Status indicators show which keys are configured

### 5. Notebook Interface
- Click "📓 Notebook" to open the notebook panel
- Add code or markdown cells
- Write JavaScript code and run it
- View output in the cell output area
- Delete cells as needed

### 6. Databank
- Click "💾 Databank" to open the databank panel
- Store key-value pairs
- Supports JSON values
- Load all saved data
- Use for persistent data storage

### 7. Data Sheets
- Create structured data sheets
- Click "New Sheet" in the sidebar
- Edit data in JSON format
- Use "AI Assist" to format data with AI
- Save sheets with unique IDs

## 🔧 API Endpoints

The server provides the following REST API endpoints:

### File Operations
- `POST /api/upload` - Upload a file
- `GET /api/download/:filename` - Download a file
- `GET /api/read/:filename` - Read file content
- `POST /api/write` - Write file content
- `GET /api/files` - List all files

### AI Gateway
- `POST /api/gateway` - Unified AI API gateway
  ```json
  {
    "service": "deepseek|gemini|copilot",
    "apiKey": "your_api_key",
    "prompt": "your_prompt",
    "model": "optional_model_name"
  }
  ```

### Data Management
- `GET /api/datasheet/:id` - Get data sheet
- `POST /api/datasheet` - Create data sheet
- `PUT /api/datasheet/:id` - Update data sheet
- `GET /api/databank/:key` - Get databank value
- `POST /api/databank` - Save databank entry
- `GET /api/databank` - Get all databank entries

## 🔑 Getting API Keys

### DeepSeek
Visit [DeepSeek Platform](https://platform.deepseek.com/) to get your API key

### Google Gemini
Visit [Google AI Studio](https://makersuite.google.com/app/apikey) to get your API key

### OpenAI
Visit [OpenAI Platform](https://platform.openai.com/api-keys) to get your API key

## 🏗️ Project Structure

```
brettappscode/
├── public/
│   ├── index.html      # Main HTML file
│   ├── styles.css      # Styles
│   └── app.js          # Frontend JavaScript
├── uploads/            # Uploaded files (created automatically)
├── server.js           # Express server
├── package.json        # Dependencies
└── README.md          # This file
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- CodeMirror for the code editor
- Express.js for the server framework
- All the AI API providers

## 🐛 Known Issues

- API keys are stored in browser local storage (not encrypted)
- Notebook cell execution is limited to JavaScript
- File uploads are stored on the server filesystem

## 🔒 Security Considerations

- **API Keys**: Stored in browser local storage. For production use, implement server-side encryption.
- **Notebook Cells**: Uses `eval()` for code execution (similar to Jupyter). Only run trusted code.
- **File Operations**: Server validates file paths to prevent traversal attacks.
- **Upload Directory**: Created with restricted permissions (0o755).
- **Rate Limiting**: API endpoints limited to 30 requests/minute per IP to prevent DoS attacks.
- **XSS Prevention**: Markdown content is HTML-escaped to prevent cross-site scripting.

## 🔮 Future Enhancements

- Add more AI models and providers
- Implement collaborative editing
- Add version control integration
- Enhanced data visualization
- Mobile app version
