import {describe,it,expect} from 'vitest';
import {createGame,rolesFor,applyInput,action,ghostSide,finish,rewardsFor,setOnline,snapshotFor,tickGame} from '../src/game/engine.js';
import {catchPlayer,slap} from '../src/game/combat.js';
import {createOldDorm,isBlocked,wireMap,zoneAt} from '../src/game/maps/old_dorm.js';
import {distance,hasLineOfSight,inLight,visible} from '../src/game/vision.js';
import {RULES} from '../src/game/config.js';
import {astar} from '../src/game/ai/bot.js';
import {tickEvents} from '../src/game/events.js';
import {tickItems,useItem,convertItem,pickup} from '../src/game/items.js';
import {seeded,simulate} from '../src/sim.js';
const players=(n=8)=>Array.from({length:n},(_,i)=>({id:'p'+i,nickname:'P'+i,color:'blue' as const,isBot:false}));
function game(){
 const g=createGame('test',players(),300,1,false,{now:100000,random:seeded(1)});
 g.phase='hunt';g.huntStartedAt=g.now;g.phaseEndsAt=g.now+300000;g.nextEventAt=g.now+60000;g.nextDropAt=g.now+60000;
 g.map.tiles.fill(0);g.map.lockedDoors=[];g.map.props=[];
 g.players.forEach((p,i)=>{p.x=30+i;p.y=20});
 return g;
}
const advance=(g:ReturnType<typeof game>,seconds:number)=>{for(let i=0;i<seconds*20;i++)tickGame(g)};
describe('map and visibility',()=>{
 it('64x40 map, four correctly positioned wings, reachable spawns/props/generators/items and 40% cracked interior',()=>{
 const m=createOldDorm();expect(Buffer.from(wireMap(m).tiles,'base64')).toHaveLength(2560);
 expect(m.generators).toHaveLength(3);expect(m.itemSpots).toHaveLength(12);
 for(const p of [...m.hiderSpawns,...m.generators,...m.itemSpots,...m.props]){
 expect(isBlocked(p.x,p.y,.35,m),JSON.stringify(p)).toBe(false);
 expect(astar(m.hunterSpawn,p,m).length,JSON.stringify(p)).toBeGreaterThan(0);
 }
 const walls=[...m.tiles].filter(t=>t===1||t===2).length-2*m.w-2*(m.h-2);
 expect([...m.tiles].filter(t=>t===2).length/walls).toBeCloseTo(.4,1);
 for(const z of m.zones.filter(z=>z.name!=='中央大厅'))expect(m.itemSpots.filter(p=>zoneAt(p,m)===z).length).toBeGreaterThanOrEqual(2);
 expect(m.zones.find(z=>z.name==='西区澡堂')!.x).toBeLessThan(26);
 });
 it('DDA blocks walls and corner cracks; circular collision respects radius; room maps are independent',()=>{
 const a=game(),b=game();a.map.tiles[20*64+32]=1;
 expect(hasLineOfSight(31.5,20.5,33.5,20.5,a.map)).toBe(false);
 expect(hasLineOfSight(31.5,19.5,33.5,21.5,a.map)).toBe(false);
 expect(hasLineOfSight(31.5,20.5,33.5,20.5,b.map)).toBe(true);
 expect(isBlocked(31.7,20.5,.35,a.map)).toBe(true);expect(isBlocked(31.64,20.5,.35,a.map)).toBe(false);
 expect(inLight(30,20,35,20,0,6,Math.PI/3,b.map)).toBe(true);expect(inLight(30,20,25,20,0,6,Math.PI/3,b.map)).toBe(false);
 });
 it('snapshots hide wall-obscured players/footprints, preserve disguise fields, omit hidden identities from ripples',()=>{
 const g=game(),h=g.players.find(p=>p.role==='hunter')!,v=g.players.find(p=>p.role==='hider')!;h.x=30.5;h.y=20.5;v.x=32.5;v.y=20.5;
 g.map.tiles[20*64+31]=1;g.footprints.push({x:v.x,y:v.y,dir:0,until:g.now+3000,hunter:false});
 expect(snapshotFor(g,h.id)!.players.some(p=>p.id===v.id)).toBe(false);expect(snapshotFor(g,h.id)!.footprints).toHaveLength(0);
 g.map.tiles[20*64+31]=0;v.state='disguised';v.prop='chair';expect(snapshotFor(g,h.id)!.players.find(p=>p.id===v.id)?.prop).toBe('chair');
 v.state='ghost';expect(visible(g,h,v)).toBe(false);
 });
});
describe('authoritative game',()=>{
 it('role distribution, mole switch and no repeat hunter',()=>{
 const ids=players(10).map(p=>p.id),r=rolesFor(ids,[], 'auto',true,seeded(3));
 expect(r.filter(r=>r==='hunter')).toHaveLength(2);expect(r.filter(r=>r==='mole')).toHaveLength(1);
 const last=ids.filter((_,i)=>r[i]==='hunter'),next=rolesFor(ids,last,'auto',false,seeded(3));
 expect(next.filter(r=>r==='mole')).toHaveLength(0);expect(ids.filter((_,i)=>next[i]==='hunter').some(id=>last.includes(id))).toBe(false);
 });
 it('input flooding cannot speed up movement; hunters are locked during hide',()=>{
 const g=game(),p=g.players.find(p=>p.role==='hider')!,h=g.players.find(p=>p.role==='hunter')!,x=p.x;
 for(let i=0;i<100;i++)applyInput(g,p.id,1,0,false);expect(p.x).toBe(x);tickGame(g);expect(p.x-x).toBeCloseTo(.15);
 g.phase='hide';g.phaseEndsAt=g.now+20000;const hx=h.x;applyInput(g,h.id,1,0,true);tickGame(g);expect(h.x).toBe(hx);
 });
 it('disguise needs existing nearby prop, movement unmasks with 0.5 sec delay, jitter every 10sec',()=>{
 const g=game(),p=g.players.find(p=>p.role==='hider')!;p.x=30;p.y=20;
 action(g,p.id,'disguise',{prop:'chair'});expect(p.state).toBe('normal');
 g.map.props.push({x:30.5,y:20,prop:'chair'});action(g,p.id,'disguise',{prop:'chair'});expect(p.state).toBe('disguised');
 advance(g,10);expect(g.outbox.some(m=>m.kind==='disguise_jitter')).toBe(true);
 const x=p.x;applyInput(g,p.id,1,0,false);tickGame(g);expect(p.state).toBe('normal');expect(p.x).toBe(x);advance(g,.4);expect(p.x).toBe(x);
 });
 it('slap is nearest target, blocked by walls, miss stuns; capture enters cage and ghost selection preserves rescue token',()=>{
 const g=game(),h=g.players.find(p=>p.role==='hunter')!,v=g.players.find(p=>p.role==='hider')!;h.x=20;h.y=20;v.x=20.7;v.y=20;v.state='disguised';
 slap(g,h);expect(v.caged).toBe(true);expect(v.state).toBe('caged');expect(v.x).toBe(g.map.cage.x);expect(h.captures).toBe(1);
 ghostSide(g,v.id,'wraith');expect(v.state).toBe('ghost');expect(v.caged).toBe(true);
 g.now+=600;slap(g,h);expect(h.state).toBe('stunned');expect(h.stunnedUntil-g.now).toBe(1500);expect(g.ripples.at(-1)?.r).toBe(8);
 });
 it('3 second held rescue works once and survives ghost movement; stop interrupts',()=>{
 const g=game(),[v,rescuer]=g.players.filter(p=>p.role==='hider');catchPlayer(g,v);ghostSide(g,v.id,'guardian');v.x=2;v.y=2;
 rescuer.x=g.map.cage.x;rescuer.y=g.map.cage.y+1;
 action(g,rescuer.id,'interact_start',{targetId:v.id});advance(g,2);expect(v.caged).toBe(true);
 action(g,rescuer.id,'interact_stop');advance(g,2);expect(v.caged).toBe(true);
 action(g,rescuer.id,'interact_start',{targetId:v.id});advance(g,3.05);expect(v.caged).toBe(false);expect(v.rescued).toBe(true);
 catchPlayer(g,v);action(g,rescuer.id,'interact_start',{targetId:v.id});advance(g,4);expect(v.caged).toBe(true);expect(rescuer.score['解救队友']).toBe(60);
 });
 it.each([1,2,3])('generator with %i repairers uses 25/15/10sec and reduces remaining by 10% of the hunt once',n=>{
 const g=game(),gen=g.generators[0];gen.x=30;gen.y=20;
 const ps=g.players.filter(p=>p.role==='hider').slice(0,n);for(const p of ps){p.x=30;p.y=20;action(g,p.id,'interact_start')}
 const end=g.phaseEndsAt;advance(g,[25,15,10][n-1]+.1);expect(gen.fixed).toBe(true);expect(g.phaseEndsAt).toBe(end-g.durationSec*100);
 for(const p of ps)expect(p.score['修理发电机']).toBe(40);
 });
 it('default 600s hunt: a fixed generator removes exactly the design-doc 60s',()=>{
 const g=game();g.durationSec=600;const gen=g.generators[0];gen.x=30;gen.y=20;
 const p=g.players.find(q=>q.role==='hider')!;p.x=30;p.y=20;action(g,p.id,'interact_start');
 const end=g.phaseEndsAt;advance(g,25.1);expect(gen.fixed).toBe(true);expect(end-g.phaseEndsAt).toBe(60000);
 });
 it('three timed slaps break cracked wall with per-match mutations and broadcast',()=>{
 const g=game(),h=g.players.find(p=>p.role==='hunter')!;h.x=20.5;h.y=20.5;h.dir=0;g.map.tiles[20*64+21]=2;
 slap(g,h);expect(g.map.tiles[20*64+21]).toBe(2);g.now+=500;slap(g,h);expect(g.map.tiles[20*64+21]).toBe(2);g.now+=500;slap(g,h);
 expect(g.map.tiles[20*64+21]).toBe(4);expect(g.outbox.some(m=>m.t==='game.wall')).toBe(true);
 });
 it('final heartbeat, timeout hider win, all captured hunter win, offline hunter void, ghost timeout and cooldown',()=>{
 const g=game(),h=g.players.find(p=>p.role==='hunter')!,v=g.players.find(p=>p.role==='hider')!;
 g.phaseEndsAt=g.now+29000;advance(g,2);expect(g.phase).toBe('final');expect(g.ripples.some(r=>r.kind==='heartbeat')).toBe(true);
 catchPlayer(g,v);advance(g,10);expect(v.ghostSide).toBe('guardian');action(g,v.id,'ghost_skill',{x:v.x+1,y:v.y});const n=g.ripples.length;action(g,v.id,'ghost_skill',{x:v.x+1,y:v.y});expect(g.ripples.length).toBe(n);
 advance(g,17.1);expect(g.winner).toBe('hider');
 const all=game();all.players.filter(p=>p.role==='hider').forEach(p=>catchPlayer(all,p));tickGame(all);expect(all.winner).toBe('hunter');
 const off=game(),oh=off.players.find(p=>p.role==='hunter')!;setOnline(off,oh.id,false);advance(off,30.1);expect(off.voided).toBe(true);expect(rewardsFor(off,oh).exp).toBe(0);
 });
 it('reconnect within 30 sec restores live input; expired hiders caught',()=>{
 const g=game(),p=g.players.find(p=>p.role==='hider')!;setOnline(g,p.id,false);advance(g,29);setOnline(g,p.id,true);advance(g,2);expect(p.caged).toBe(false);
 setOnline(g,p.id,false);advance(g,30.1);expect(p.caged).toBe(true);
 });
});
describe('items and events',()=>{
 it('eight item effects, conversion and inventory cap',()=>{
 const g=game(),h=g.players.find(p=>p.role==='hunter')!,p=g.players.find(p=>p.role==='hider')!;p.x=20;p.y=20;h.x=24;h.y=20;
 p.items=['smoke','banana'];useItem(g,p,0,{x:1,y:0});h.x=21;tickItems(g);expect(visionRadiusForSmoke(g,h)).toBe(0);
 g.now+=500;useItem(g,p,1,{x:1,y:0});h.x=20;tickItems(g);expect(h.stunnedUntil).toBeGreaterThan(g.now);
 h.stunnedUntil=0;h.state='normal';g.hazards=[];h.x=20;p.x=23;p.state='disguised';p.prop='chair';
 h.items=['strong_flashlight','net'];useItem(g,h,0,{x:1,y:0});expect(p.state).toBe('normal');
 g.now+=500;useItem(g,h,1,{x:1,y:0});expect(p.slowUntil).toBeGreaterThan(g.now);
 h.items=['bell_trap','sprint_shoes'];g.now+=500;useItem(g,h,0,{x:1,y:0});p.x=h.x;tickItems(g);expect(g.marks.some(m=>m.targetId===p.id)).toBe(true);
 g.now+=500;useItem(g,h,1,{x:1,y:0});expect(h.boostUntil-g.now).toBe(4000);
 p.x=30;p.y=20;p.items=['speed_shoes','wood_board'];g.now+=500;useItem(g,p,0,{x:1,y:0});expect(p.boostUntil-g.now).toBe(5000);
 g.now+=500;useItem(g,p,1,{x:1,y:0});expect(g.walls.size).toBeGreaterThan(0);g.now+=25001;tickItems(g);expect(g.walls.size).toBe(0);
 expect(convertItem('smoke',true,()=>0)).toBe('strong_flashlight');
 const d=g.drops[0];p.x=d.x;p.y=d.y;p.items=['smoke','banana'];expect(pickup(g,p)).toBe(false);
 });
 it('events and drops warn five seconds early, have capped counts and four working kinds',()=>{
 const g=game();g.now=g.nextEventAt-5000;tickEvents(g);expect(g.event?.stage).toBe('warn');expect(g.drops.filter(d=>d.stage==='warn').length).toBeGreaterThanOrEqual(3);
 g.now+=5000;tickEvents(g);expect(g.event?.stage).toBe('start');expect(g.drops.filter(d=>d.stage==='warn')).toHaveLength(0);
 for(let i=0;i<10;i++){g.now+=15000;tickEvents(g);g.now=g.nextEventAt;tickEvents(g)}
 expect(Object.values(g.eventCounts).every(n=>n<=2)).toBe(true);
 });
 it('seeded full AI simulation uses same engine, produces captures/generators/events, returns waiting',()=>{
 const log:string[]=[];const g=simulate(42,s=>log.push(s));
 expect(g.result).toBeDefined();expect(g.phase).toBe('waiting');expect(log.some(s=>s.startsWith('caught'))).toBe(true);expect(log.some(s=>s.startsWith('generator fixed'))).toBe(true);expect(log.some(s=>s.startsWith('event'))).toBe(true);
 },15000);
});
import {visionRadius as visionRadiusForSmoke} from '../src/game/vision.js';
