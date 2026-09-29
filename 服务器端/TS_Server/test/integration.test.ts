import {describe,it,expect} from 'vitest';
import {once} from 'node:events';
import {mkdtempSync,unlinkSync,rmdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import WebSocket from 'ws';
import {createServer} from '../src/server.js';
import {SqliteStore} from '../src/store/store.js';
import {signToken} from '../src/auth.js';
import {finish} from '../src/game/engine.js';
import {connectBot} from '../src/bots.js';
const secret='integration-test-secret-at-least-32-chars';
type Msg={t:string;[key:string]:any};
class Peer {
 messages:Msg[]=[];listeners:(()=>void)[]=[];
 constructor(public ws:WebSocket){ws.on('message',raw=>{this.messages.push(JSON.parse(raw.toString()));for(const fn of [...this.listeners])fn()})}
 send(m:unknown){this.ws.send(JSON.stringify(m))}
 next(t:string,predicate:(m:Msg)=>boolean=()=>true):Promise<Msg>{
 return new Promise((resolve,reject)=>{
 const find=()=>{const i=this.messages.findIndex(m=>m.t===t&&predicate(m));if(i>=0){clearTimeout(timeout);this.listeners=this.listeners.filter(f=>f!==find);resolve(this.messages.splice(i,1)[0])}};
 const timeout=setTimeout(()=>{this.listeners=this.listeners.filter(f=>f!==find);reject(Error('timeout '+t+' got '+this.messages.map(m=>m.t).join(',')))},3000);this.listeners.push(find);find();
 });
 }
}
describe('real HTTP and WebSocket integration',()=>{
 it('full account wire flow, malformed JSON, unauthorized WS, profile and notice',async()=>{
 const app=createServer({store:new SqliteStore(':memory:'),secret,autoTick:false});const port=await app.listen(0,'127.0.0.1'),base='http://127.0.0.1:'+port;
 const post=async(path:string,body:unknown,token='')=>{const r=await fetch(base+path,{method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+token},body:JSON.stringify(body)});return {status:r.status,...await r.json() as object} as any};
 try{
 const reg=await post('/api/auth/register',{account:'wiretest',password:'secret123'});expect(reg.ok).toBe(true);expect(reg.user).not.toHaveProperty('salt');
 const login=await post('/api/auth/password',{account:'wiretest',password:'secret123'});expect(login.user.id).toBe(reg.user.id);
 const me=await fetch(base+'/api/me',{headers:{authorization:'Bearer '+reg.token}});expect((await me.json() as any).user.id).toBe(reg.user.id);
 expect((await post('/api/profile',{nickname:'网络猫',color:'pink'},reg.token)).user.needsProfile).toBe(false);
 const sms=await post('/api/auth/sms/send',{phone:'13900000000'});expect(sms.devCode).toMatch(/^\d{6}$/);
 expect((await post('/api/auth/sms/login',{phone:'13900000000',code:sms.devCode})).ok).toBe(true);
 expect((await post('/api/auth/wechat',{code:'mock_wire'})).ok).toBe(true);
 const invalid=new Peer(new WebSocket('ws://127.0.0.1:'+port+'/ws?token=bad'));expect((await invalid.next('error')).code).toBe('UNAUTHORIZED');invalid.ws.terminate();
 const bad=await fetch(base+'/api/auth/guest',{method:'POST',body:'{bad'});expect((await bad.json() as any).code).toBe('BAD_JSON');
 expect((await (await fetch(base+'/api/notice')).json() as any).ok).toBe(true);
 }finally{await app.close()}
 });
 it('room ready/start/vote/private roles, live bot connections, reconnect, result rewards and return, host transfer',async()=>{
 let now=Date.now();const app=createServer({store:new SqliteStore(':memory:'),secret,clock:()=>now,minPlayers:8,autoTick:false});
 const port=await app.listen(0,'127.0.0.1'),base='http://127.0.0.1:'+port;
 const users=[app.store.create('guest','host_device'),app.store.create('guest','guest_device')];
 const peers:Peer[]=[];
 const connect=async(i:number)=>{const p=new Peer(new WebSocket('ws://127.0.0.1:'+port+'/ws?token='+signToken(users[i].id,secret,86400,now)));peers.push(p);await p.next('hello');return p};
 let bot:Awaited<ReturnType<typeof connectBot>>|undefined;
 try{
 const a=await connect(0),b=await connect(1);
 a.send({t:'room.create',settings:{moleEnabled:true}});const room=await a.next('room.state');const code=room.code;
 b.send({t:'room.join',code});await b.next('room.state');a.send({t:'room.start'});expect((await a.next('error')).code).toBe('NOT_READY');
 b.send({t:'room.ready',ready:true});await b.next('room.state',m=>m.players.find((p:any)=>p.id===users[1].id)?.ready);
 // A real test bot logs in via HTTP and joins/readies via WS.
 bot=await connectBot(base,code,1);
 await a.next('room.state',m=>m.players.some((p:any)=>p.id===bot!.id&&p.ready));
 a.send({t:'room.start'});await a.next('vote.start');
 b.send({t:'vote.cast',mapId:'old_dorm'});await b.next('vote.update');
 now+=10001;app.hub.step(now);
 const start=await b.next('game.start');expect(start.you.id).toBe(users[1].id);expect(start.you.role).toMatch(/hunter|hider/);expect(start.map.tiles).toHaveLength(3416);
 const r=app.hub.lobby.rooms.get(code)!;expect(r.game!.players).toHaveLength(8);
 // Close and reconnect through a new actual WS connection.
 b.ws.close();await once(b.ws,'close');await new Promise(resolve=>setTimeout(resolve,10));
 now+=1000;
 const token=signToken(users[1].id,secret,86400,now),re=new Peer(new WebSocket('ws://127.0.0.1:'+port+'/ws?token='+token));peers.push(re);
 const hello=await re.next('hello');expect(hello.reconnect.roomCode).toBe(code);expect((await re.next('game.start')).you.role).toBe(start.you.role);
 // Drive production hub ticks with fake wall-clock time to avoid real minutes.
 for(let i=0;i<501;i++){now+=50;app.hub.step(now)}
 expect(r.game!.phase).toBe('hunt');finish(r.game!,'hider');app.hub.step(now+50);
 const result=await re.next('game.result');expect(result.rewards.exp).toBeGreaterThanOrEqual(50);
 const exp=app.store.getUser(users[1].id)!.exp;app.hub.step(now+100);expect(app.store.getUser(users[1].id)!.exp).toBe(exp);
 now+=15100;app.hub.step(now);expect(r.phase).toBe('waiting');expect(r.game).toBeUndefined();
 a.send({t:'room.leave'});await a.next('room.left');await re.next('room.state',m=>m.hostId===users[1].id);
 }finally{bot?.close();peers.forEach(p=>p.ws.terminate());await app.close()}
 },15000);
 it('quick match updates every connection membership, kicks revoke authority, invites only friends',async()=>{
 let now=Date.now();const app=createServer({store:new SqliteStore(':memory:'),secret,clock:()=>now,minPlayers:2,autoTick:false});const port=await app.listen(0,'127.0.0.1');
 const u=[app.store.create('guest','match_a'),app.store.create('guest','match_b')],ps=u.map(x=>new Peer(new WebSocket('ws://127.0.0.1:'+port+'/ws?token='+signToken(x.id,secret))));
 try{
 await Promise.all(ps.map(p=>p.next('hello')));ps[0].send({t:'match.start'});expect((await ps[0].next('match.status')).found).toBe(1);
 ps[1].send({t:'match.start'});await Promise.all(ps.map(p=>p.next('vote.start')));expect(app.hub.lobby.roomOf(u[0].id)).toBe(app.hub.lobby.roomOf(u[1].id));
 now+=10001;app.hub.step(now);await Promise.all(ps.map(p=>p.next('game.start')));
 }finally{ps.forEach(p=>p.ws.terminate());await app.close()}
 });
 it('sqlite survives reopening and idempotent rewards survive restart',()=>{
 const dir=mkdtempSync(join(tmpdir(),'xideng-test-')),file=join(dir,'test.db');let store=new SqliteStore(file);
 try{const u=store.create('guest','persist'),f=store.create('guest','friend');store.addFriend(u.id,f.id);store.reward('m',u.id,{exp:99,coins:1,rankDelta:2});store.close();store=new SqliteStore(file);
 expect(store.findDevice('persist')?.exp).toBe(99);expect(store.friends(u.id)).toHaveLength(1);store.reward('m',u.id,{exp:99,coins:1,rankDelta:2});expect(store.getUser(u.id)?.exp).toBe(99);
 }finally{store.close();for(const suffix of ['','-wal','-shm'])try{unlinkSync(file+suffix)}catch{}rmdirSync(dir)}
 });
});
