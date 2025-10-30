// Initialize CodeMirror editor
let editor;
let currentFile = 'untitled.html';
let apiKeys = {};
let notebookCells = [];
let sheetEditor;

// Initialize editor on page load
document.addEventListener('DOMContentLoaded', () => {
    initializeEditor();
    initializeResizer();
    initializeEventListeners();
    loadApiKeys();
    loadFileList();
    updateLivePreview();
});

// Initialize CodeMirror
function initializeEditor() {
    editor = CodeMirror(document.getElementById('editor'), {
        mode: 'htmlmixed',
        theme: 'monokai',
        lineNumbers: true,
        autoCloseBrackets: true,
        autoCloseTags: true,
        matchBrackets: true,
        indentUnit: 2,
        tabSize: 2,
        lineWrapping: true
    });
    
    editor.setSize('100%', '100%');
    
    // Auto-update preview on change
    editor.on('change', debounce(() => {
        updateLivePreview();
    }, 500));
    
    // Set default content
    editor.setValue(`<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My Page</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
        }
        h1 { color: #667eea; }
    </style>
</head>
<body>
    <h1>Welcome to AI Code Editor</h1>
    <p>Start coding and see live preview!</p>
    <script>
        console.log('Hello from the live preview!');
    </script>
</body>
</html>`);
}

// Initialize split-screen resizer
function initializeResizer() {
    const resizer = document.getElementById('resizer');
    const editorSection = document.querySelector('.editor-section');
    const previewSection = document.querySelector('.preview-section');
    
    let isResizing = false;
    
    resizer.addEventListener('mousedown', (e) => {
        isResizing = true;
        document.body.style.cursor = 'col-resize';
    });
    
    document.addEventListener('mousemove', (e) => {
        if (!isResizing) return;
        
        const container = document.querySelector('.split-container');
        const containerRect = container.getBoundingClientRect();
        const newWidth = ((e.clientX - containerRect.left) / containerRect.width) * 100;
        
        if (newWidth > 20 && newWidth < 80) {
            editorSection.style.flex = `0 0 ${newWidth}%`;
            previewSection.style.flex = `0 0 ${100 - newWidth}%`;
        }
    });
    
    document.addEventListener('mouseup', () => {
        isResizing = false;
        document.body.style.cursor = 'default';
    });
}

// Initialize event listeners
function initializeEventListeners() {
    // Editor mode change
    document.getElementById('editorMode').addEventListener('change', (e) => {
        editor.setOption('mode', e.target.value);
    });
    
    // Refresh preview
    document.getElementById('refreshPreview').addEventListener('click', () => {
        updateLivePreview();
    });
    
    // File operations
    document.getElementById('newFile').addEventListener('click', newFile);
    document.getElementById('saveFile').addEventListener('click', saveFile);
    document.getElementById('uploadFile').addEventListener('change', uploadFile);
    document.getElementById('downloadFile').addEventListener('click', downloadFile);
    
    // Panel toggles
    document.getElementById('toggleNotebook').addEventListener('click', () => togglePanel('notebookPanel'));
    document.getElementById('toggleAI').addEventListener('click', () => togglePanel('aiPanel'));
    document.getElementById('toggleApiVault').addEventListener('click', () => togglePanel('apiVaultPanel'));
    document.getElementById('toggleDatabank').addEventListener('click', () => togglePanel('databankPanel'));
    
    // AI Assistant
    document.getElementById('sendAI').addEventListener('click', sendAIMessage);
    document.getElementById('aiPrompt').addEventListener('keypress', (e) => {
        if (e.key === 'Enter' && e.ctrlKey) {
            sendAIMessage();
        }
    });
    
    // Notebook
    document.getElementById('addCell').addEventListener('click', addNotebookCell);
    
    // Databank
    document.getElementById('saveDatabank').addEventListener('click', saveToDatabank);
    document.getElementById('loadDatabank').addEventListener('click', loadDatabank);
    
    // Data sheets
    document.getElementById('newDataSheet').addEventListener('click', () => {
        openDataSheetModal();
    });
    document.getElementById('saveSheet').addEventListener('click', saveDataSheet);
    document.getElementById('aiAssistSheet').addEventListener('click', aiAssistDataSheet);
}

// Update live preview
function updateLivePreview() {
    const preview = document.getElementById('preview');
    const code = editor.getValue();
    
    // Create a blob URL for the content
    const blob = new Blob([code], { type: 'text/html' });
    const url = URL.createObjectURL(blob);
    
    preview.src = url;
}

// File Operations
function newFile() {
    const filename = prompt('Enter filename:', 'untitled.html');
    if (filename) {
        currentFile = filename;
        editor.setValue('');
        showNotification('New file created: ' + filename);
    }
}

async function saveFile() {
    const content = editor.getValue();
    
    try {
        const response = await fetch('/api/write', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ filename: currentFile, content })
        });
        
        const data = await response.json();
        if (data.success) {
            showNotification('File saved: ' + currentFile);
            loadFileList();
        }
    } catch (error) {
        showNotification('Error saving file: ' + error.message, 'error');
    }
}

async function uploadFile(event) {
    const file = event.target.files[0];
    if (!file) return;
    
    const formData = new FormData();
    formData.append('file', file);
    
    try {
        const response = await fetch('/api/upload', {
            method: 'POST',
            body: formData
        });
        
        const data = await response.json();
        if (data.success) {
            showNotification('File uploaded: ' + data.originalName);
            loadFileList();
            
            // Read the file content
            const readResponse = await fetch(`/api/read/${data.filename}`);
            const readData = await readResponse.json();
            if (readData.success) {
                editor.setValue(readData.content);
                currentFile = data.originalName;
            }
        }
    } catch (error) {
        showNotification('Error uploading file: ' + error.message, 'error');
    }
}

function downloadFile() {
    const content = editor.getValue();
    const blob = new Blob([content], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = currentFile;
    a.click();
    URL.revokeObjectURL(url);
    showNotification('File downloaded: ' + currentFile);
}

async function loadFileList() {
    try {
        const response = await fetch('/api/files');
        const data = await response.json();
        
        const fileList = document.getElementById('fileList');
        fileList.innerHTML = '';
        
        data.files.forEach(filename => {
            const fileItem = document.createElement('div');
            fileItem.className = 'file-item';
            fileItem.textContent = filename;
            fileItem.onclick = () => loadFile(filename);
            fileList.appendChild(fileItem);
        });
    } catch (error) {
        console.error('Error loading file list:', error);
    }
}

async function loadFile(filename) {
    try {
        const response = await fetch(`/api/read/${filename}`);
        const data = await response.json();
        
        if (data.success) {
            editor.setValue(data.content);
            currentFile = filename;
            showNotification('Loaded: ' + filename);
        }
    } catch (error) {
        showNotification('Error loading file: ' + error.message, 'error');
    }
}

// Panel Management
function togglePanel(panelId) {
    const panel = document.getElementById(panelId);
    panel.classList.toggle('hidden');
}

function closePanel(panelId) {
    document.getElementById(panelId).classList.add('hidden');
}

function closeModal(modalId) {
    document.getElementById(modalId).classList.add('hidden');
}

// API Key Management
function loadApiKeys() {
    apiKeys = JSON.parse(localStorage.getItem('apiKeys') || '{}');
    updateApiKeyStatus();
}

function saveApiKey(service) {
    const keyInput = document.getElementById(service + 'Key');
    const key = keyInput.value.trim();
    
    if (key) {
        apiKeys[service] = key;
        localStorage.setItem('apiKeys', JSON.stringify(apiKeys));
        showNotification(`${service} API key saved`);
        updateApiKeyStatus();
    }
}

function updateApiKeyStatus() {
    const statusDiv = document.getElementById('apiKeyStatus');
    statusDiv.innerHTML = '';
    
    Object.keys(apiKeys).forEach(service => {
        const item = document.createElement('div');
        item.className = 'api-key-status-item';
        item.innerHTML = `
            <span>${service}</span>
            <span class="status-indicator"></span>
        `;
        statusDiv.appendChild(item);
    });
}

// AI Assistant
async function sendAIMessage() {
    const promptInput = document.getElementById('aiPrompt');
    const prompt = promptInput.value.trim();
    
    if (!prompt) return;
    
    const service = document.getElementById('aiService').value;
    const model = document.getElementById('aiModel').value;
    
    if (!apiKeys[service]) {
        showNotification('Please set API key for ' + service, 'error');
        return;
    }
    
    // Add user message
    addAIMessage('user', prompt);
    promptInput.value = '';
    
    // Show loading
    const loadingId = addAIMessage('assistant', 'Thinking...');
    
    try {
        const response = await fetch('/api/gateway', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                service,
                apiKey: apiKeys[service],
                prompt,
                model: model || undefined
            })
        });
        
        const data = await response.json();
        
        // Remove loading message
        document.getElementById(loadingId).remove();
        
        if (data.success) {
            addAIMessage('assistant', data.response);
        } else {
            addAIMessage('assistant', 'Error: ' + data.error);
        }
    } catch (error) {
        document.getElementById(loadingId).remove();
        addAIMessage('assistant', 'Error: ' + error.message);
    }
}

function addAIMessage(role, content) {
    const messagesDiv = document.getElementById('aiMessages');
    const messageDiv = document.createElement('div');
    const messageId = 'msg-' + Date.now();
    
    messageDiv.id = messageId;
    messageDiv.className = `ai-message ${role}`;
    messageDiv.innerHTML = `
        <div class="ai-message-label">${role === 'user' ? 'You' : 'AI'}</div>
        <div>${content}</div>
    `;
    
    messagesDiv.appendChild(messageDiv);
    messagesDiv.scrollTop = messagesDiv.scrollHeight;
    
    return messageId;
}

// Notebook
function addNotebookCell() {
    const cellsDiv = document.getElementById('notebookCells');
    const cellId = 'cell-' + Date.now();
    
    const cellDiv = document.createElement('div');
    cellDiv.className = 'notebook-cell';
    cellDiv.id = cellId;
    cellDiv.innerHTML = `
        <div class="cell-header">
            <select class="cell-type-selector" onchange="changeCellType('${cellId}', this.value)">
                <option value="code">Code</option>
                <option value="markdown">Markdown</option>
            </select>
            <div class="cell-controls">
                <button class="btn-small" onclick="runCell('${cellId}')">▶ Run</button>
                <button class="btn-small" onclick="deleteCell('${cellId}')">🗑️</button>
            </div>
        </div>
        <div class="cell-editor" id="${cellId}-editor"></div>
        <div class="cell-output" id="${cellId}-output"></div>
    `;
    
    cellsDiv.appendChild(cellDiv);
    
    // Initialize CodeMirror for this cell
    const cellEditor = CodeMirror(document.getElementById(`${cellId}-editor`), {
        mode: 'javascript',
        theme: 'monokai',
        lineNumbers: true,
        lineWrapping: true
    });
    
    notebookCells.push({ id: cellId, editor: cellEditor, type: 'code' });
}

function changeCellType(cellId, type) {
    const cell = notebookCells.find(c => c.id === cellId);
    if (cell) {
        cell.type = type;
        cell.editor.setOption('mode', type === 'code' ? 'javascript' : 'markdown');
    }
}

function runCell(cellId) {
    const cell = notebookCells.find(c => c.id === cellId);
    if (!cell) return;
    
    const code = cell.editor.getValue();
    const outputDiv = document.getElementById(`${cellId}-output`);
    
    if (cell.type === 'code') {
        try {
            // Capture console.log
            const logs = [];
            const originalLog = console.log;
            console.log = (...args) => {
                logs.push(args.join(' '));
                originalLog(...args);
            };
            
            const result = eval(code);
            console.log = originalLog;
            
            outputDiv.textContent = logs.join('\n') + (result !== undefined ? '\n=> ' + result : '');
        } catch (error) {
            outputDiv.textContent = 'Error: ' + error.message;
        }
    } else {
        // Simple markdown rendering (basic)
        outputDiv.innerHTML = code.replace(/\n/g, '<br>');
    }
}

function deleteCell(cellId) {
    const index = notebookCells.findIndex(c => c.id === cellId);
    if (index !== -1) {
        notebookCells.splice(index, 1);
        document.getElementById(cellId).remove();
    }
}

// Databank
async function saveToDatabank() {
    const key = document.getElementById('databankKey').value.trim();
    const value = document.getElementById('databankValue').value.trim();
    
    if (!key) {
        showNotification('Please enter a key', 'error');
        return;
    }
    
    try {
        const response = await fetch('/api/databank', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ key, value })
        });
        
        const data = await response.json();
        if (data.success) {
            showNotification('Saved to databank: ' + key);
            document.getElementById('databankKey').value = '';
            document.getElementById('databankValue').value = '';
            loadDatabank();
        }
    } catch (error) {
        showNotification('Error saving to databank: ' + error.message, 'error');
    }
}

async function loadDatabank() {
    try {
        const response = await fetch('/api/databank');
        const result = await response.json();
        
        if (result.success) {
            const entriesDiv = document.getElementById('databankEntries');
            entriesDiv.innerHTML = '';
            
            Object.entries(result.data).forEach(([key, value]) => {
                const entryDiv = document.createElement('div');
                entryDiv.className = 'databank-entry';
                entryDiv.innerHTML = `
                    <div class="databank-entry-key">${key}</div>
                    <div class="databank-entry-value">${JSON.stringify(value, null, 2)}</div>
                `;
                entriesDiv.appendChild(entryDiv);
            });
        }
    } catch (error) {
        showNotification('Error loading databank: ' + error.message, 'error');
    }
}

// Data Sheets
function openDataSheetModal() {
    const modal = document.getElementById('dataSheetModal');
    modal.classList.remove('hidden');
    
    if (!sheetEditor) {
        sheetEditor = CodeMirror(document.getElementById('sheetEditor'), {
            mode: 'javascript',
            theme: 'monokai',
            lineNumbers: true,
            lineWrapping: true
        });
        sheetEditor.setValue('[]');
    }
}

async function saveDataSheet() {
    const id = document.getElementById('sheetId').value.trim();
    const data = sheetEditor.getValue();
    
    if (!id) {
        showNotification('Please enter sheet ID', 'error');
        return;
    }
    
    try {
        const response = await fetch('/api/datasheet', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id, data: JSON.parse(data) })
        });
        
        const result = await response.json();
        if (result.success) {
            showNotification('Data sheet saved: ' + id);
            closeModal('dataSheetModal');
            loadDataSheets();
        }
    } catch (error) {
        showNotification('Error saving data sheet: ' + error.message, 'error');
    }
}

async function aiAssistDataSheet() {
    const service = 'gemini'; // Default to Gemini for data operations
    
    if (!apiKeys[service]) {
        showNotification('Please set Gemini API key first', 'error');
        return;
    }
    
    const currentData = sheetEditor.getValue();
    const prompt = `Help me structure this data properly as JSON. Current data: ${currentData}. 
    Please provide a well-structured JSON array with proper formatting.`;
    
    try {
        const response = await fetch('/api/gateway', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                service,
                apiKey: apiKeys[service],
                prompt
            })
        });
        
        const data = await response.json();
        if (data.success) {
            // Try to extract JSON from response
            const jsonMatch = data.response.match(/```json\n([\s\S]*?)\n```/) || 
                            data.response.match(/\[[\s\S]*\]/);
            if (jsonMatch) {
                sheetEditor.setValue(jsonMatch[1] || jsonMatch[0]);
                showNotification('AI assisted data formatting applied');
            } else {
                showNotification('AI response: ' + data.response);
            }
        }
    } catch (error) {
        showNotification('Error with AI assist: ' + error.message, 'error');
    }
}

async function loadDataSheets() {
    // This would load saved sheets list
    // For now, it's a placeholder
}

// Utility Functions
function showNotification(message, type = 'success') {
    const notification = document.createElement('div');
    notification.style.cssText = `
        position: fixed;
        top: 80px;
        right: 20px;
        background: ${type === 'error' ? '#f44336' : '#4caf50'};
        color: white;
        padding: 15px 20px;
        border-radius: 5px;
        box-shadow: 0 4px 8px rgba(0,0,0,0.2);
        z-index: 10000;
        animation: slideIn 0.3s ease-out;
    `;
    notification.textContent = message;
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease-out';
        setTimeout(() => notification.remove(), 300);
    }, 3000);
}

function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Add CSS animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from { transform: translateX(400px); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }
    @keyframes slideOut {
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(400px); opacity: 0; }
    }
`;
document.head.appendChild(style);
