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
    const previewDocument = previewFrame.contentDocument || previewFrame.contentWindow.document;
    
    previewDocument.open();
    previewDocument.write(code);
    previewDocument.close();
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
