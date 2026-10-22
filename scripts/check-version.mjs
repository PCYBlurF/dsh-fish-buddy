#!/usr/bin/env node
/**
 * 校验 version.json、Windows 挂件、macOS package 和 CHANGELOG 是否一致。
 * CI 使用；只读。
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const version = JSON.parse(fs.readFileSync(path.join(ROOT, 'version.json'), 'utf8')).version;

const ps = fs.readFileSync(path.join(ROOT, 'bin', 'fish-widget.ps1'), 'utf8');
const psMatch = ps.match(/\$script:Version = '([^']+)'/);
const mac = JSON.parse(fs.readFileSync(path.join(ROOT, 'mac', 'package.json'), 'utf8'));
const changelog = fs.readFileSync(path.join(ROOT, 'CHANGELOG.md'), 'utf8');

const errors = [];
if (!psMatch) errors.push('fish-widget.ps1: $script:Version not found');
else if (psMatch[1] !== version) errors.push(`fish-widget.ps1: ${psMatch[1]} != ${version}`);
if (mac.version !== version) errors.push(`mac/package.json: ${mac.version} != ${version}`);
const escapedVersion = version.split('.').join('\\.');
const changelogHeading = new RegExp('^##\\s+' + escapedVersion + '(?:\\s|$)', 'm');
if (!changelogHeading.test(changelog)) errors.push(`CHANGELOG.md: missing exact "## ${version}" heading`);

if (errors.length > 0) {
  for (const error of errors) console.error(`FAIL ${error}`);
  process.exit(1);
}
console.log(`version OK: ${version}`);
