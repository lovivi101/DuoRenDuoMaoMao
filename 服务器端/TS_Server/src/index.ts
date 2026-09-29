import 'dotenv/config';
import {createServer} from './server.js';
const app=createServer();
const port=await app.listen();
console.log('熄灯 TS server: http://localhost:'+port+' /ws (20Hz)');
let closing=false;
for(const signal of ['SIGINT','SIGTERM'] as const)process.on(signal,()=>{if(closing)return;closing=true;void app.close().then(()=>process.exit(0))});
