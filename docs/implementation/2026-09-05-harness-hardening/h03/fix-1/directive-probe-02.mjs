import { Parser, parseDocument } from '../../../../../packs/autonomy/repo-template/scripts/quality-orchestrator/node_modules/yaml/dist/index.js';
const sample='title: hello\nstatus: active\nenabled: true\nthreshold: 100\n';
for(const [name,source] of [['plain',sample],['explicit-default-tag','%TAG !! tag:yaml.org,2002:\n---\n'+sample],['quoted-text',sample.replace('hello','"%TAG !! tag:yaml.org,2002:"')]]) {
 const document=parseDocument(source,{version:'1.2',schema:'core',keepSourceTokens:true});
 console.log(JSON.stringify({name,tags:document.directives.tags,tokens:[...new Parser().parse(source)].map(t=>({type:t.type,...t.type==='directive'?{source:t.source}:{}}))}));
}
