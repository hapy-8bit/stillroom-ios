#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const files = [];
const skip = new Set(['.git', 'Build', '.build', 'Stillroom.xcodeproj']);
function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory() && !skip.has(entry.name)) walk(file);
    else if (entry.isFile() && /\.(swift|cjs|rb)$/.test(entry.name)) {
      const source = fs.readFileSync(file, 'utf8');
      const lines = source ? source.split(/\r\n|\n|\r/).length - Number(/[\r\n]$/.test(source)) : 0;
      files.push({ file: path.relative(root, file), lines });
    }
  }
}
walk(root);
files.sort((a, b) => b.lines - a.lines);
for (const file of files) console.log(`${file.lines > 800 ? 'FAIL' : file.lines > 600 ? 'REVIEW' : 'OK'} ${file.lines} ${file.file}`);
if (!files.length || files.some(file => file.lines > 800)) process.exitCode = 1;
console.log(`${files.length} maintained code files; maximum ${files[0]?.lines ?? 0} lines`);

