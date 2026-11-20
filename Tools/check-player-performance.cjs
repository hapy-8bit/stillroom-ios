#!/usr/bin/env node
// Validate actual same-device measurements, not a configured animation rate.
const fs = require('node:fs');
const file = process.argv[2];
if (!file) throw new Error('Provide performance-comparison.json from the recorded device run.');
const report = JSON.parse(fs.readFileSync(file, 'utf8'));
const before = report.before;
const after = report.after;
const positive = value => Number.isFinite(value) && value > 0;
for (const sample of [before, after]) {
  if (!positive(sample.frameRate.steadyMean) || !positive(sample.metrics.cpuSeconds)
      || !positive(sample.metrics.wallSeconds) || sample.frameRate.samples.length < 8) {
    throw new Error('Incomplete frame/CPU evidence; do not infer FPS from a nominal target.');
  }
}
const cpuRatio = after.metrics.cpuSeconds / after.metrics.wallSeconds /
  (before.metrics.cpuSeconds / before.metrics.wallSeconds);
if (after.frameRate.steadyMean < 55) throw new Error('Steady display rate is below the 55 FPS floor.');
if (cpuRatio > 0.70) throw new Error('CPU cost has not improved by at least 30% in the same workload.');
if (after.metrics.physicalMemoryKB > before.metrics.physicalMemoryKB * 1.10) {
  throw new Error('Physical memory grew by more than 10%.');
}
if (report.normalAppearance && report.normalAppearance.steadyMean < 55) {
  throw new Error('Normal appearance is below the 55 FPS floor.');
}
console.log(`PASS: ${before.frameRate.steadyMean.toFixed(1)} → ${after.frameRate.steadyMean.toFixed(1)} FPS; ` +
  `CPU per wall-second reduced ${(100 * (1 - cpuRatio)).toFixed(1)}%; memory within budget.`);
