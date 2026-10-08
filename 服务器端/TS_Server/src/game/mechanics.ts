import type {GamePlayer,GameState,Pos} from '../types.js';
import {RULES} from './config.js';
import {inRect} from './maps/build.js';
import {active,emit,fx,living,ripple} from './shared.js';
import {distance,validMove} from './vision.js';

// Map-specific rules (design doc §8). Every hook is a no-op on maps without the matching
// `mechanics` entry, so 旧宿舍楼 plays exactly as before.
export const MECH={monitorRange:1.5,monitorCooldownMs:2500,xrayMarkMs:1000,xrayCooldownMs:10000,
 deckVision:9,blizzardVision:1.5,snowPrintMs:15000,snowStepMs:500,coldRampSec:20,coldMaxSlow:.3,fireRange:3,fireSeen:12,
 broadcastFakes:5};
// Development-only override for balance runs, e.g. MECH_TUNE='{"deckVision":7}'.
if(process.env.NODE_ENV!=='production'&&process.env.MECH_TUNE)Object.assign(MECH,JSON.parse(process.env.MECH_TUNE));

const tile=(p:Pos)=>({x:Math.floor(p.x),y:Math.floor(p.y)});
export const outdoors=(g:GameState,p:Pos)=>!!g.map.mechanics?.indoor&&!g.map.mechanics.indoor.some(r=>inRect(p,r));
export const onDeck=(g:GameState,p:Pos)=>!!g.map.mechanics?.deck&&inRect(p,g.map.mechanics.deck);
const monitorHeard=new WeakMap<GameState,Map<number,number>>(),snowStep=new WeakMap<GamePlayer,number>();

// Movement multiplier: cold on the snowfield (hiders only: after coldAfterSec outdoors, ramps to -30%).
export function mechanicsSpeed(g:GameState,p:GamePlayer){
 const after=g.map.mechanics?.coldAfterSec;if(!after||p.outdoorSince==null||p.role==='hunter')return 1;
 const cold=(g.now-p.outdoorSince)/1000-after;return cold<=0?1:1-MECH.coldMaxSlow*Math.min(1,cold/MECH.coldRampSec);
}
// Vision radius adjustments: moonlit deck, blizzard outdoors.
export function mechanicsVision(g:GameState,p:GamePlayer,radius:number){
 if(radius<=0)return radius;
 if(g.mapEvent?.kind==='blizzard'&&g.mapEvent.stage==='start'&&outdoors(g,p))return Math.min(radius,MECH.blizzardVision);
 if(onDeck(g,p)&&!(g.event?.stage==='start'&&g.event.kind==='blackout'))return Math.max(radius,MECH.deckVision);
 return radius;
}
// The lodge fireplace lights up whoever stands next to it for anyone with line of sight nearby.
export function litByFire(g:GameState,observer:Pos,target:Pos){
 const f=g.map.mechanics?.fireplace;return !!f&&distance(target,f)<=MECH.fireRange&&distance(observer,target)<=MECH.fireSeen;
}
// Interact inside the mall broadcast room: a one-off fake alarm (5 fake ripples across the map).
export function onInteract(g:GameState,p:GamePlayer){
 const room=g.map.mechanics?.broadcastRoom;
 if(!room||p.role==='hunter'||g.broadcastUsed||!inRect(p,room)||!active(g))return false;
 g.broadcastUsed=true;
 for(let i=0;i<MECH.broadcastFakes;i++){
  for(let tries=0;tries<30;tries++){const q={x:1+g.random()*(g.map.w-2),y:1+g.random()*(g.map.h-2)};if(validMove(q.x,q.y,g.map)){ripple(g,q,'fake',false,p.id);break}}
 }
 fx(g,p,'broadcast_alarm',p.id);return true;
}

function portals(g:GameState){
 const list=g.map.portals??[];if(!list.length)return;
 for(const p of g.players){
  if(!living(p)||p.state==='ghost'||p.state==='disguised'){p.transit=null;continue}
  const t=tile(p),here=list.find(q=>q.x===t.x&&q.y===t.y);
  if(!here){p.transit=null;p.portalLock=null;continue}
  if(p.portalLock===here.id)continue;
  if(!p.transit||p.transit.portal!==here.id){p.transit={portal:here.id,since:g.now};continue}
  if(g.now-p.transit.since<here.delaySec*1000)continue;
  // Capacity (elevator: 2): the earliest arrivals ride, the rest wait for the next trip.
  const waiting=g.players.filter(q=>q.transit?.portal===here.id).sort((a,b)=>a.transit!.since-b.transit!.since);
  if(waiting.indexOf(p)>=here.cap)continue;
  const dest={x:here.to.x+.5,y:here.to.y+.5};
  ripple(g,p,'door',p.role==='hunter',p.id);p.x=dest.x;p.y=dest.y;p.interact=null;
  const back=list.find(q=>q.x===here.to.x&&q.y===here.to.y);p.portalLock=back?.id??null;p.transit=null;
  ripple(g,dest,'door',p.role==='hunter',p.id);emit(g,{t:'game.portal',id:p.id,kind:here.kind,x:dest.x,y:dest.y});
 }
}
function monitors(g:GameState){
 const list=g.map.mechanics?.monitors;if(!list)return;
 let heard=monitorHeard.get(g);if(!heard){heard=new Map();monitorHeard.set(g,heard)}
 list.forEach((m,i)=>{
  if(g.now-(heard!.get(i)??-Infinity)<MECH.monitorCooldownMs)return;
  const runner=g.players.find(p=>living(p)&&p.role!=='hunter'&&p.running&&distance(p,m)<=MECH.monitorRange);
  if(runner){ripple(g,m,'door',false,runner.id);fx(g,m,'monitor_beep');heard!.set(i,g.now)}
 });
}
function xray(g:GameState){
 const room=g.map.mechanics?.xray;if(!room)return;
 for(const p of g.players){
  if(!living(p)||p.state==='ghost'||!inRect(p,room)||(p.xrayReadyAt??0)>g.now)continue;
  p.xrayReadyAt=g.now+MECH.xrayCooldownMs;
  g.marks.push({x:p.x,y:p.y,kind:'xray',targetId:p.id,until:g.now+MECH.xrayMarkMs,audience:'all'});fx(g,p,'xray',p.id);
 }
}
// Timed map events (ship tilt, blizzard) share one slot and one schedule per map.
function mapEvents(g:GameState,dt:number){
 const m=g.map.mechanics;const spec=m?.tilt?{kind:'ship_tilt',...m.tilt}:m?.blizzard?{kind:'blizzard',...m.blizzard}:null;if(!spec)return;
 if(g.nextMapEventAt<=g.huntStartedAt)g.nextMapEventAt=g.huntStartedAt+spec.intervalSec*1000;
 const e=g.mapEvent;
 if(!e&&g.now>=g.nextMapEventAt-spec.warnSec*1000){
  g.mapEvent={kind:spec.kind,stage:'warn',at:g.nextMapEventAt,until:g.nextMapEventAt+spec.durationSec*1000,dir:g.random()<.5?-1:1};
  emit(g,{t:'game.mapEvent',kind:spec.kind,stage:'warn',at:g.mapEvent.at,durationSec:spec.durationSec,dir:g.mapEvent.dir});
 }else if(e?.stage==='warn'&&g.now>=e.at){
  e.stage='start';emit(g,{t:'game.mapEvent',kind:e.kind,stage:'start',at:e.at,durationSec:spec.durationSec,dir:e.dir});
  if(e.kind==='blizzard')g.footprints=g.footprints.filter(f=>!outdoors(g,f));
 }else if(e?.stage==='start'&&g.now>=e.until){
  emit(g,{t:'game.mapEvent',kind:e.kind,stage:'end',at:e.until,durationSec:0});g.mapEvent=null;g.nextMapEventAt+=spec.intervalSec*1000;
 }
 // Ship tilt: everyone not disguised slides sideways; disguised hiders stay put and stand out.
 if(g.mapEvent?.kind==='ship_tilt'&&g.mapEvent.stage==='start'&&m?.tilt){
  const dx=(g.mapEvent.dir??1)*m.tilt.speed*dt;
  for(const p of g.players)if(living(p)&&p.state!=='disguised'&&p.state!=='ghost'&&validMove(p.x+dx,p.y,g.map))p.x+=dx;
 }
}
function snow(g:GameState){
 if(!g.map.mechanics?.indoor)return;
 for(const p of g.players){
  const out=living(p)&&p.state!=='ghost'&&outdoors(g,p);
  p.outdoorSince=out?(p.outdoorSince??g.now):null;
  // Walking on snow leaves prints too (running already does, everywhere).
  const moving=Math.hypot(p.input.mx,p.input.my)>0&&g.now-p.input.at<=500&&g.now>=p.stunnedUntil;
  if(out&&moving&&!p.running&&g.now-(snowStep.get(p)??-Infinity)>=MECH.snowStepMs){g.footprints.push({x:p.x,y:p.y,dir:p.dir,until:g.now+MECH.snowPrintMs,hunter:p.role==='hunter',style:p.look?.footprint});snowStep.set(p,g.now)}
 }
 // Prints on snow last 15 s instead of 3 s.
 for(const f of g.footprints)if(f.until-g.now<=RULES.footprintSec*1000+60&&f.until-g.now>RULES.footprintSec*1000-60&&outdoors(g,f))f.until=g.now+MECH.snowPrintMs;
}
export function tickMechanics(g:GameState,dt:number){
 if(g.phase==='assign'||g.phase==='result'||g.phase==='waiting')return;
 portals(g);
 if(!active(g))return;
 monitors(g);xray(g);mapEvents(g,dt);snow(g);
}
