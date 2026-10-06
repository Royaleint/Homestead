#!/usr/bin/env node
// Usage: node check-release-budget.mjs [releaseDir] [baselinePath] [--report-only]
// Defaults: .release and .github/release-budget.json. Report mode never writes a baseline.
// Reads standard single-disk ZIP metadata; ZIP64 and unsupported records fail closed.

import { lstatSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";

const metrics = ["compressedBytes", "uncompressedBytes", "fileCount"];

function requireValid(condition, message) {
  if (!condition) throw new Error(message);
}

function exactKeys(value, keys, label) {
  requireValid(value !== null && typeof value === "object" && !Array.isArray(value)
    && Object.keys(value).length === keys.length && keys.every((key) => Object.hasOwn(value, key)),
  `Invalid baseline ${label}: expected exactly ${keys.join(", ")}`);
}

function loadBaseline(filename) {
  let value, source;
  try {
    source = readFileSync(filename, "utf8");
    value = JSON.parse(source);
  } catch (error) {
    throw new Error(`Cannot read baseline '${filename}': ${error.message}`);
  }
  exactKeys(value, ["schemaVersion", "sourceRelease", "maximums"], "fields");
  requireValid(value.schemaVersion === 1, "Invalid baseline schemaVersion: expected 1");
  requireValid(typeof value.sourceRelease === "string" && value.sourceRelease.trim().length > 0,
    "Invalid baseline sourceRelease: expected a nonempty string");
  exactKeys(value.maximums, metrics, "maximums");
  for (const metric of metrics) {
    requireValid(Number.isSafeInteger(value.maximums[metric]) && value.maximums[metric] > 0,
      `Invalid baseline ${metric}: expected a positive safe integer`);
  }
  // All property names in the v1 schema are unique, including maximums fields.
  // Tokenize complete JSON strings so escaped quotes inside values are skipped.
  const names = new Set();
  for (const token of source.matchAll(/"(?:[^"\\]|\\.)*"/g)) {
    if (!/^\s*:/.test(source.slice(token.index + token[0].length))) continue;
    const name = JSON.parse(token[0]);
    requireValid(!names.has(name), `Invalid baseline: duplicate field '${name}'`);
    names.add(name);
  }
  return value;
}

function measureZip(buffer) {
  function bounds(start, length, limit = buffer.length) {
    requireValid(Number.isSafeInteger(start) && Number.isSafeInteger(length)
      && start >= 0 && length >= 0 && start + length <= limit,
    "Malformed ZIP: record extends outside its bounds");
  }
  function extraFields(start, length) {
    const end = start + length;
    bounds(start, length);
    while (start < end) {
      bounds(start, 4, end);
      const id = buffer.readUInt16LE(start), size = buffer.readUInt16LE(start + 2);
      requireValid(id !== 1, "Unsupported ZIP64 extra field");
      bounds(start + 4, size, end);
      start += 4 + size;
    }
  }

  // EOCD can be followed only by its declared comment (at most 65535 bytes).
  const endings = [];
  for (let at = buffer.length - 22; at >= Math.max(0, buffer.length - 22 - 65535); at--) {
    if (buffer.readUInt32LE(at) === 0x06054b50
      && at + 22 + buffer.readUInt16LE(at + 20) === buffer.length) endings.push(at);
  }
  requireValid(endings.length === 1, "Malformed or ambiguous ZIP end-of-central-directory record");
  const end = endings[0];
  const countOnDisk = buffer.readUInt16LE(end + 8), count = buffer.readUInt16LE(end + 10);
  const directorySize = buffer.readUInt32LE(end + 12), directoryStart = buffer.readUInt32LE(end + 16);
  requireValid(count !== 0xffff && countOnDisk !== 0xffff && directorySize !== 0xffffffff
    && directoryStart !== 0xffffffff, "Unsupported ZIP64 end record");
  requireValid(buffer.readUInt16LE(end + 4) === 0 && buffer.readUInt16LE(end + 6) === 0
    && countOnDisk === count, "Unsupported multi-disk or mismatching ZIP entry counts");
  requireValid(count > 0 && directoryStart + directorySize === end,
    "Malformed ZIP central directory bounds or empty archive");
  bounds(directoryStart, directorySize, end);

  let cursor = directoryStart, uncompressedBytes = 0, fileCount = 0;
  const names = new Set(), ranges = [];
  for (let index = 0; index < count; index++) {
    bounds(cursor, 46, end);
    requireValid(buffer.readUInt32LE(cursor) === 0x02014b50, "Malformed ZIP central directory signature");
    const version = buffer.readUInt16LE(cursor + 6), flags = buffer.readUInt16LE(cursor + 8);
    const method = buffer.readUInt16LE(cursor + 10), crc = buffer.readUInt32LE(cursor + 16);
    const compressed = buffer.readUInt32LE(cursor + 20), uncompressed = buffer.readUInt32LE(cursor + 24);
    const nameSize = buffer.readUInt16LE(cursor + 28), extraSize = buffer.readUInt16LE(cursor + 30);
    const commentSize = buffer.readUInt16LE(cursor + 32), disk = buffer.readUInt16LE(cursor + 34);
    const local = buffer.readUInt32LE(cursor + 42);
    requireValid(compressed !== 0xffffffff && uncompressed !== 0xffffffff && local !== 0xffffffff
      && disk !== 0xffff, "Unsupported ZIP64 entry");
    requireValid(version >= 10 && version <= 20 && disk === 0 && (method === 0 || method === 8)
      && (flags & ~0x080e) === 0 && (method === 8 || (flags & 6) === 0),
    "Unsupported ZIP version, disk, compression method, or flags");
    bounds(cursor + 46, nameSize + extraSize + commentSize, end);
    const name = buffer.subarray(cursor + 46, cursor + 46 + nameSize);
    const nameKey = name.toString("hex");
    requireValid(nameSize > 0 && !name.includes(0) && !names.has(nameKey),
      "Malformed ZIP: empty, NUL-containing, or duplicate entry name");
    names.add(nameKey);
    extraFields(cursor + 46 + nameSize, extraSize);

    bounds(local, 30, directoryStart);
    requireValid(buffer.readUInt32LE(local) === 0x04034b50, "Malformed ZIP local header signature");
    requireValid(buffer.readUInt16LE(local + 4) === version && buffer.readUInt16LE(local + 6) === flags
      && buffer.readUInt16LE(local + 8) === method, "Mismatching ZIP local header metadata");
    const localNameSize = buffer.readUInt16LE(local + 26), localExtraSize = buffer.readUInt16LE(local + 28);
    bounds(local + 30, localNameSize + localExtraSize, directoryStart);
    requireValid(localNameSize === nameSize && name.equals(buffer.subarray(local + 30, local + 30 + localNameSize)),
      "Mismatching ZIP local entry name");
    extraFields(local + 30 + localNameSize, localExtraSize);
    const descriptor = (flags & 8) !== 0;
    for (const [position, expected] of [[14, crc], [18, compressed], [22, uncompressed]]) {
      const actual = buffer.readUInt32LE(local + position);
      requireValid(actual === expected || (descriptor && actual === 0), "Mismatching ZIP local CRC or sizes");
    }
    requireValid(method !== 0 || compressed === uncompressed, "Malformed ZIP stored-entry sizes");
    const dataStart = local + 30 + localNameSize + localExtraSize;
    bounds(dataStart, compressed, directoryStart);
    let dataEnd = dataStart + compressed;
    if (descriptor) {
      // Both signed and unsigned descriptors are valid. Require exactly one match.
      const matches = [];
      for (const signed of [false, true]) {
        const start = dataEnd + (signed ? 4 : 0), stop = start + 12;
        if (stop > directoryStart || (signed && buffer.readUInt32LE(dataEnd) !== 0x08074b50)) continue;
        if (buffer.readUInt32LE(start) === crc && buffer.readUInt32LE(start + 4) === compressed
          && buffer.readUInt32LE(start + 8) === uncompressed) matches.push(stop);
      }
      requireValid(matches.length === 1, "Malformed or ambiguous ZIP data descriptor");
      dataEnd = matches[0];
    }
    ranges.push([local, dataEnd]);
    const directory = name[name.length - 1] === 0x2f;
    requireValid(!directory || (uncompressed === 0 && compressed === 0), "Malformed ZIP directory payload");
    if (!directory) {
      fileCount++;
      uncompressedBytes += uncompressed;
      requireValid(Number.isSafeInteger(uncompressedBytes), "Unsafe ZIP uncompressed byte total");
    }
    cursor += 46 + nameSize + extraSize + commentSize;
  }
  requireValid(cursor === end, "Malformed ZIP: central directory count or size mismatch");
  ranges.sort((a, b) => a[0] - b[0]);
  let next = 0;
  for (const [start, stop] of ranges) {
    requireValid(start === next, "Malformed ZIP: overlapping entries or unsupported records between entries");
    next = stop;
  }
  requireValid(next === directoryStart && fileCount > 0, "Malformed ZIP: unlisted records or no files");
  return { compressedBytes: buffer.length, uncompressedBytes, fileCount };
}

try {
  const positional = [];
  let reportOnly = false;
  for (const argument of process.argv.slice(2)) {
    if (argument === "--report-only" && !reportOnly) reportOnly = true;
    else {
      requireValid(!argument.startsWith("--"), `Unknown or repeated option '${argument}'`);
      positional.push(argument);
    }
  }
  requireValid(positional.length <= 2, "Usage: check-release-budget.mjs [releaseDir] [baselinePath] [--report-only]");
  const [releaseDir = ".release", baselinePath = ".github/release-budget.json"] = positional;
  const baseline = loadBaseline(baselinePath);
  const zips = readdirSync(releaseDir).filter((name) => name.toLowerCase().endsWith(".zip"));
  requireValid(zips.length === 1, `Expected exactly one ZIP in '${releaseDir}'; found ${zips.length}`);
  const zipPath = path.join(releaseDir, zips[0]), stat = lstatSync(zipPath);
  requireValid(stat.isFile() && Number.isSafeInteger(stat.size), "ZIP artifact must be a regular file with a safe byte size");
  const observed = measureZip(readFileSync(zipPath));
  console.log(`release-budget: ${zips[0]} (baseline ${baseline.sourceRelease})`);
  const exceeded = [];
  for (const metric of metrics) {
    console.log(`${metric}: ${observed[metric]} (maximum ${baseline.maximums[metric]})`);
    if (observed[metric] > baseline.maximums[metric]) exceeded.push(metric);
  }
  for (const metric of exceeded) {
    console.log(`EXCEEDED ${metric}: ${observed[metric]} > ${baseline.maximums[metric]} (+${observed[metric] - baseline.maximums[metric]})`);
  }
  if (reportOnly) console.log("release-budget: REPORT ONLY; baseline unchanged");
  else {
    requireValid(exceeded.length === 0, `${exceeded.length} package budget(s) exceeded`);
    console.log("release-budget: PASSED");
  }
} catch (error) {
  console.error(`release-budget: FAILED - ${error.message}`);
  process.exitCode = 1;
}
