const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const multer = require('multer');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '50mb' }));
app.use(express.static('public'));

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, 'uploads');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true, mode: 0o755 });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    // Sanitize filename to prevent path traversal
    const sanitized = path.basename(file.originalname);
    cb(null, Date.now() + '-' + sanitized);
  }
});

const upload = multer({ storage });

// API Routes

// File upload endpoint
app.post('/api/upload', upload.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }
  res.json({ 
    success: true, 
    filename: req.file.filename,
    path: req.file.path,
    originalName: req.file.originalname
  });
});

// File download endpoint
app.get('/api/download/:filename', (req, res) => {
  // Sanitize filename to prevent path traversal
  const sanitizedFilename = path.basename(req.params.filename);
  const filePath = path.join(__dirname, 'uploads', sanitizedFilename);
  
  // Verify the resolved path is within uploads directory
  const uploadDir = path.join(__dirname, 'uploads');
  if (!filePath.startsWith(uploadDir)) {
    return res.status(403).json({ error: 'Access denied' });
  }
  
  if (fs.existsSync(filePath)) {
    res.download(filePath);
  } else {
    res.status(404).json({ error: 'File not found' });
  }
});

// Read file endpoint
app.get('/api/read/:filename', (req, res) => {
  // Sanitize filename to prevent path traversal
  const sanitizedFilename = path.basename(req.params.filename);
  const filePath = path.join(__dirname, 'uploads', sanitizedFilename);
  
  // Verify the resolved path is within uploads directory
  const uploadDir = path.join(__dirname, 'uploads');
  if (!filePath.startsWith(uploadDir)) {
    return res.status(403).json({ error: 'Access denied' });
  }
  
  if (fs.existsSync(filePath)) {
    const content = fs.readFileSync(filePath, 'utf8');
    res.json({ success: true, content });
  } else {
    res.status(404).json({ error: 'File not found' });
  }
});

// Write file endpoint
app.post('/api/write', (req, res) => {
  const { filename, content } = req.body;
  if (!filename || content === undefined) {
    return res.status(400).json({ error: 'Filename and content required' });
  }
  
  // Sanitize filename to prevent path traversal
  const sanitizedFilename = path.basename(filename);
  const filePath = path.join(__dirname, 'uploads', sanitizedFilename);
  
  // Verify the resolved path is within uploads directory
  const uploadDir = path.join(__dirname, 'uploads');
  if (!filePath.startsWith(uploadDir)) {
    return res.status(403).json({ error: 'Access denied' });
  }
  
  // Create uploads directory if it doesn't exist
  if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true, mode: 0o755 });
  }
  
  fs.writeFileSync(filePath, content, 'utf8');
  res.json({ success: true, filename: sanitizedFilename });
});

// List files endpoint
app.get('/api/files', (req, res) => {
  const uploadDir = path.join(__dirname, 'uploads');
  if (!fs.existsSync(uploadDir)) {
    return res.json({ files: [] });
  }
  const files = fs.readdirSync(uploadDir);
  res.json({ files });
});

// API Gateway endpoint for AI services
app.post('/api/gateway', async (req, res) => {
  const { service, apiKey, prompt, model } = req.body;
  
  try {
    let response;
    
    switch(service) {
      case 'deepseek':
        response = await callDeepSeek(apiKey, prompt, model);
        break;
      case 'gemini':
        response = await callGemini(apiKey, prompt, model);
        break;
      case 'copilot':
        response = await callCopilot(apiKey, prompt, model);
        break;
      default:
        return res.status(400).json({ error: 'Invalid service' });
    }
    
    res.json({ success: true, response });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// AI Service Implementations
async function callDeepSeek(apiKey, prompt, model = 'deepseek-chat') {
  const fetch = (await import('node-fetch')).default;
  const response = await fetch('https://api.deepseek.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`
    },
    body: JSON.stringify({
      model,
      messages: [{ role: 'user', content: prompt }]
    })
  });
  
  if (!response.ok) {
    throw new Error(`DeepSeek API error: ${response.statusText}`);
  }
  
  const data = await response.json();
  return data.choices[0].message.content;
}

async function callGemini(apiKey, prompt, model = 'gemini-pro') {
  const fetch = (await import('node-fetch')).default;
  const response = await fetch(`https://generativelanguage.googleapis.com/v1/models/${model}:generateContent?key=${apiKey}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      contents: [{
        parts: [{ text: prompt }]
      }]
    })
  });
  
  if (!response.ok) {
    throw new Error(`Gemini API error: ${response.statusText}`);
  }
  
  const data = await response.json();
  return data.candidates[0].content.parts[0].text;
}

async function callCopilot(apiKey, prompt, model = 'gpt-4') {
  // GitHub Copilot uses OpenAI API
  const fetch = (await import('node-fetch')).default;
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`
    },
    body: JSON.stringify({
      model,
      messages: [{ role: 'user', content: prompt }]
    })
  });
  
  if (!response.ok) {
    throw new Error(`OpenAI API error: ${response.statusText}`);
  }
  
  const data = await response.json();
  return data.choices[0].message.content;
}

// Data store for dynamic data sheets and databanks
let dataSheets = {};
let dataBank = {};

// Data sheet endpoints
app.get('/api/datasheet/:id', (req, res) => {
  const sheet = dataSheets[req.params.id];
  if (sheet) {
    res.json({ success: true, data: sheet });
  } else {
    res.status(404).json({ error: 'Data sheet not found' });
  }
});

app.post('/api/datasheet', (req, res) => {
  const { id, data } = req.body;
  dataSheets[id] = data;
  res.json({ success: true, id });
});

app.put('/api/datasheet/:id', (req, res) => {
  const { data } = req.body;
  dataSheets[req.params.id] = data;
  res.json({ success: true, id: req.params.id });
});

// Databank endpoints
app.get('/api/databank/:key', (req, res) => {
  const value = dataBank[req.params.key];
  if (value !== undefined) {
    res.json({ success: true, value });
  } else {
    res.status(404).json({ error: 'Key not found' });
  }
});

app.post('/api/databank', (req, res) => {
  const { key, value } = req.body;
  dataBank[key] = value;
  res.json({ success: true, key });
});

app.get('/api/databank', (req, res) => {
  res.json({ success: true, data: dataBank });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
