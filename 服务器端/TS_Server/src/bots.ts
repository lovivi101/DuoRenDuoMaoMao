import 'dotenv/config';
import {randomUUID} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import WebSocket from 'ws';
import type {GameMap,Pos} from './types.js';
import {astar} from './game/ai/bot.js';
type Snapshot={you:{x:number;y:number;dir:number;state:string;items:(string|null)[];stamina:number;progress:unknown;ghostSide:string|null;cooldowns:{ghostSkill:number}};
 players:{id:string;x:number;y:number;state:string}[];generators:{id:number;x:number;y:number;fixed:boolean}[];ripples:{x:number;y:number;hunter:boolean}[]};
export async function connectBot(base:string,code:string,index:number){
 const response=await fetch(base+'/api/auth/guest',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({deviceId:'ws-bot-'+randomUUID()})});
 const auth=await response.json() as {ok:boolean;token:string;user:{id:string}};if(!auth.ok)throw Error('Bot login failed');
 await fetch(base+'/api/profile',{method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+auth.token},body:JSON.stringify({nickname:'联调AI-'+index,color:'cyan'})});
 const url=new URL('/ws',base);url.protocol=url.protocol==='https:'?'wss:':'ws:';url.searchParams.set('token',auth.token);
 const ws=new WebSocket(url);let map:GameMap|undefined,role='hider',phase='',snap:Snapshot|undefined,seq=0,path:Pos[]=[],think=0,lastAction=0;
 let drops:{id:string;x:number;y:number;stage:string}[]=[];
 const send=(m:unknown)=>{if(ws.readyState===WebSocket.OPEN)ws.send(JSON.stringify(m))};
 const timer=setInterval(()=>{
 if(!map||!snap||!['hide','hunt','final'].includes(phase))return;
 const p=snap.you,now=Date.now();
 if(p.state==='caged'){send({t:'game.ghostSide',side:'guardian'});return}
 if(p.state==='ghost'){if(p.cooldowns.ghostSkill===0)send({t:'game.action',kind:'ghost_skill',x:p.x+1,y:p.y});return}
 const hunter=role==='hunter';if(hunter&&phase==='hide')return;
 const dist=(q:Pos)=>Math.hypot(p.x-q.x,p.y-q.y);
 if(now>=think){
 think=now+600;
 let goal:Pos|undefined;
 if(hunter){goal=snap.players.filter(q=>q.state!=='ghost'&&q.state!=='caged').sort((a,b)=>dist(a)-dist(b))[0]||snap.ripples.filter(q=>!q.hunter).at(-1)}
 else goal=drops.filter(q=>q.stage==='landed'&&p.items.includes(null)).sort((a,b)=>dist(a)-dist(b))[0]||snap.generators.filter(q=>!q.fixed).sort((a,b)=>dist(a)-dist(b))[0];
 goal??=map.props[Math.floor(Math.random()*map.props.length)];path=astar(p,goal,map);if(path.length>1&&dist(path[0])<.4)path.shift();
 }
 if(now-lastAction>700){
 if(hunter&&snap.players.some(q=>q.state!=='ghost'&&dist(q)<1.2)){send({t:'game.action',kind:'slap'});lastAction=now}
 else if(!hunter&&(drops.some(q=>q.stage==='landed'&&dist(q)<1.5)||snap.generators.some(q=>!q.fixed&&dist(q)<1.5))){send({t:'game.action',kind:'interact_start'});lastAction=now;path=[]}
 }
 if(p.progress){send({t:'game.input',seq:seq++,mx:0,my:0,run:false});return}
 while(path.length&&dist(path[0])<.2)path.shift();const next=path[0];
 const d=next?dist(next):0;send({t:'game.input',seq:seq++,mx:d?(next.x-p.x)/d:0,my:d?(next.y-p.y)/d:0,run:hunter});
 },100);
 ws.on('message',raw=>{
 const m=JSON.parse(raw.toString());
 if(m.t==='hello')send({t:'room.join',code});
 if(m.t==='room.state'&&m.phase==='waiting'&&m.players.some((p:{id:string;ready:boolean})=>p.id===auth.user.id&&!p.ready)){send({t:'room.ready',ready:true})}
 if(m.t==='game.start'){role=m.you.role;map={...m.map,tiles:Uint8Array.from(Buffer.from(m.map.tiles,'base64'))};console.log('[bot '+index+'] '+role)}
 if(m.t==='game.phase')phase=m.phase;
 if(m.t==='game.snap')snap=m;
 if(m.t==='game.wall'&&map)for(const c of m.cells){map.tiles[c.y*map.w+c.x]=c.tile;if(c.locked===false)map.lockedDoors=map.lockedDoors.filter(p=>p.x!==c.x||p.y!==c.y)}
 if(m.t==='game.drop')for(const d of m.drops){drops=drops.filter(q=>q.id!==d.id);drops.push(d)}
 if(m.t==='game.result')console.log('[bot '+index+'] winner='+m.winner+' rewards='+JSON.stringify(m.rewards));
 if(m.t==='error'){console.error('[bot '+index+']',m.code);if(['NOT_FOUND','ROOM_FULL','UNAUTHORIZED','ROOM_BUSY'].includes(m.code))ws.close()}
 });
 ws.on('close',()=>clearInterval(timer));ws.on('error',()=>clearInterval(timer));
 await new Promise<void>((resolve,reject)=>{ws.once('open',resolve);ws.once('error',reject)});
 return {ws,id:auth.user.id,close:()=>{clearInterval(timer);ws.close()}};
}
async function main(){
 const args=process.argv.slice(2),arg=(name:string,fallback:string)=>{const i=args.indexOf(name);return i>=0?args[i+1]:fallback};
 const code=arg('--room',''),n=Number(arg('--n','1')),base=arg('--url','http://127.0.0.1:'+(process.env.PORT||8787));
 if(!/^\d{6}$/.test(code)||!Number.isInteger(n)||n<1||n>11)throw Error('usage: npm run bots -- --room <6 digits> --n <1..11> [--url http://host:8787]');
 const bots:Awaited<ReturnType<typeof connectBot>>[]=[];for(let i=0;i<n;i++)bots.push(await connectBot(base,code,i+1));console.log(n+' WS bots joined '+code);
 for(const signal of ['SIGINT','SIGTERM'] as const)process.on(signal,()=>{bots.forEach(b=>b.close());setTimeout(()=>process.exit(),100)});
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href)main().catch(e=>{console.error(e.message);process.exit(1)});
