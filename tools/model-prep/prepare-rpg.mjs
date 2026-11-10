import {NodeIO} from '@gltf-transform/core';
import {dedup,weld,simplify,prune,textureCompress} from '@gltf-transform/functions';
import {MeshoptSimplifier} from 'meshoptimizer';
import sharp from 'sharp';
import {writeFile,readdir,mkdir} from 'node:fs/promises';
import {resolve,basename,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
if (!process.argv[2]) throw new Error('Usage: node prepare-rpg.mjs /path/to/Hi3D-models');
const source=resolve(process.argv[2]);
const out=resolve(dirname(fileURLToPath(import.meta.url)),'../../assets/models');
await mkdir(out,{recursive:true});
await MeshoptSimplifier.ready;
const io=new NodeIO();
const files=await readdir(source), report=[];
for(const [key,word,ratio] of [['hero','少年',.045],['slime','史莱姆',.025],['sword','短剑',.016],['village','村落',.14]]) {
 const match=files.find(n=>n.includes(word)&&n.toLowerCase().endsWith('.glb'));
 if (!match) throw new Error(`Missing ${key}: expected a .glb filename containing ${word}`);
 const file=resolve(source,match);
 const doc=await io.read(file);
 const count=()=>doc.getRoot().listMeshes().reduce((s,m)=>s+m.listPrimitives().reduce((n,p)=>n+p.getAttribute('POSITION').getCount(),0),0);
 const before=count();
 await doc.transform(dedup(),weld(),simplify({simplifier:MeshoptSimplifier,ratio,error:.0008}),prune(),textureCompress({encoder:sharp,targetFormat:'jpeg',resize:[2048,2048],quality:94}));
 for(const m of doc.getRoot().listMaterials())m.setMetallicFactor(key==='sword'?.45:0).setRoughnessFactor(key==='sword'?.36:.84);
 await io.write(`${out}/${key}-optimized.glb`,doc);
 report.push({key,source:basename(file),before,after:count()});
 console.log(key,before,'->',count());
}
await writeFile(`${out}/manifest.json`,JSON.stringify(report,null,2));
