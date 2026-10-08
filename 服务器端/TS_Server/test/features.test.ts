import {describe,it,expect} from 'vitest';
import {Api} from '../src/http/api.js';
import {SqliteStore} from '../src/store/store.js';
import {createGame,matchRecord,tickGame,action} from '../src/game/engine.js';
import {visionRadius} from '../src/game/vision.js';
import {mechanicsSpeed,MECH} from '../src/game/mechanics.js';
import {Lobby} from '../src/lobby/lobby.js';
import {seeded} from '../src/sim.js';
import type {GameState,MatchRecord,User} from '../src/types.js';

const secret='test-only-secret-32-characters-long';
const players=(n=8)=>Array.from({length:n},(_,i)=>({id:'p'+i,nickname:'P'+i,color:'blue' as const,isBot:false}));
function hunt(mapId:string){
 const g=createGame('T',players(),600,1,false,{now:100000,random:seeded(3),mapId});
 g.phase='hunt';g.huntStartedAt=g.now;g.phaseEndsAt=g.now+600000;g.nextEventAt=g.now+600000;g.nextDropAt=g.now+600000;
 return g;
}
const ticks=(g:GameState,seconds:number)=>{for(let i=0;i<seconds*20;i++)tickGame(g)};
const hider=(g:GameState)=>g.players.find(p=>p.role==='hider')!;

describe('shop, wardrobe, tasks and records',()=>{
 it('buys with coins, refuses duplicates and poverty, equips only owned items',async()=>{
  const store=new SqliteStore(':memory:');const api=new Api(store,secret,()=>'offline',()=>100000);
  const u=store.create('guest','device-1');u.coins=1000;store.saveUser(u);const me=()=>store.getUser(u.id)!;
  const shop=await api.route('GET','/api/shop',{},me()) as {items:{id:string;slot:string;owned:boolean}[];look:{hat:string}};
  expect(shop.look.hat).toBe('nightcap');expect(shop.items.find(i=>i.slot==='hat'&&i.id==='nightcap')!.owned).toBe(true);
  await expect(api.route('POST','/api/wardrobe/equip',{slot:'hat',id:'cat'},me())).rejects.toMatchObject({code:'NOT_OWNED'});
  await api.route('POST','/api/shop/buy',{slot:'hat',id:'cat'},me());expect(me().coins).toBe(200);
  await expect(api.route('POST','/api/shop/buy',{slot:'hat',id:'cat'},me())).rejects.toMatchObject({code:'ALREADY_OWNED'});
  await expect(api.route('POST','/api/shop/buy',{slot:'hat',id:'dino'},me())).rejects.toMatchObject({code:'NOT_ENOUGH_COINS'});
  await expect(api.route('POST','/api/shop/buy',{slot:'hat',id:'crown'},me())).rejects.toMatchObject({code:'NOT_ENOUGH_GEMS'});
  const r=await api.route('POST','/api/wardrobe/equip',{slot:'hat',id:'cat'},me()) as {user:{look:{hat:string}}};
  expect(r.user.look.hat).toBe('cat');
 });
 it('match rewards advance daily tasks once per match; claiming pays out once; records list newest first',async()=>{
  const store=new SqliteStore(':memory:');let now=Date.UTC(2026,9,8,4);const api=new Api(store,secret,()=>'offline',()=>now);
  const u=store.create('guest','device-2');const rec=(id:string,at:number):MatchRecord=>({matchId:id,at,mapId:'old_dorm',role:'hider',win:true,score:300,captures:0,rescues:1,repairs:2,survived:true,mvp:true,durationSec:420});
  store.reward('m1',u.id,{exp:100,coins:50,rankDelta:20},rec('m1',now));store.reward('m1',u.id,{exp:100,coins:50,rankDelta:20},rec('m1',now));
  store.reward('m2',u.id,{exp:100,coins:50,rankDelta:20},rec('m2',now+1000));
  const me=()=>store.getUser(u.id)!;expect(me().coins).toBe(100);expect(me().stats).toMatchObject({games:2,wins:2,rescues:2,repairs:4,mvp:2});
  const tasks=(await api.route('GET','/api/tasks',{},me())).tasks as {id:string;progress:number;goal:number}[];
  expect(tasks.find(t=>t.id==='play')!.progress).toBe(2);expect(tasks.find(t=>t.id==='repair')!.progress).toBe(2);
  await expect(api.route('POST','/api/tasks/claim',{id:'play'},me())).rejects.toMatchObject({code:'TASK_NOT_DONE'});
  await api.route('POST','/api/tasks/claim',{id:'survive'},me());expect(me().gems).toBe(5);
  await expect(api.route('POST','/api/tasks/claim',{id:'survive'},me())).rejects.toMatchObject({code:'ALREADY_CLAIMED'});
  const records=(await api.route('GET','/api/records',{},me())).records as MatchRecord[];expect(records.map(r=>r.matchId)).toEqual(['m2','m1']);
  now+=86400000;const fresh=(await api.route('GET','/api/tasks',{},me())).tasks as {progress:number;claimed:boolean}[];
  expect(fresh.every(t=>t.progress===0&&!t.claimed)).toBe(true);
 });
 it('builds a match record from the game state',()=>{
  const g=hunt('old_dorm');const p=hider(g);p.score={'修理发电机':80,'解救队友':60};g.winner='hider';
  expect(matchRecord(g,p)).toMatchObject({repairs:2,rescues:1,win:true,role:'hider',survived:true,mapId:'old_dorm'});
 });
});

describe('account recovery and binding',()=>{
 it('resets a password through the bound phone and lets other logins add an account',async()=>{
  const store=new SqliteStore(':memory:');const api=new Api(store,secret,()=>'offline',()=>100000);
  const reg=await api.route('POST','/api/auth/register',{account:'nightcat',password:'secret123'});
  const u=store.getUser((reg.user as User).id)!;u.bindings.phone='13800000000';store.saveUser(u);
  const sms=await api.route('POST','/api/auth/sms/send',{phone:'13800000000'});
  const reset=await api.route('POST','/api/auth/password/reset',{phone:'13800000000',code:sms.devCode,password:'newpass1'});expect(reset.account).toBe('nightcat');
  await expect(api.route('POST','/api/auth/password',{account:'nightcat',password:'secret123'})).rejects.toMatchObject({code:'PASSWORD_WRONG'});
  expect((await api.route('POST','/api/auth/password',{account:'nightcat',password:'newpass1'})).ok).toBe(true);
  const guest=store.create('guest','device-3');
  await api.route('POST','/api/bind/account',{account:'guest_one',password:'secret123'},guest);
  expect((await api.route('POST','/api/auth/password',{account:'guest_one',password:'secret123'})).ok).toBe(true);
  await expect(api.route('POST','/api/bind/account',{account:'other',password:'secret123'},store.getUser(guest.id))).rejects.toMatchObject({code:'ACCOUNT_EXISTS'});
 });
});

describe('map vote',()=>{
 it('offers the host pick plus two other maps and starts the most voted one',()=>{
  const lobby=new Lobby(1,()=>100000);const host={id:'h',nickname:'H',color:'blue' as const,ready:true,isBot:false,isHost:true,online:true};
  const r=lobby.create(host,{map:'night_mall'});lobby.beginVote(r);
  expect(r.voteMaps![0]).toBe('night_mall');expect(new Set(r.voteMaps).size).toBe(3);
  expect(lobby.voteWinner(r)).toBe('night_mall');
  r.votes.set('h',r.voteMaps![2]);expect(lobby.voteWinner(r)).toBe(r.voteMaps![2]);
  lobby.start(r);expect(r.game!.mapId).toBe(r.voteMaps![2]);
 });
});

describe('map mechanics',()=>{
 it('elevators move a waiting player to the other wing after their delay',()=>{
  const g=hunt('night_hospital'),p=hider(g),e=g.map.portals![0];p.x=e.x+.5;p.y=e.y+.5;
  ticks(g,e.delaySec-.5);expect(Math.floor(p.x)).toBe(e.x);ticks(g,1);expect(Math.floor(p.x)).toBe(e.to.x);
  ticks(g,e.delaySec+1);expect(Math.floor(p.x)).toBe(e.to.x); // locked until the player steps off
 });
 it('the X-ray room reveals whoever walks in to everyone for a moment',()=>{
  const g=hunt('night_hospital'),p=hider(g),x=g.map.mechanics!.xray!;p.x=x.x+2.5;p.y=x.y+2.5;ticks(g,.1);
  expect(g.marks.some(m=>m.kind==='xray'&&m.targetId===p.id&&m.audience==='all')).toBe(true);
 });
 it('the mall broadcast room fires five fake ripples once',()=>{
  const g=hunt('night_mall'),p=hider(g),room=g.map.mechanics!.broadcastRoom!;p.x=room.x+3.5;p.y=room.y+4.5;
  action(g,p.id,'interact_start');expect(g.ripples.filter(r=>r.kind==='fake')).toHaveLength(MECH.broadcastFakes);
  g.ripples=[];action(g,p.id,'interact_start');expect(g.ripples.filter(r=>r.kind==='fake')).toHaveLength(0);
 });
 it('ship tilt slides everyone but disguised hiders; the deck is moonlit',()=>{
  const g=hunt('midnight_cruise'),[a,b]=g.players.filter(p=>p.role==='hider');
  a.x=20.5;a.y=6.5;b.x=24.5;b.y=6.5;b.state='disguised';b.prop='deck_chair';
  expect(visionRadius(g,a)).toBe(MECH.deckVision);
  g.nextMapEventAt=g.now+3500;ticks(g,4.5);expect(g.mapEvent?.stage).toBe('start');
  const dir=g.mapEvent!.dir!;ticks(g,1);expect((a.x-20.5)*dir).toBeGreaterThan(.5);expect(b.x).toBe(24.5);
 });
 it('blizzard blinds the snowfield, cold slows hiders outdoors, indoors restores',()=>{
  const g=hunt('snow_lodge'),p=hider(g);p.x=10.5;p.y=25.5;
  ticks(g,MECH.coldRampSec+g.map.mechanics!.coldAfterSec!+1);expect(mechanicsSpeed(g,p)).toBeCloseTo(1-MECH.coldMaxSlow,2);
  g.nextMapEventAt=g.now+5000;ticks(g,5.5);expect(g.mapEvent).toMatchObject({kind:'blizzard',stage:'start'});expect(visionRadius(g,p)).toBe(MECH.blizzardVision);
  p.x=30.5;p.y=26.5;ticks(g,.1);expect(mechanicsSpeed(g,p)).toBe(1);expect(visionRadius(g,p)).toBeGreaterThan(MECH.blizzardVision);
 });
});
