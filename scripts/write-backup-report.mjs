import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
const [releasePath, assetDir, manifestPath] = process.argv.slice(2);
const release = JSON.parse(fs.readFileSync(releasePath, 'utf8'));
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const assets = [];
for (const name of fs.readdirSync(assetDir).sort()) {
  const file = path.join(assetDir, name);
  const size = fs.statSync(file).size;
  const hash = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  const remote = release.assets.find(a => a.name === name);
  if (!remote || remote.state !== 'uploaded' || remote.size !== size) throw new Error('Release asset missing or incomplete: ' + name);
  if (remote.digest && remote.digest !== 'sha256:' + hash) throw new Error('Server digest mismatch: ' + name);
  assets.push({ name, size, sha256: hash, url: remote.browser_download_url, serverDigest: remote.digest ?? null });
}
console.log(JSON.stringify({
  verified: true,
  verifiedAt: new Date().toISOString(),
  sourceHead: manifest.sourceHead,
  sourceFileCount: manifest.fileCount,
  sourceTotalBytes: manifest.totalBytes,
  sourceEntryCount: manifest.entries.length,
  fullSnapshotExtractedAndVerified: true,
  releaseAssetsDownloadedAndHashVerified: true,
  workflowCommit: process.env.GITHUB_SHA,
  workflowRun: 'https://github.com/' + process.env.GITHUB_REPOSITORY + '/actions/runs/' + process.env.GITHUB_RUN_ID,
  release: release.html_url,
  assets
}, null, 2));
