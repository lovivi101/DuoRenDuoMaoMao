import {WebSocket,WebSocketServer} from 'ws';
import type {Server} from 'node:http';
import type {Store} from '../store/store.js';
import {safeUser,verifyToken} from '../auth.js';
import type {GameMessage,Player,Room,User} from '../types.js';
import {Lobby,validateSettings} from '../lobby/lobby.js';
import {lookOf} from '../economy.js';
// ~8 kHz 8-bit μ-law chunks of 100 ms arrive base64 encoded (~1.1 KB each).
const VOICE={range:8,perSecond:15,maxChars:4000};
import {action,ghostSide,mark,matchRecord,rewardsFor,setInput,setOnline,snapshotFor,tickGame} from '../game/engine.js';
import {wireMap} from '../game/maps/old_dorm.js';
import {visible} from '../game/vision.js';
import {CONFIG} from '../game/config.js';
export class Hub {
 wss=new WebSocketServer({noServer:true,maxPayload:16384});
 sockets=new Map<string,WebSocket>();lobby:Lobby;private timer?:NodeJS.Timeout;private lastStatus=0;
 private disconnected=new Map<string,number>();
 constructor(public server:Server,public store:Store,public secret:string,private clock=Date.now,minPlayers=CONFIG.matchMinPlayers){
 this.lobby=new Lobby(minPlayers,clock);
 server.on('upgrade',(req,socket,head)=>{
 const url=new URL(req.url||'/', 'http://localhost');
 if(url.pathname!=='/ws'){socket.end('HTTP/1.1 404 Not Found\r\n\r\n');return}
 const uid=verifyToken(url.searchParams.get('token')||'',secret,clock()),u=uid?store.getUser(uid):undefined;
 this.wss.handleUpgrade(req,socket,head,ws=>{
 if(!u){ws.send(JSON.stringify({t:'error',code:'UNAUTHORIZED',msg:'请重新登录'}));ws.close(1008);return}
 this.connect(ws,u);
 });
 });
 }
 status=(id:string):'online'|'in_game'|'offline'=>this.sockets.has(id)?(this.lobby.roomOf(id)?.phase==='playing'?'in_game':'online'):'offline';
 send(id:string,m:unknown){const ws=this.sockets.get(id);if(ws?.readyState===WebSocket.OPEN){if(ws.bufferedAmount>1024*1024){ws.close(1013,'slow client');return}ws.send(JSON.stringify(m))}}
 // 近距离语音 (design §11.4): only in rooms with voice on; in a match only players within
 // VOICE.range hear a speaker (hunters included), louder when closer; ghosts and caged
 // players are heard only by each other so the caught cannot call out the hunter.
 private voiceBudget=new Map<string,{at:number;count:number}>();
 voice(r:Room,id:string,m:Record<string,unknown>){
 if(!r.settings.voiceEnabled||typeof m.d!=='string'||m.d.length>VOICE.maxChars)return;
 const now=this.clock();let b=this.voiceBudget.get(id);if(!b||now-b.at>=1000){b={at:now,count:0};this.voiceBudget.set(id,b)}if(++b.count>VOICE.perSecond)return;
 const g=r.game,out=(to:string,vol:number)=>{if(to!==id)this.send(to,{t:'voice',from:id,d:m.d,vol:+vol.toFixed(2)})};
 if(!g||g.phase==='result'||g.phase==='waiting'){for(const p of r.players)if(!p.isBot)out(p.id,1);return}
 const sp=g.players.find(p=>p.id===id);if(!sp)return;const muted=(p:typeof sp)=>p.state==='ghost'||p.caged;
 for(const p of g.players){if(p.isBot||muted(p)!==muted(sp))continue;const d=Math.hypot(p.x-sp.x,p.y-sp.y);if(d<=VOICE.range)out(p.id,1-d/VOICE.range*.8)}
 }
 broadcast(r:Room,m:unknown){for(const p of r.players)this.send(p.id,m)}
 state(r:Room){const m={t:'room.state',code:r.code,hostId:r.hostId,settings:r.settings,phase:r.phase,players:r.players.map(p=>({...p,isHost:p.id===r.hostId}))};this.broadcast(r,m);return m}
 private player(u:User):Player{return {id:u.id,nickname:u.nickname,color:u.color,ready:false,isBot:false,isHost:false,online:true,look:lookOf(u)}}
 private voteStart(r:Room){const maps=r.voteMaps??['old_dorm'];return {t:'vote.start',maps,available:maps,endsAt:r.voteEndsAt}}
 private vote(r:Room){this.state(r);this.broadcast(r,this.voteStart(r))}
 private startFor(r:Room,id:string){
 const g=r.game;if(!g)return;const p=g.players.find(p=>p.id===id);if(!p)return;
 const allies=p.role==='hunter'||p.role==='mole'?g.players.filter(q=>q.id!==id&&(q.role==='hunter'||q.role==='mole')).map(q=>({id:q.id,role:q.role})):[];
 this.send(id,{t:'game.start',mapId:g.mapId,map:wireMap(g.map),you:{id,role:p.role},allies,players:g.players.map(({id,nickname,color,isBot,look})=>({id,nickname,color,isBot,look})),durationSec:g.durationSec});
 this.send(id,{t:'game.phase',phase:g.phase,endsAt:g.phaseEndsAt});
 this.send(id,{t:'game.drop',drops:g.drops.filter(d=>d.stage!=='taken').map(({id,x,y,stage})=>({id,x,y,stage}))});
 if(g.event)this.send(id,{t:'game.event',kind:g.event.kind,stage:g.event.stage,at:g.event.at,durationSec:(g.event.until-g.event.at)/1000});
 if(g.result)this.send(id,{t:'game.result',...g.result,rewards:rewardsFor(g,p)});
 const snap=snapshotFor(g,id);if(snap)this.send(id,snap);
 }
 private connect(ws:WebSocket,u:User){
 const old=this.sockets.get(u.id);this.sockets.set(u.id,ws);old?.close(1000,'replaced');
 const r=this.lobby.roomOf(u.id),g=r?.game;
 const disconnectedAt=this.disconnected.get(u.id);const within=disconnectedAt!==undefined&&this.clock()-disconnectedAt<=CONFIG.reconnectSec*1000;
 this.disconnected.delete(u.id);
 if(r){const p=r.players.find(p=>p.id===u.id);if(p)p.online=true;if(g)setOnline(g,u.id,true)}
 this.send(u.id,{t:'hello',user:safeUser(u),serverNow:this.clock(),...(r&&within?{reconnect:{roomCode:r.code}}:{})});
 if(r){this.state(r);if(g)this.startFor(r,u.id);else if(r.phase==='voting')this.send(u.id,this.voteStart(r))}
 let lastSecond=this.clock(),count=0,pongAt=this.clock();
 ws.on('pong',()=>{pongAt=this.clock()});
 const heartbeat=setInterval(()=>{if(this.clock()-pongAt>30000){ws.terminate();return}ws.ping()},10000);heartbeat.unref();
 ws.on('message',raw=>{
 if(this.sockets.get(u.id)!==ws)return;
 try{
 if(this.clock()-lastSecond>=1000){lastSecond=this.clock();count=0}if(++count>100)throw Error('RATE_LIMIT');
 const m=JSON.parse(raw.toString()) as Record<string,unknown>;if(!m||typeof m!=='object'||typeof m.t!=='string')throw Error('BAD_MESSAGE');
 this.handle(u.id,m);
 }catch(e){this.send(u.id,{t:'error',code:e instanceof SyntaxError?'BAD_JSON':e instanceof Error?e.message:'BAD_MESSAGE',msg:e instanceof Error?e.message:'请求无效'})}
 });
 ws.on('close',()=>{clearInterval(heartbeat);if(this.sockets.get(u.id)!==ws)return;
 this.sockets.delete(u.id);this.lobby.matchCancel(u.id);this.disconnected.set(u.id,this.clock());
 const r=this.lobby.roomOf(u.id);if(r){const p=r.players.find(p=>p.id===u.id);if(p)p.online=false;if(r.game)setOnline(r.game,u.id,false);this.state(r)}
 });
 ws.on('error',()=>ws.close());
 }
 handle(id:string,m:Record<string,unknown>){
 const user=this.store.getUser(id);if(!user)throw Error('UNAUTHORIZED');
 if(m.t==='ping'){this.send(id,{t:'pong',c:m.c,s:this.clock()});return}
 if(m.t==='match.start'){const r=this.lobby.matchStart(this.player(user));if(r)this.vote(r);else this.send(id,{t:'match.status',...this.lobby.matchStatus(id)});return}
 if(m.t==='match.cancel'){this.lobby.matchCancel(id);this.send(id,{t:'match.status',...this.lobby.matchStatus(id)});return}
 if(m.t==='match.aiFill'){this.vote(this.lobby.aiFill(id));return}
 if(m.t==='room.create'){this.state(this.lobby.create(this.player(user),m.settings));return}
 if(m.t==='room.join'){if(typeof m.code!=='string'||!/^\d{6}$/.test(m.code))throw Error('NOT_FOUND');this.state(this.lobby.join(m.code,this.player(user)));return}
 const r=this.lobby.roomOf(id);if(!r)throw Error('NOT_IN_ROOM');
 const host=()=>{if(r.hostId!==id)throw Error('HOST_ONLY')};
 const waiting=()=>{if(r.phase!=='waiting')throw Error('ROOM_BUSY')};
 if(m.t==='room.leave'){
 if(r.game){setOnline(r.game,id,false);const p=r.game.players.find(p=>p.id===id);if(p)p.disconnectedAt=r.game.now-CONFIG.reconnectSec*1000}
 this.lobby.leave(r.code,id);this.send(id,{t:'room.left',reason:'leave'});this.state(r);return;
 }
 if(m.t==='voice'){this.voice(r,id,m);return}
 if(m.t==='room.ready'){waiting();if(typeof m.ready!=='boolean')throw Error('BAD_MESSAGE');r.players.find(p=>p.id===id)!.ready=m.ready;this.state(r);return}
 if(m.t==='room.settings'){host();waiting();const s=validateSettings(m.settings,r.settings);if(s.maxPlayers<r.players.length)throw Error('ROOM_FULL');r.settings=s;this.state(r);return}
 if(m.t==='room.addBot'){host();waiting();this.lobby.addBot(r);this.state(r);return}
 if(m.t==='room.kick'){
 host();waiting();if(m.playerId===id||!r.players.some(p=>p.id===m.playerId))throw Error('BAD_TARGET');
 this.send(String(m.playerId),{t:'room.left',reason:'kicked'});this.lobby.leave(r.code,String(m.playerId));this.state(r);return;
 }
 if(m.t==='room.start'){host();this.vote(this.lobby.beginVote(r));return}
 if(m.t==='room.invite'){
 if(!this.store.friends(id).some(f=>f.id===m.friendId))throw Error('NOT_FRIEND');
 if(!this.sockets.has(String(m.friendId)))throw Error('FRIEND_OFFLINE');this.send(String(m.friendId),{t:'invite',from:safeUser(user),code:r.code});return;
 }
 if(m.t==='vote.cast'){const mapId=String(m.mapId);if(r.phase!=='voting'||!(r.voteMaps??[]).includes(mapId))throw Error('BAD_VOTE');r.votes.set(id,mapId);const counts:Record<string,number>={};for(const v of r.votes.values())counts[v]=(counts[v]??0)+1;this.broadcast(r,{t:'vote.update',counts,voters:[...r.votes.keys()]});return}
 if(m.t==='room.again'){
 // A caller can request a rematch during the result screen. Reset the shared
 // room immediately so all clients receive the waiting state and can ready up.
 if(r.phase==='result'){this.lobby.reset(r);this.state(r);return}
 waiting();r.players.find(p=>p.id===id)!.ready=true;this.state(r);return;
 }
 const g=r.game;if(!g||r.phase!=='playing')throw Error('NOT_PLAYING');
 if(m.t==='game.input'){if(typeof m.seq!=='number'||typeof m.mx!=='number'||typeof m.my!=='number'||typeof m.run!=='boolean')throw Error('BAD_INPUT');setInput(g,id,m.seq,m.mx,m.my,m.run)}
 else if(m.t==='game.action'){if(typeof m.kind!=='string')throw Error('BAD_ACTION');action(g,id,m.kind,m)}
 else if(m.t==='game.ghostSide')ghostSide(g,id,String(m.side));
 else if(m.t==='game.mark')mark(g,id,String(m.kind),Number(m.x),Number(m.y));
 else throw Error('UNKNOWN_MESSAGE');
 this.flush(r);
 }
 private flush(r:Room){
 const g=r.game;if(!g)return;
 for(const m of g.outbox.splice(0)){
 if(m.t==='game.result'){
 r.phase='result';
 if(!r.resultSent){for(const p of g.players){const rewards=rewardsFor(g,p);if(!p.isBot&&!g.voided)this.store.reward(g.id,p.id,rewards,matchRecord(g,p));this.send(p.id,{...m,rewards})}r.resultSent=true;this.state(r)}
 }else if(m.t==='game.fx'){
 for(const p of g.players){if(m.by===p.id||visible(g,p,{x:Number(m.x),y:Number(m.y)}))this.send(p.id,m)}
 }else this.broadcast(r,m);
 }
 }
 step(now=this.clock()){
 for(const [id,at] of this.disconnected)if(now-at>=CONFIG.reconnectSec*1000){
 const r=this.lobby.roomOf(id);if(r&&!r.game){this.lobby.leave(r.code,id);this.state(r)}this.disconnected.delete(id);
 }
 for(const r of this.lobby.rooms.values()){
 if(r.phase==='voting'&&now>=r.voteEndsAt){try{const mapId=this.lobby.voteWinner(r);this.lobby.start(r,mapId);this.broadcast(r,{t:'vote.result',mapId});this.state(r);for(const p of r.players)this.startFor(r,p.id)}catch(e){r.phase='waiting';this.broadcast(r,{t:'error',code:'HUNTER_ROTATION',msg:'人数或猎手设置无法满足轮换，请调整房间人数'});this.state(r)}}
 if(r.game){
 tickGame(r.game,now);this.flush(r);
 if(r.game.phase==='waiting'){this.lobby.reset(r);this.state(r)}
 else for(const p of r.players){const snap=snapshotFor(r.game,p.id);if(snap)this.send(p.id,snap)}
 }
 }
 if(now-this.lastStatus>=1000){this.lastStatus=now;for(const q of this.lobby.queue)this.send(q.player.id,{t:'match.status',...this.lobby.matchStatus(q.player.id)})}
 }
 start(){if(!this.timer)this.timer=setInterval(()=>{try{this.step()}catch(e){console.error('tick failed',e)}},1000/CONFIG.tickHz)}
 async close(){if(this.timer)clearInterval(this.timer);for(const ws of this.sockets.values())ws.terminate();await new Promise<void>(resolve=>this.wss.close(()=>resolve()))}
}
