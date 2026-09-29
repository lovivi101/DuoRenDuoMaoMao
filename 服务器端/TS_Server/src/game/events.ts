import type {GameState} from '../types.js';
import {RULES} from './config.js';
import {emit,living,reveal,ripple} from './shared.js';
import {randomItem} from './items.js';
export const EVENTS={blackout:10,emergency_light:8,adrenaline:10,broadcast:3} as const;
export function chooseEvent(g:GameState){
 const h=g.players.filter(p=>p.role==='hider'),ratio=h.filter(living).length/Math.max(1,h.length);
 const pool=(Object.keys(EVENTS) as (keyof typeof EVENTS)[]).filter(k=>(g.eventCounts[k]||0)<2);
 const weights=pool.map(k=>ratio>.7?(k==='adrenaline'?1:3):ratio<.3?(k==='adrenaline'?6:1):1);
 let roll=g.random()*weights.reduce((a,b)=>a+b,0);
 return pool.find((_,i)=>(roll-=weights[i])<=0)||pool.at(-1);
}
export function tickEvents(g:GameState){
 if(!g.event&&g.now>=g.nextEventAt-RULES.warnSec*1000){
 const kind=chooseEvent(g);
 if(kind){g.event={kind,stage:'warn',at:g.nextEventAt,until:g.nextEventAt+EVENTS[kind]*1000};emit(g,{t:'game.event',kind,stage:'warn',at:g.nextEventAt,durationSec:EVENTS[kind]})}
 else g.nextEventAt+=RULES.eventInterval*1000;
 }
 const e=g.event;
 if(e&&e.stage==='warn'&&g.now>=e.at){
 e.stage='start';g.eventCounts[e.kind]=(g.eventCounts[e.kind]||0)+1;g.nextEventAt+=RULES.eventInterval*1000;
 emit(g,{t:'game.event',kind:e.kind,stage:'start',at:e.at,durationSec:EVENTS[e.kind as keyof typeof EVENTS]});
 if(e.kind==='emergency_light')for(const p of g.players.filter(living))reveal(g,p,EVENTS.emergency_light);
 if(e.kind==='broadcast'){
 const targets=g.players.filter(p=>p.role==='hider'&&living(p));const p=targets[Math.floor(g.random()*targets.length)];
 if(p)g.marks.push({x:p.x,y:p.y,kind:'report',until:e.until,audience:'all',targetId:p.id});
 }
 }
 if(e&&e.stage==='start'&&g.now>=e.until){emit(g,{t:'game.event',kind:e.kind,stage:'end',at:e.until,durationSec:0});g.event=null}
 if(g.now>=g.nextDropAt-RULES.warnSec*1000&&!g.drops.some(d=>d.stage==='warn')){
 const spots=[...g.map.itemSpots].sort(()=>g.random()-.5).slice(0,3+Math.floor(g.random()*2));
 const drops=spots.map((p,i)=>({...p,id:'d_'+g.tick+'_'+i,item:randomItem(g),stage:'warn' as const,at:g.nextDropAt}));
 g.drops.push(...drops);emit(g,{t:'game.drop',drops:drops.map(({id,x,y,stage})=>({id,x,y,stage}))});
 }
 const landed=g.drops.filter(d=>d.stage==='warn'&&g.now>=d.at);
 if(landed.length){for(const d of landed){d.stage='landed';ripple(g,d,'box')}g.nextDropAt+=RULES.dropInterval*1000;emit(g,{t:'game.drop',drops:landed.map(({id,x,y,stage})=>({id,x,y,stage}))})}
}
