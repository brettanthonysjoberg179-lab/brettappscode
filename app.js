// Initialize CodeMirror editor
const editor = CodeMirror.fromTextArea(document.getElementById('code-editor'), {
    mode: 'htmlmixed',
    theme: 'monokai',
    lineNumbers: true,
    autoCloseBrackets: true,
    autoCloseTags: true,
    matchBrackets: true,
    indentUnit: 4,
    tabSize: 4,
    lineWrapping: true
});

// Get preview iframe
const previewFrame = document.getElementById('preview-frame');
const refreshBtn = document.getElementById('refresh-btn');

// Function to update preview
function updatePreview() {
    const code = editor.getValue();
    
    // Revoke the previous blob URL to prevent memory leaks
    if (previewFrame.src && previewFrame.src.startsWith('blob:')) {
        URL.revokeObjectURL(previewFrame.src);
    }
    
    const blob = new Blob([code], { type: 'text/html' });
    const blobURL = URL.createObjectURL(blob);
    previewFrame.src = blobURL;
}

// Update preview on code change with debounce
let debounceTimer;
editor.on('change', () => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
        updatePreview();
    }, 500); // 500ms delay
});

// Manual refresh button
refreshBtn.addEventListener('click', () => {
    updatePreview();
});

// Initial preview load
updatePreview();
