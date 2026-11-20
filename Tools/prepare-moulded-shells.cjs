#!/usr/bin/env node
// Only deterministic catalogue sizing and hub crops happen here. Ink removal
// was performed by imagegen; the native renderer owns its physical masks.
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('/Users/liuhang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '..');
const evidence = path.join(root, 'Evidence/0.4.0/moulded-shells-20261107');
const names = {strata:'Strata',facet:'Facet',islands:'Islands',ribs:'Ribs',stream:'Stream',eclipse:'Eclipse'};
const hubs = {
 strata:[[437.4,488.2,88],[1098.8,487,89]],
 facet:[[453.9,483.8,99],[1080.2,484.9,100]],
 islands:[[440.7,461.8,99],[1083.4,457.4,96]],
 ribs:[[462.7,481.5,96],[1086.8,481.5,96]],
 stream:[[425.8,454.8,113],[1145.2,476.8,119]],
 eclipse:[[450.5,456.2,83],[1086.8,455.2,82]]
};

async function asset(name, pipeline, scale) {
 const folder = path.join(root, 'Stillroom/Resources/Assets.xcassets', `${name}.imageset`);
 await fs.mkdir(folder, {recursive:true});
 await pipeline.png().toFile(path.join(folder, `${name}.png`));
 await fs.writeFile(path.join(folder, 'Contents.json'), JSON.stringify({
  images:[{filename:`${name}.png`,idiom:'universal',scale}],
  info:{author:'xcode',version:1}
 },null,2)+'\n');
}

(async()=>{
 const inputs = JSON.parse(await fs.readFile(path.join(evidence,'resource-inputs.json'),'utf8'));
 const receipt = [];
 const ownTape = path.join(inputs.approvedDirectory,'strata.png');
 await asset('OneTapeMouldTape',sharp(ownTape).extract({left:268,top:318,width:340,height:340}),'3x');
 for (const {id,source} of inputs.blankSources) {
  const prefix = `OneTapeMould${names[id]}`;
  const approved = path.join(inputs.approvedDirectory,`${id}.png`);
  const metadata = await sharp(approved).metadata();
  // The automatic matte also classified some clear glazing as background.
  // Retain the generated RGB here; the native outline supplies exact coverage.
  // Materialize RGB before resizing: a single Sharp pipeline resamples using
  // the source matte first and would discard the glazing's underlying RGB.
  const opaque = await sharp(source).removeAlpha().png().toBuffer();
  await asset(prefix,sharp(opaque).resize(1728,1129,{fit:'fill'}),'3x');
  await asset(`${prefix}Thumb`,sharp(opaque).resize(480,306,{fit:'fill'}),'2x');
  for (let index=0;index<2;index++) {
   const [x,y,radius] = hubs[id][index];
   const diameter = Math.round(radius*2);
   const crop = {left:Math.round(x-radius),top:Math.round(y-radius),width:diameter,height:diameter};
   await asset(`${prefix}Hub${index}`,sharp(approved).extract(crop),'3x');
  }
  receipt.push({id,prefix,sourceSize:[metadata.width,metadata.height],hubs:hubs[id]});
 }
 await fs.writeFile(path.join(evidence,'resource-geometry.json'),JSON.stringify(receipt,null,2)+'\n');
 console.log(`Prepared ${receipt.length} plates, thumbnails and twelve independent hub samples.`);
})().catch(error=>{console.error(error);process.exitCode=1;});
