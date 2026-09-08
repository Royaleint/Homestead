import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { deflateRawSync } from "node:zlib";
import test from "node:test";

const checker = fileURLToPath(new URL("../check-release-budget.mjs", import.meta.url));
const metricNames = ["compressedBytes", "uncompressedBytes", "fileCount"];

// Real, small ZIP fixtures without a packager or external dependencies.
function zip(entries = [{ name: "Homestead/test.lua", text: "hello" }], comment = "") {
  const locals = [], central = [];
  let offset = 0;
  for (const { name, text = "", deflate = false, descriptor = false, signed = true } of entries) {
    const filename = Buffer.from(name), data = Buffer.from(text);
    const payload = deflate ? deflateRawSync(data) : data;
    let crc = 0xffffffff;
    for (const byte of data) {
      crc ^= byte;
      for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
    }
    crc = (crc ^ 0xffffffff) >>> 0;
    const local = Buffer.alloc(30), header = Buffer.alloc(46);
    local.writeUInt32LE(0x04034b50);
    header.writeUInt32LE(0x02014b50);
    local.writeUInt16LE(20, 4);
    header.writeUInt16LE(20, 6);
    local.writeUInt16LE(descriptor ? 8 : 0, 6);
    header.writeUInt16LE(descriptor ? 8 : 0, 8);
    local.writeUInt16LE(deflate ? 8 : 0, 8);
    header.writeUInt16LE(deflate ? 8 : 0, 10);
    for (const [value, lp, cp] of [[crc, 14, 16], [payload.length, 18, 20], [data.length, 22, 24]]) {
      if (!descriptor) local.writeUInt32LE(value, lp);
      header.writeUInt32LE(value, cp);
    }
    local.writeUInt16LE(filename.length, 26);
    header.writeUInt16LE(filename.length, 28);
    header.writeUInt32LE(offset, 42);
    const tail = Buffer.alloc(descriptor ? (signed ? 16 : 12) : 0);
    if (descriptor) {
      const start = signed ? 4 : 0;
      if (signed) tail.writeUInt32LE(0x08074b50);
      tail.writeUInt32LE(crc, start);
      tail.writeUInt32LE(payload.length, start + 4);
      tail.writeUInt32LE(data.length, start + 8);
    }
    const record = Buffer.concat([local, filename, payload, tail]);
    locals.push(record);
    central.push(header, filename);
    offset += record.length;
  }
  const directory = Buffer.concat(central), end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(directory.length, 12);
  end.writeUInt32LE(offset, 16);
  end.writeUInt16LE(Buffer.byteLength(comment), 20);
  return Buffer.concat([...locals, directory, end, Buffer.from(comment)]);
}

function baseline(maximums) {
  return { schemaVersion: 1, sourceRelease: "v2.10.1", maximums };
}

function fixture(t, artifact = zip()) {
  const root = mkdtempSync(path.join(tmpdir(), "release-budget-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const release = path.join(root, ".release"), budget = path.join(root, ".github", "release-budget.json");
  mkdirSync(release);
  mkdirSync(path.dirname(budget));
  writeFileSync(path.join(release, "Homestead.zip"), artifact);
  const maximums = { compressedBytes: artifact.length, uncompressedBytes: 5, fileCount: 1 };
  writeFileSync(budget, JSON.stringify(baseline(maximums)));
  return {
    root, release, budget, maximums,
    setBudget(value) { writeFileSync(budget, JSON.stringify(value)); },
    run(args = [release, budget]) {
      const result = spawnSync(process.execPath, [checker, ...args], { cwd: root, encoding: "utf8" });
      assert.ifError(result.error);
      return { status: result.status, output: result.stdout + result.stderr };
    },
  };
}

test("exact baseline passes and prints all metrics with default paths", (t) => {
  const f = fixture(t), result = f.run([]);
  assert.equal(result.status, 0, result.output);
  for (const metric of metricNames) assert.match(result.output, new RegExp(`${metric}: ${f.maximums[metric]}\\b`));
});
test("values below every maximum pass", (t) => {
  const f = fixture(t);
  f.setBudget(baseline(Object.fromEntries(metricNames.map((key) => [key, f.maximums[key] + 1]))));
  const result = f.run();
  assert.equal(result.status, 0, result.output);
});
for (const metric of metricNames) test(`${metric} exceeding its maximum by one fails`, (t) => {
  const f = metric === "fileCount" ? fixture(t, zip([{ name: "one.lua", text: "hello" }, { name: "two.lua" }])) : fixture(t);
  if (metric === "fileCount") f.maximums.fileCount = 2;
  f.setBudget(baseline({ ...f.maximums, [metric]: f.maximums[metric] - 1 }));
  const result = f.run();
  assert.equal(result.status, 1, result.output);
  assert.match(result.output, new RegExp(`EXCEEDED ${metric}.*\\+1\\b`));
});
test("reports every simultaneous excess", (t) => {
  const f = fixture(t, zip([{ name: "one.lua", text: "hello" }, { name: "two.lua" }]));
  f.maximums.fileCount = 2;
  f.setBudget(baseline(Object.fromEntries(metricNames.map((key) => [key, f.maximums[key] - 1]))));
  const result = f.run();
  assert.equal(result.status, 1, result.output);
  for (const metric of metricNames) assert.match(result.output, new RegExp(`EXCEEDED ${metric}`));
});
test("directories excluded; compressed size includes ZIP comment", (t) => {
  const f = fixture(t, zip([{ name: "Homestead/" }, { name: "Homestead/test.lua", text: "hello" }], "comment"));
  const result = f.run();
  assert.equal(result.status, 0, result.output);
  assert.match(result.output, /uncompressedBytes: 5\b/);
  assert.match(result.output, /fileCount: 1\b/);
});
for (const options of [{ deflate: true }, { deflate: true, descriptor: true }, { descriptor: true, signed: false }]) {
  test(`supports ZIP entry ${JSON.stringify(options)}`, (t) => {
    const f = fixture(t, zip([{ name: "test.lua", text: "hello", ...options }]));
    const result = f.run();
    assert.equal(result.status, 0, result.output);
  });
}
test("report-only reports excess without modifying baseline", (t) => {
  const f = fixture(t, zip([{ name: "one.lua", text: "hello" }, { name: "two.lua" }]));
  f.setBudget(baseline({ compressedBytes: 1, uncompressedBytes: 1, fileCount: 1 }));
  const before = readFileSync(f.budget), result = f.run([f.release, f.budget, "--report-only"]);
  assert.equal(result.status, 0, result.output);
  for (const metric of metricNames) assert.match(result.output, new RegExp(`EXCEEDED ${metric}`));
  assert.deepEqual(readFileSync(f.budget), before);
});
for (const state of ["missing directory", "zero ZIPs", "multiple ZIPs", "ZIP named directory", "missing baseline"]) {
  test(`rejects ${state}`, (t) => {
    const f = fixture(t);
    if (state === "missing directory") rmSync(f.release, { recursive: true });
    if (state === "zero ZIPs" || state === "ZIP named directory") rmSync(path.join(f.release, "Homestead.zip"));
    if (state === "ZIP named directory") mkdirSync(path.join(f.release, "Homestead.zip"));
    if (state === "multiple ZIPs") writeFileSync(path.join(f.release, "other.ZIP"), zip());
    if (state === "missing baseline") rmSync(f.budget);
    const result = f.run();
    assert.equal(result.status, 1, result.output);
    assert.match(result.output, /release-budget: FAILED/);
  });
}
const invalidBaselines = [null, [], {}, { schemaVersion: 2 }, { schemaVersion: "1" },
  { sourceRelease: "" }, { sourceRelease: 1 }, { maximums: null }, { maximums: [] },
  { unexpected: 1 }, { maximums: { compressedBytes: 1 } }];
for (const key of metricNames) for (const value of [-1, 1.5, "5", null, Number.MAX_SAFE_INTEGER + 1]) {
  invalidBaselines.push({ maximums: { compressedBytes: 999, uncompressedBytes: 999, fileCount: 9, [key]: value } });
}
for (const [index, override] of invalidBaselines.entries()) test(`invalid baseline ${index} fails in report-only mode`, (t) => {
  const f = fixture(t);
  f.setBudget(override === null || Array.isArray(override) || Object.keys(override).length === 0
    ? override : { ...baseline(f.maximums), ...override });
  const result = f.run([f.release, f.budget, "--report-only"]);
  assert.equal(result.status, 1, result.output);
  assert.match(result.output, /baseline/i);
});
test("invalid JSON fails", (t) => {
  const f = fixture(t);
  writeFileSync(f.budget, "{");
  assert.equal(f.run().status, 1);
});
const mutations = {
  "truncated EOCD": (b) => b.subarray(0, b.length - 1),
  "trailing garbage": (b) => Buffer.concat([b, Buffer.from("x")]),
  "missing EOCD": () => Buffer.from("not a ZIP"),
  "central signature": (b, cd) => b.writeUInt32LE(0, cd),
  "central size": (b, cd, end) => b.writeUInt32LE(1, end + 12),
  "central offset": (b, cd, end) => b.writeUInt32LE(0xfffffffe, end + 16),
  "central name bounds": (b, cd) => b.writeUInt16LE(65535, cd + 28),
  "entry count mismatch": (b, cd, end) => b.writeUInt16LE(2, end + 10),
  "multidisk": (b, cd, end) => b.writeUInt16LE(1, end + 4),
  "ZIP64 count": (b, cd, end) => b.writeUInt16LE(65535, end + 10),
  "ZIP64 size": (b, cd) => b.writeUInt32LE(0xffffffff, cd + 24),
  "ZIP64 offset": (b, cd) => b.writeUInt32LE(0xffffffff, cd + 42),
  "unsupported version": (b, cd) => b.writeUInt16LE(45, cd + 6),
  "unsupported compression": (b, cd) => b.writeUInt16LE(99, cd + 10),
  "encrypted entry": (b, cd) => b.writeUInt16LE(1, cd + 8),
  "local signature": (b) => b.writeUInt32LE(0, 0),
  "local offset bounds": (b, cd) => b.writeUInt32LE(cd, cd + 42),
  "local name mismatch": (b) => b.writeUInt8(88, 30),
  "local size mismatch": (b) => b.writeUInt32LE(4, 22),
  "payload bounds": (b, cd) => b.writeUInt32LE(9999, cd + 20),
};
for (const [name, mutate] of Object.entries(mutations)) test(`rejects corrupt or unsupported ZIP: ${name}`, (t) => {
  let artifact = zip();
  const end = artifact.length - 22, cd = artifact.readUInt32LE(end + 16);
  const replacement = mutate(artifact, cd, end);
  if (Buffer.isBuffer(replacement)) artifact = replacement;
  const f = fixture(t, artifact), result = f.run([f.release, f.budget, "--report-only"]);
  assert.equal(result.status, 1, result.output);
  assert.match(result.output, /release-budget: FAILED/);
});
for (const [name, entries] of [
  ["empty archive", []], ["only directories", [{ name: "Homestead/" }]],
  ["duplicate names", [{ name: "same" }, { name: "same" }]],
]) test(`rejects ${name}`, (t) => {
  const f = fixture(t, zip(entries));
  assert.equal(f.run().status, 1);
});
test("unknown arguments fail", (t) => {
  const f = fixture(t);
  assert.equal(f.run([f.release, f.budget, "--unknown"]).status, 1);
});

test("duplicate baseline keys fail even when JSON parsing would overwrite them", (t) => {
  const f = fixture(t);
  writeFileSync(f.budget, JSON.stringify(baseline(f.maximums)).replace('"schemaVersion":1', '"schemaVersion":2,"schemaVersion":1'));
  const result = f.run();
  assert.equal(result.status, 1, result.output);
  assert.match(result.output, /duplicate.*baseline|baseline.*duplicate/i);
});

test("escaped duplicate baseline keys also fail", (t) => {
  const f = fixture(t);
  writeFileSync(f.budget, JSON.stringify(baseline(f.maximums)).replace('"schemaVersion":1', '"schemaVersion":2,"\\u0073chemaVersion":1'));
  const result = f.run();
  assert.equal(result.status, 1, result.output);
  assert.match(result.output, /duplicate.*baseline|baseline.*duplicate/i);
});

test("baseline string values can contain escaped quotes and colons", (t) => {
  const f = fixture(t);
  f.setBudget({ ...baseline(f.maximums), sourceRelease: 'release "schemaVersion":1' });
  const result = f.run();
  assert.equal(result.status, 0, result.output);
});

for (const [name, id, size, status] of [["ZIP64", 1, 0, 1], ["truncated", 0xffff, 5, 1], ["unknown well-formed", 0xffff, 0, 0]]) {
  test(`${name} central extra field`, (t) => {
    const original = zip(), end = original.length - 22, cd = original.readUInt32LE(end + 16);
    const extra = Buffer.alloc(4);
    extra.writeUInt16LE(id);
    extra.writeUInt16LE(size, 2);
    const artifact = Buffer.concat([original.subarray(0, end), extra, original.subarray(end)]);
    artifact.writeUInt16LE(4, cd + 30);
    artifact.writeUInt32LE(original.readUInt32LE(end + 12) + 4, end + 4 + 12);
    const f = fixture(t, artifact), result = f.run();
    assert.equal(result.status, status, result.output);
    if (status) assert.match(result.output, /release-budget: FAILED/);
  });
}

test("mismatching data descriptor fails", (t) => {
  const artifact = zip([{ name: "test.lua", text: "hello", deflate: true, descriptor: true }]);
  const cd = artifact.readUInt32LE(artifact.length - 6);
  artifact.writeUInt32LE(4, cd - 4);
  const f = fixture(t, artifact), result = f.run();
  assert.equal(result.status, 1, result.output);
  assert.match(result.output, /descriptor/i);
});

test("unlisted bytes before local records fail", (t) => {
  const original = zip(), end = original.length - 22, cd = original.readUInt32LE(end + 16);
  const artifact = Buffer.concat([Buffer.from([0]), original]);
  artifact.writeUInt32LE(1, cd + 1 + 42);
  artifact.writeUInt32LE(cd + 1, end + 1 + 16);
  const f = fixture(t, artifact), result = f.run();
  assert.equal(result.status, 1, result.output);
  assert.match(result.output, /records between entries/);
});

for (const metric of metricNames) for (const reportOnly of [false, true]) {
  test(`zero ${metric} fails baseline validation${reportOnly ? " in report-only mode" : ""}`, (t) => {
    const f = fixture(t);
    f.setBudget(baseline({ ...f.maximums, [metric]: 0 }));
    const result = f.run([f.release, f.budget, ...(reportOnly ? ["--report-only"] : [])]);
    assert.equal(result.status, 1, result.output);
    assert.match(result.output, new RegExp(`Invalid baseline ${metric}`));
  });
}