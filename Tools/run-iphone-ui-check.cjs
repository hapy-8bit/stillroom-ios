#!/usr/bin/env node
// One controlled XCTest session followed by an ordinary app launch. Keep the
// test exit code: restoring the app must never conceal a failed/crashed test.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawn, spawnSync } = require('node:child_process');
const bundle = 'com.liuhang.stillroom';
const options = {};
for (let i = 2; i < process.argv.length; i += 2) {
  const key = process.argv[i];
  if (key === '--help') {
    console.log('Usage: node Tools/run-iphone-ui-check.cjs --device UDID --xctestrun FILE --result RESULT.xcresult --log LOG --only-testing StillroomUITests/CLASS --receipt FILE.json');
    process.exit(0);
  }
  if (!['--device', '--xctestrun', '--result', '--log', '--only-testing', '--receipt'].includes(key)
      || !process.argv[i + 1]) throw new Error('Unknown or missing argument: ' + key);
  options[key.slice(2)] = process.argv[i + 1];
}
for (const key of ['device', 'xctestrun', 'result', 'log', 'only-testing', 'receipt']) {
  if (!options[key]) throw new Error('Missing --' + key);
}
if (!options['only-testing'].startsWith('StillroomUITests/')) throw new Error('Only this app’s UI test target is supported.');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'onetape-usb-check-'));
const lockFile = path.join(os.tmpdir(), 'onetape-usb-' + options.device.replace(/[^a-z0-9-]/gi, '_') + '.lock');
function acquireLock() {
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const handle = fs.openSync(lockFile, 'wx');
      fs.writeFileSync(handle, JSON.stringify({ pid: process.pid, startedAt: new Date().toISOString() }));
      fs.closeSync(handle);
      return;
    } catch (error) {
      if (error.code !== 'EEXIST') throw error;
      const existing = JSON.parse(fs.readFileSync(lockFile, 'utf8'));
      if (!Number.isInteger(existing.pid) || existing.pid <= 0) throw new Error('USB test lock requires inspection: ' + lockFile);
      try { process.kill(existing.pid, 0); }
      catch (failure) {
        if (failure.code === 'ESRCH') { fs.unlinkSync(lockFile); continue; }
        throw failure;
      }
      throw new Error('Another One Tape USB check is active (host PID ' + existing.pid + '); do not interrupt its app process.');
    }
  }
  throw new Error('Unable to acquire the USB check lock.');
}
function command(binary, args) {
  const result = spawnSync(binary, args, { encoding: 'utf8' });
  if (result.status !== 0) throw new Error(binary + ' failed: ' + (result.stderr || result.stdout));
  return result.stdout;
}
function deviceJSON(args, name) {
  const file = path.join(temporary, name + '.json');
  command('xcrun', ['devicectl', 'device', ...args.slice(0, 2), '--device', options.device,
    '--json-output', file, '--quiet', ...args.slice(2)]);
  return JSON.parse(fs.readFileSync(file, 'utf8')).result;
}
function verifyWired() {
  const result = deviceJSON(['info', 'details'], 'device').properties;
  if (result.connection.transportType !== 'wired' || result.hardware.reality !== 'physical'
      || result.hardware.deviceType !== 'iPhone') throw new Error('An authorized wired physical iPhone is required.');
  return { device: result.hardware.marketingName, os: result.software.osVersionNumber.stringValue, transportType: 'wired' };
}
function verifyTarget() {
  const run = JSON.parse(command('plutil', ['-convert', 'json', '-o', '-', options.xctestrun]));
  const applications = [];
  const dependencies = [];
  const resolve = value => path.resolve(value.replace('__TESTROOT__', path.dirname(path.resolve(options.xctestrun))));
  function visit(value) {
    if (!value || typeof value !== 'object') return;
    if (value.UITargetAppPath) applications.push(value.UITargetAppPath);
    if (value.DependentProductPaths) dependencies.push(...value.DependentProductPaths);
    if (value.TestHostPath) dependencies.push(value.TestHostPath);
    Object.values(value).forEach(visit);
  }
  visit(run);
  if (!applications.length) throw new Error('No target app is declared in the xctestrun.');
  const targets = applications.map(resolve);
  if (new Set(targets).size !== 1) throw new Error('The UI check must target one exact app artifact.');
  let expectedBuild;
  for (const app of applications) {
    const resolved = resolve(app);
    const info = JSON.parse(command('plutil', ['-convert', 'json', '-o', '-', path.join(resolved, 'Info.plist')]));
    if (info.CFBundleIdentifier !== bundle) throw new Error('Refusing a UI target outside One Tape.');
    expectedBuild = info.CFBundleVersion;
  }
  // Xcode installs dependent products as well as UITargetAppPath. An older
  // same-bundle dependency silently replaces the intended normal app artifact.
  for (const dependency of dependencies.filter(value => value.endsWith('.app'))) {
    const resolved = resolve(dependency);
    const info = JSON.parse(command('plutil', ['-convert', 'json', '-o', '-', path.join(resolved, 'Info.plist')]));
    if (info.CFBundleIdentifier === bundle && resolved !== targets[0]) {
      throw new Error('A dependent product references a different One Tape app; use one exact artifact throughout the xctestrun.');
    }
  }
  return String(expectedBuild);
}
async function main() {
  const receipt = { startedAt: new Date().toISOString(), bundleIdentifier: bundle, device: verifyWired() };
  receipt.expectedBuild = verifyTarget();
  acquireLock();
  fs.mkdirSync(path.dirname(path.resolve(options.log)), { recursive: true });
  const log = fs.createWriteStream(options.log);
  console.log('Starting one controlled XCTest session; One Tape will be normally launched when it ends.');
  try {
    receipt.testExitCode = await new Promise((resolve, reject) => {
      const child = spawn('xcodebuild', ['test-without-building', '-xctestrun', options.xctestrun,
        '-destination', 'platform=iOS,id=' + options.device, '-resultBundlePath', options.result,
        '-parallel-testing-enabled', 'NO', '-only-testing:' + options['only-testing']],
      { stdio: ['ignore', 'pipe', 'pipe'] });
      child.stdout.pipe(log, { end: false });
      child.stderr.pipe(log, { end: false });
      child.once('error', reject);
      child.once('close', code => resolve(code ?? 1));
    });
  } finally {
    log.end();
    try {
      receipt.deviceAtNormalLaunch = verifyWired();
      const installed = deviceJSON(['info', 'apps', '--filter', "bundleIdentifier == '" + bundle + "'"], 'installed');
      receipt.installedBuild = installed.apps.find(app => app.bundleIdentifier === bundle)?.bundleVersion;
      receipt.normalLaunch = deviceJSON(['process', 'launch', bundle], 'normal-launch');
      receipt.finishedAt = new Date().toISOString();
      fs.mkdirSync(path.dirname(path.resolve(options.receipt)), { recursive: true });
      fs.writeFileSync(options.receipt, JSON.stringify(receipt, null, 2) + '\n');
    } finally { fs.unlinkSync(lockFile); }
  }
  if (receipt.installedBuild !== receipt.expectedBuild) throw new Error('The installed app build does not match the tested artifact.');
  process.exitCode = receipt.testExitCode;
  console.log('One Tape normally launched. XCTest exit code: ' + receipt.testExitCode);
}
main().catch(error => { console.error(error.message); process.exitCode = 1; })
  .finally(() => fs.rmSync(temporary, { recursive: true, force: true }));
