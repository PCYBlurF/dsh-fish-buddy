#!/usr/bin/env node
/**
 * 把 version.json 的版本同步到 Windows 挂件和 macOS package。
 * 不修改 git、不创建 release。
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const version = JSON.parse(fs.readFileSync(path.join(ROOT, 'version.json'), 'utf8')).version;
if (!/^\d+\.\d+\.\d+$/.test(version)) {
  console.error(`invalid version: ${version}`);
  process.exit(1);
}

const psPath = path.join(ROOT, 'bin', 'fish-widget.ps1');
let ps = fs.readFileSync(psPath, 'utf8');
const hadBom = ps.charCodeAt(0) === 0xfeff;
if (hadBom) ps = ps.slice(1);
if (!/\$script:Version = '[^']+'/.test(ps)) {
  console.error('cannot find $script:Version in fish-widget.ps1');
  process.exit(1);
}
ps = ps.replace(/(\$script:Version = ')[^']+(')/, `$1${version}$2`);
fs.writeFileSync(psPath, (hadBom ? '\uFEFF' : '') + ps, 'utf8');

const macPath = path.join(ROOT, 'mac', 'package.json');
const mac = JSON.parse(fs.readFileSync(macPath, 'utf8'));
mac.version = version;
fs.writeFileSync(macPath, JSON.stringify(mac, null, 2) + '\n', 'utf8');

console.log(`synced version ${version} (CHANGELOG.md / docs/releases 需手动更新)`);
