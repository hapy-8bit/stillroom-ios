#!/usr/bin/env node
// Text removal belongs to imagegen. This step only normalizes the approved
// photographs and crops independent drive/shaft samples at measured centers.
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('/Users/liuhang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '..');
const evidence = path.join(root, 'Evidence/0.4.0/approved-print-friendly-moulds-20261108');

async function writeAsset(name, pipeline, scale = '3x') {
  const folder = path.join(root, 'Stillroom/Resources/Assets.xcassets', name + '.imageset');
  await fs.mkdir(folder, {recursive: true});
  await pipeline.png().toFile(path.join(folder, name + '.png'));
  await fs.writeFile(path.join(folder, 'Contents.json'), JSON.stringify({
    images: [{filename: name + '.png', idiom: 'universal', scale}],
    info: {author: 'xcode', version: 1}
  }, null, 2) + '\n');
}

async function main() {
  const input = JSON.parse(await fs.readFile(path.join(evidence, 'production-inputs.json'), 'utf8'));
  for (const design of input.designs) {
    const suffix = design.id[0].toUpperCase() + design.id.slice(1);
    const name = 'OneTapeMould' + suffix + 'Closed';
    const [left, top, width, height] = design.bounds;
    const outputHeight = Math.round(height * 1662 / width);
    const crop = {left, top, width, height};
    await writeAsset(name, sharp(design.path).extract(crop).resize(1662, outputHeight));
    await writeAsset(name + 'Preview', sharp(design.path).extract(crop)
      .resize(720, Math.round(height * 720 / width)), '2x');
    for (let index = 0; index < 2; index++) {
      const [x, y] = design.centers[index];
      for (const [part, radius] of [['Drive', design.cores[index]], ['Shaft', design.shafts[index]]]) {
        const region = {left: x - radius, top: y - radius, width: radius * 2, height: radius * 2};
        await writeAsset(name + part + index, sharp(design.path).extract(region));
      }
    }
    console.log('Prepared ' + name + ', preview and four independent motion samples.');
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
