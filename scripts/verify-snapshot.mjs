import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
const [manifestPath, directory] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const root = path.resolve(directory);
const seen = [];
function walk(dir, prefix = '') {
  for (const name of fs.readdirSync(dir).sort()) {
    const rel = prefix ? prefix + '/' + name : name;
    const full = path.join(dir, name);
    seen.push(rel);
    if (fs.lstatSync(full).isDirectory()) walk(full, rel);
  }
}
walk(root);
const expected = manifest.entries.map(e => e.path).sort();
if (JSON.stringify(seen.sort()) !== JSON.stringify(expected)) throw new Error('Restored file list differs from manifest');
for (const e of manifest.entries) {
  const full = path.resolve(root, e.path);
  if (!full.startsWith(root + path.sep)) throw new Error('Unsafe manifest path');
  const st = fs.lstatSync(full);
  if ((st.mode & 0o7777) !== e.mode) throw new Error('Mode mismatch: ' + e.path);
  if (e.type === 'file') {
    const hash = crypto.createHash('sha256').update(fs.readFileSync(full)).digest('hex');
    if (!st.isFile() || st.size !== e.size || hash !== e.sha256) throw new Error('File mismatch: ' + e.path);
  } else if (e.type === 'directory') {
    if (!st.isDirectory()) throw new Error('Directory mismatch: ' + e.path);
  } else if (e.type === 'symlink') {
    if (!st.isSymbolicLink() || fs.readlinkSync(full) !== e.target) throw new Error('Symlink mismatch: ' + e.path);
  } else throw new Error('Unsupported manifest type');
}
console.log('Verified ' + manifest.fileCount + ' files, ' + manifest.totalBytes + ' bytes, including original .git and ignored outputs.');
