const fs = require('fs');
const path = require('path');

// Copy CodeMirror files to public directory
const source = path.join(__dirname, 'node_modules', 'codemirror');
const dest = path.join(__dirname, 'public', 'codemirror');

if (fs.existsSync(source) && !fs.existsSync(dest)) {
  console.log('Copying CodeMirror files to public directory...');
  
  // Create destination directory
  fs.mkdirSync(dest, { recursive: true });
  
  // Copy recursively
  function copyRecursiveSync(src, dest) {
    const exists = fs.existsSync(src);
    const stats = exists && fs.statSync(src);
    const isDirectory = exists && stats.isDirectory();
    
    if (isDirectory) {
      if (!fs.existsSync(dest)) {
        fs.mkdirSync(dest);
      }
      fs.readdirSync(src).forEach(childItemName => {
        copyRecursiveSync(
          path.join(src, childItemName),
          path.join(dest, childItemName)
        );
      });
    } else {
      fs.copyFileSync(src, dest);
    }
  }
  
  copyRecursiveSync(source, dest);
  console.log('CodeMirror files copied successfully!');
} else if (fs.existsSync(dest)) {
  console.log('CodeMirror files already exist in public directory.');
} else {
  console.log('Warning: CodeMirror not found in node_modules. Please run npm install first.');
}
